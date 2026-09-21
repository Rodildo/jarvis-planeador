import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/notification_service.dart';
import '../core/i18n/app_language.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final AppLanguage _lang;

  static const String _localBackupKey = 'chat_today_backup';
  static const String _energyPromptGateKey = 'energy_prompt_gate';
  static const String _lastEnergyCheckKey = 'last_energy_check_at';

  bool isLoading = false;
  late String jarvisMessage;

  // plan = { greeting, morning: [{task, reason}], midday: [...], night: [...] }
  Map<String, dynamic>? plan;
  // Claves: 'ai-<block>-<index>' para tareas del plan, o el id propio de una
  // tarea manual (ya tiene el prefijo 'manual-').
  Map<String, bool> completed = {};
  List<Map<String, dynamic>> manualTasks = [];
  bool dayStarted = false;
  bool showMiddayInput = false;
  /// true cuando _hydrateToday no pudo restaurar nada Y ya se alcanzó el
  /// límite de _canShowEnergyPrompt: la UI debe ocultar los botones de
  /// energía en vez de dejar que el usuario dispare otra generación de
  /// plan mientras el límite sigue activo.
  bool energyPromptGateBlocked = false;

  DateTime? _lastEnergyCheckAt;

  /// El botón manual de "Chequeo de energía ahora" no debe estar
  /// disponible todo el tiempo: se habilita solo cada 6 horas como mínimo
  /// desde el último reporte de energía (mañana o mediodía), para no
  /// invitar a llamadas de IA de más. El chequeo automático por
  /// notificación ya respeta ese mismo intervalo por diseño.
  bool get canRequestMiddayCheck {
    final last = _lastEnergyCheckAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(hours: 6);
  }

  ChatProvider(this._lang) {
    jarvisMessage = _lang.t('chat.initialGreeting');
    // Se registra antes de consultar si la app se abrió desde una
    // notificación, para no perder el tap si fue un cold start.
    NotificationService.instance.onMiddayTap = showMidday;
    NotificationService.instance.handleAppLaunchFromNotification();
    _hydrateToday();
    // Precarga en segundo plano (sin esperar) para que, si el usuario
    // entra a Historial o a Mi Plan Maestro, ya esté listo en caché en
    // vez de tener que esperar el viaje de red justo en ese momento.
    _api.getHistory(days: 365);
    _api.getLifeBlueprint();
  }

  // Si el usuario ya tiene un plan generado hoy, restauramos ese estado al
  // abrir la app en vez de volver a pedir el nivel de energía desde cero.
  Future<void> _hydrateToday() async {
    isLoading = true;
    notifyListeners();

    await _loadLastEnergyCheck();

    Map<String, dynamic>? log;
    try {
      log = await _api.getTodayLog();
    } catch (_) {
      log = null;
    }

    final raw = log?['actions_chosen'];
    if (raw != null) {
      try {
        final state = jsonDecode(raw) as Map<String, dynamic>;
        if (_applyRestoredState(state)) {
          isLoading = false;
          notifyListeners();
          return;
        }
      } catch (_) {
        // Estado guardado corrupto: seguimos abajo como si no hubiera nada.
      }
    }

    // El backend guarda tu energía matutina ANTES de generar el plan, así
    // que si la generación falló a mitad de camino (ej. la IA no
    // respondió bien) puede que ya hayas reportado tu energía hoy aunque
    // nunca se haya guardado un plan. En vez de volver a preguntarte,
    // reintentamos solos con esa misma energía.
    final morningEnergy = log?['energy_morning'];
    final energyLevel = morningEnergy is int ? morningEnergy : int.tryParse('$morningEnergy');
    if (energyLevel != null && energyLevel >= 1 && energyLevel <= 5) {
      jarvisMessage = _lang.tr('chat.resumingPlan', {'level': '$energyLevel'});
      notifyListeners();
      await _generatePlan(energyLevel);
      return;
    }

    // No se pudo confirmar con el backend que ya hay un plan guardado hoy
    // (sin red justo al abrir la app, arranque en frío, etc. — getTodayLog
    // ya reintenta solo, pero puede seguir fallando). Antes de asumir que
    // no hay nada y volver a pedir energía —lo que además dispararía una
    // llamada de más a la IA si el usuario responde, pisando el plan real—
    // probamos con el respaldo local de hoy.
    final backup = await _loadLocalBackup();
    if (backup != null && _applyRestoredState(backup)) {
      isLoading = false;
      notifyListeners();
      return;
    }

    // Ni el backend ni el respaldo local tenían nada que restaurar: de
    // verdad no hay más remedio que pedir energía desde cero. Como límite
    // duro para que un problema repetido (de red o lo que sea) nunca
    // convierta esto en una pantalla que reaparece sin parar: como mucho
    // dos veces al día, con al menos 8 horas de diferencia entre una y
    // otra. Si ya se llegó a ese límite, no se vuelve a pedir energía —se
    // deja un mensaje para reintentar más tarde en vez de arriesgar
    // generar (y gastar tokens en) un plan de más.
    if (!await _canShowEnergyPrompt()) {
      jarvisMessage = _lang.t('chat.gateBlockedMessage');
      energyPromptGateBlocked = true;
      isLoading = false;
      notifyListeners();
      return;
    }
    await _recordEnergyPromptShown();

    isLoading = false;
    notifyListeners();
  }

  /// Reintento manual desde la pantalla de "no pude confirmar tu plan"
  /// (ver energyPromptGateBlocked): vuelve a intentar restaurar el día sin
  /// pasar por el límite de nuevo si esta vez sí se puede confirmar algo.
  Future<void> retryHydrate() async {
    energyPromptGateBlocked = false;
    await _hydrateToday();
  }

  /// Límite duro sobre cuántas veces al día se puede volver a mostrar la
  /// pantalla inicial de "¿cómo está tu energía?" cuando no hubo nada que
  /// restaurar (ver _hydrateToday): máximo 2 veces, con al menos 8 horas
  /// entre una y otra. Un día nuevo (fecha distinta a la guardada) siempre
  /// reinicia el conteo, sin importar la hora del último registro.
  Future<bool> _canShowEnergyPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_energyPromptGateKey);
    if (raw == null) return true;
    try {
      final gate = jsonDecode(raw) as Map<String, dynamic>;
      if (gate['date'] != _todayDate) return true;
      if ((gate['count'] as int? ?? 0) >= 2) return false;
      final lastShownRaw = gate['lastShownAt'] as String?;
      if (lastShownRaw != null) {
        final lastShown = DateTime.tryParse(lastShownRaw);
        if (lastShown != null && DateTime.now().difference(lastShown) < const Duration(hours: 8)) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _recordEnergyPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_energyPromptGateKey);
    int count = 0;
    if (raw != null) {
      try {
        final gate = jsonDecode(raw) as Map<String, dynamic>;
        if (gate['date'] == _todayDate) count = (gate['count'] as int? ?? 0);
      } catch (_) {}
    }
    await prefs.setString(_energyPromptGateKey, jsonEncode({
      'date': _todayDate,
      'count': count + 1,
      'lastShownAt': DateTime.now().toIso8601String(),
    }));
  }

  /// Aplica un estado guardado (del backend o del respaldo local) si trae
  /// un plan válido. Devuelve false si no había nada útil que restaurar.
  bool _applyRestoredState(Map<String, dynamic> state) {
    final restoredPlan = state['plan'] as Map<String, dynamic>?;
    if (restoredPlan == null) return false;
    plan = restoredPlan;
    completed = Map<String, bool>.from(state['completed'] ?? {});
    manualTasks = List<Map<String, dynamic>>.from(
      (state['manualTasks'] as List? ?? []).map((t) => Map<String, dynamic>.from(t)),
    );
    dayStarted = true;
    jarvisMessage = restoredPlan['greeting']?.toString() ?? _lang.t('chat.defaultPlanReady');
    return true;
  }

  String get _todayDate => DateTime.now().toIso8601String().split('T')[0];

  Future<void> _loadLastEnergyCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastEnergyCheckKey);
    if (raw != null) _lastEnergyCheckAt = DateTime.tryParse(raw);
  }

  Future<void> _recordEnergyCheckNow() async {
    final now = DateTime.now();
    _lastEnergyCheckAt = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEnergyCheckKey, now.toIso8601String());
  }

  Future<void> _saveLocalBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localBackupKey, jsonEncode({
      'date': _todayDate,
      'plan': plan,
      'completed': completed,
      'manualTasks': manualTasks,
    }));
  }

  Future<Map<String, dynamic>?> _loadLocalBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localBackupKey);
    if (raw == null) return null;
    try {
      final backup = jsonDecode(raw) as Map<String, dynamic>;
      // Respaldo de un día anterior: ya no aplica, un día nuevo empieza
      // sin plan hasta que se reporte energía de verdad.
      if (backup['date'] != _todayDate) return null;
      return backup;
    } catch (_) {
      return null;
    }
  }

  int? _parseEnergyLevel(String textInput) {
    final text = textInput.trim();
    int? level = int.tryParse(text);
    if (level == null) {
      final match = RegExp(r'[1-5]').firstMatch(text);
      if (match != null) level = int.parse(match.group(0)!);
    }
    if (level == null || level < 1 || level > 5) return null;
    return level;
  }

  Future<void> requestDailyPlan(String textInput) async {
    final energyLevel = _parseEnergyLevel(textInput);
    if (energyLevel == null) {
      jarvisMessage = _lang.t('chat.invalidEnergyLevel');
      notifyListeners();
      return;
    }
    await _generatePlan(energyLevel);
  }

  Future<void> _generatePlan(int energyLevel) async {
    isLoading = true;
    // Limpia cualquier mensaje de error de un intento anterior, para que
    // no se vea el error viejo superpuesto con el spinner del intento nuevo.
    jarvisMessage = _lang.t('chat.loadingPlan');
    notifyListeners();

    try {
      final result = await _api.getDailyPlan(energyLevel, _lang.code);
      plan = result;
      completed = {};
      manualTasks = [];
      dayStarted = true;
      jarvisMessage = result['greeting']?.toString() ?? _lang.t('chat.defaultPlanReady');
      await _persistState();
      await _recordEnergyCheckNow();
      await NotificationService.instance.scheduleMiddayCheck(const Duration(hours: 6));
    } catch (e) {
      jarvisMessage = '${e.toString().replaceFirst('Exception: ', '')} ${_lang.t('chat.connectionErrorSuffix')}';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleTaskDone(String id) async {
    completed[id] = !(completed[id] ?? false);
    notifyListeners();
    await _persistState();
  }

  Future<void> addManualTask(String block, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = 'manual-${DateTime.now().microsecondsSinceEpoch}';
    manualTasks.add({'id': id, 'block': block, 'text': trimmed});
    notifyListeners();
    await _persistState();
  }

  Future<void> removeManualTask(String id) async {
    manualTasks.removeWhere((t) => t['id'] == id);
    completed.remove(id);
    notifyListeners();
    await _persistState();
  }

  Future<void> _persistState() async {
    await _api.saveDailyState({
      'plan': plan,
      'completed': completed,
      'manualTasks': manualTasks,
    });
    await _saveLocalBackup();
  }

  void showMidday() {
    NotificationService.instance.cancelMiddayCheck();
    showMiddayInput = true;
    jarvisMessage = _lang.t('chat.middayPrompt');
    notifyListeners();
  }

  /// Sale del chequeo de mitad de día sin responder, volviendo a mostrar
  /// el plan. Antes, si el chequeo fallaba, no había forma de salir de
  /// esta pantalla: los botones de energía se quedaban ahí para siempre.
  void dismissMiddayCheck() {
    showMiddayInput = false;
    jarvisMessage = plan?['greeting']?.toString() ?? _lang.t('chat.defaultPlanReady');
    notifyListeners();
  }

  Future<void> triggerMiddayCheck(String textInput) async {
    final energyLevel = _parseEnergyLevel(textInput);
    if (energyLevel == null) return;

    isLoading = true;
    // Limpia cualquier mensaje de error de un intento anterior, para que
    // no se vea el error viejo superpuesto con el spinner del intento nuevo.
    jarvisMessage = _lang.t('chat.loadingMiddayCheck');
    notifyListeners();

    try {
      final result = await _api.triggerMiddayCheck(energyLevel, _lang.code);
      jarvisMessage = result['message']?.toString() ?? '';
      await _recordEnergyCheckNow();

      // Si el backend regeneró midday/night por un cambio grande de
      // energía, vienen el plan y los "completada" ya ajustados: se
      // reemplaza el estado local entero para no quedar desincronizados.
      final updatedPlan = result['plan'] as Map<String, dynamic>?;
      if (updatedPlan != null) {
        plan = updatedPlan;
        completed = Map<String, bool>.from(result['completed'] ?? {});
        await _persistState();
      }

      showMiddayInput = false;
    } catch (e) {
      jarvisMessage = '${e.toString().replaceFirst('Exception: ', '')} ${_lang.t('chat.connectionErrorSuffix')}';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
