import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/notification_service.dart';
import '../core/onboarding_questions.dart';

class OnboardingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Map<String, String>> messages = [];
  bool isLoading = false;
  int questionCount = 0;
  final int maxQuestions = totalOnboardingQuestions;
  String? errorMessage;

  // Progreso por área (5 áreas x 10 preguntas), para mostrar
  // "Área 2/5 · Pregunta 3/10". Viene del banco fijo de preguntas, no de
  // la IA, así que nunca falla por red.
  String? currentAreaLabel;
  int currentAreaIndex = 0;
  int currentQuestionNumber = 0;

  OnboardingProvider() {
    _initOnboarding();
  }

  Future<void> _initOnboarding() async {
    isLoading = true;
    notifyListeners();

    try {
      final progress = await _api.getOnboardingProgress();
      if (progress.isNotEmpty && _isProgressCompatible(progress)) {
        messages = progress;
        questionCount = messages.where((m) => m['role'] == 'user').length;
        if (questionCount >= maxQuestions) {
          // Si ya respondió todas pero por alguna razón no avanzó, finalizamos
          await finalizeOnboarding();
        } else if (messages.last['role'] == 'user') {
          // Si el último mensaje es del usuario, toca que Jarvis pregunte
          _fetchNextQuestion();
        } else {
          // El último mensaje ya es la pregunta pendiente; solo restauramos
          // el indicador de área/progreso para que coincida.
          _syncAreaProgress();
        }
      } else if (progress.isNotEmpty) {
        // Progreso guardado de una versión anterior del brief (preguntas
        // generadas por IA que ya no coinciden con el banco fijo actual, o
        // corrupto por el bug de errores-como-preguntas). Se descarta y se
        // empieza de cero, tanto local como en el backend.
        messages = [];
        questionCount = 0;
        await _api.saveOnboardingProgress(messages);
        _fetchNextQuestion();
      } else {
        _fetchNextQuestion();
      }
    } catch (e) {
      // Si falla obtener el progreso (ej: backend cambió, endpoint removido,
      // o datos corruptos), borramos el caché viejo y empezamos de cero.
      // Esto evita que cambios backend dejen la app en estado inconsistente.
      errorMessage = null;
      messages = [];
      questionCount = 0;
      _fetchNextQuestion();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Reinicia la conversación para un re-brief mensual (actualizar metas)
  /// en vez de retomar la del onboarding original que ya quedó completa.
  Future<void> startRebrief() async {
    messages = [];
    questionCount = 0;
    errorMessage = null;
    currentAreaLabel = null;
    currentAreaIndex = 0;
    currentQuestionNumber = 0;
    notifyListeners();
    _fetchNextQuestion();
  }

  /// Compara el progreso guardado contra el banco fijo de preguntas
  /// actual, pregunta por pregunta. Si alguna no coincide (venía de la IA
  /// generándolas dinámicamente en una versión anterior, o el banco de
  /// preguntas cambió), el progreso ya no es válido.
  bool _isProgressCompatible(List<Map<String, String>> progress) {
    int qIndex = 0;
    for (final m in progress) {
      if (m['role'] != 'jarvis') continue;
      if (qIndex >= onboardingQuestions.length) return false;
      if (m['text'] != onboardingQuestions[qIndex].question) return false;
      qIndex++;
    }
    return true;
  }

  void _syncAreaProgress() {
    if (questionCount >= onboardingQuestions.length) return;
    final q = onboardingQuestions[questionCount];
    currentAreaLabel = q.areaLabel;
    currentAreaIndex = questionCount ~/ questionsPerArea;
    currentQuestionNumber = (questionCount % questionsPerArea) + 1;
  }

  // Pregunta local: viene de un banco fijo de 50 preguntas, no de una
  // llamada a la IA, así que nunca puede fallar por red.
  void _fetchNextQuestion() {
    if (questionCount >= onboardingQuestions.length) return;
    final q = onboardingQuestions[questionCount];
    currentAreaLabel = q.areaLabel;
    currentAreaIndex = questionCount ~/ questionsPerArea;
    currentQuestionNumber = (questionCount % questionsPerArea) + 1;
    messages.add({'role': 'jarvis', 'text': q.question});
    notifyListeners();
    // Se guarda en segundo plano; si falla la conexión no se pierde nada
    // localmente, solo no queda respaldado hasta la próxima vez que ande.
    _api.saveOnboardingProgress(messages);
  }

  bool get canGoBack => questionCount > 0 && !isLoading;

  /// Descarta la pregunta actual (sin responder) y la respuesta anterior,
  /// dejando la pregunta anterior lista para responderla de nuevo. Útil
  /// si el usuario se equivocó y quiere corregir una respuesta anterior.
  void goBack() {
    if (!canGoBack) return;

    if (messages.isNotEmpty && messages.last['role'] == 'jarvis') {
      messages.removeLast();
    }
    if (messages.isNotEmpty && messages.last['role'] == 'user') {
      messages.removeLast();
      questionCount--;
    }
    errorMessage = null;
    _syncAreaProgress();
    notifyListeners();
    _api.saveOnboardingProgress(messages);
  }

  Future<bool> submitAnswer(String answer) async {
    if (answer.trim().isEmpty) return false;

    messages.add({'role': 'user', 'text': answer});
    questionCount++;
    errorMessage = null;
    notifyListeners();

    // Guardar progreso en el backend
    await _api.saveOnboardingProgress(messages);

    if (questionCount >= maxQuestions) {
      return await finalizeOnboarding();
    } else {
      _fetchNextQuestion();
      return false; // Not finished yet
    }
  }

  /// Único paso que todavía llama a la IA (genera el Life Blueprint a
  /// partir de las 50 respuestas). Si falla por un error transitorio, no
  /// se pierde ninguna respuesta: solo hay que reintentar este paso.
  Future<bool> finalizeOnboarding() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final success = await _api.submitAssessment(messages);
      if (!success) throw Exception('Falló al guardar el blueprint');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_blueprint', true);
      await NotificationService.instance.scheduleMorningReminder();

      return true; // Navigates to Chat
    } catch (e) {
      errorMessage = 'No se pudo generar tu Life Blueprint (${e.toString().replaceFirst('Exception: ', '')}). Puedes reintentar.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
