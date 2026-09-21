import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool isLoading = false;
  String jarvisMessage = "¡Buenos días! Soy Jarvis. ¿Del 1 al 5, cómo está tu nivel de energía hoy?";

  // plan = { greeting, morning: [{task, reason}], midday: [...], night: [...] }
  Map<String, dynamic>? plan;
  // Claves: 'ai-<block>-<index>' para tareas del plan, o el id propio de una
  // tarea manual (ya tiene el prefijo 'manual-').
  Map<String, bool> completed = {};
  List<Map<String, dynamic>> manualTasks = [];
  bool dayStarted = false;
  bool showMiddayInput = false;

  ChatProvider() {
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
        final restoredPlan = state['plan'] as Map<String, dynamic>?;
        if (restoredPlan != null) {
          plan = restoredPlan;
          completed = Map<String, bool>.from(state['completed'] ?? {});
          manualTasks = List<Map<String, dynamic>>.from(
            (state['manualTasks'] as List? ?? []).map((t) => Map<String, dynamic>.from(t)),
          );
          dayStarted = true;
          jarvisMessage = restoredPlan['greeting']?.toString() ?? 'Aquí está tu plan de hoy.';
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
      jarvisMessage = 'Ya tengo tu energía de hoy (nivel $energyLevel) — termino de armar tu plan...';
      notifyListeners();
      await _generatePlan(energyLevel);
      return;
    }

    isLoading = false;
    notifyListeners();
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
      jarvisMessage = "Por favor ingresa un nivel válido del 1 al 5.";
      notifyListeners();
      return;
    }
    await _generatePlan(energyLevel);
  }

  Future<void> _generatePlan(int energyLevel) async {
    isLoading = true;
    // Limpia cualquier mensaje de error de un intento anterior, para que
    // no se vea el error viejo superpuesto con el spinner del intento nuevo.
    jarvisMessage = 'Generando tu plan del día...';
    notifyListeners();

    try {
      final result = await _api.getDailyPlan(energyLevel);
      plan = result;
      completed = {};
      manualTasks = [];
      dayStarted = true;
      jarvisMessage = result['greeting']?.toString() ?? 'Aquí está tu plan de hoy.';
      await _persistState();
      await NotificationService.instance.scheduleMiddayCheck(const Duration(hours: 6));
    } catch (e) {
      jarvisMessage = "${e.toString().replaceFirst('Exception: ', '')} Revisa tu conexión e intenta de nuevo.";
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
  }

  void showMidday() {
    NotificationService.instance.cancelMiddayCheck();
    showMiddayInput = true;
    jarvisMessage = "¿Cómo está tu nivel de energía en este momento (1-5)?";
    notifyListeners();
  }

  /// Sale del chequeo de mitad de día sin responder, volviendo a mostrar
  /// el plan. Antes, si el chequeo fallaba, no había forma de salir de
  /// esta pantalla: los botones de energía se quedaban ahí para siempre.
  void dismissMiddayCheck() {
    showMiddayInput = false;
    jarvisMessage = plan?['greeting']?.toString() ?? 'Aquí está tu plan de hoy.';
    notifyListeners();
  }

  Future<void> triggerMiddayCheck(String textInput) async {
    final energyLevel = _parseEnergyLevel(textInput);
    if (energyLevel == null) return;

    isLoading = true;
    // Limpia cualquier mensaje de error de un intento anterior, para que
    // no se vea el error viejo superpuesto con el spinner del intento nuevo.
    jarvisMessage = 'Registrando tu chequeo de energía...';
    notifyListeners();

    try {
      final result = await _api.triggerMiddayCheck(energyLevel);
      jarvisMessage = result['message']?.toString() ?? '';

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
      jarvisMessage = "${e.toString().replaceFirst('Exception: ', '')} Revisa tu conexión e intenta de nuevo.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
