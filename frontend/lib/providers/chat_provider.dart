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
  }

  // Si el usuario ya tiene un plan generado hoy, restauramos ese estado al
  // abrir la app en vez de volver a pedir el nivel de energía desde cero.
  Future<void> _hydrateToday() async {
    isLoading = true;
    notifyListeners();

    try {
      final log = await _api.getTodayLog();
      final raw = log?['actions_chosen'];
      if (raw != null) {
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
        }
      }
    } catch (e) {
      // Si falla la hidratación simplemente arrancamos el flujo normal.
    } finally {
      isLoading = false;
      notifyListeners();
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
      jarvisMessage = "Por favor ingresa un nivel válido del 1 al 5.";
      notifyListeners();
      return;
    }

    isLoading = true;
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

  Future<void> triggerMiddayCheck(String textInput) async {
    final energyLevel = _parseEnergyLevel(textInput);
    if (energyLevel == null) return;

    isLoading = true;
    notifyListeners();

    try {
      jarvisMessage = await _api.triggerMiddayCheck(energyLevel);
      showMiddayInput = false;
    } catch (e) {
      jarvisMessage = "${e.toString().replaceFirst('Exception: ', '')} Revisa tu conexión e intenta de nuevo.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
