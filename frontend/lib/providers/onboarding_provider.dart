import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/notification_service.dart';

class OnboardingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Map<String, String>> messages = [];
  bool isLoading = false;
  int questionCount = 0;
  final int maxQuestions = 50;
  String? errorMessage;

  // Progreso por área (5 áreas x 10 preguntas), lo manda el backend con
  // cada pregunta para poder mostrar "Área 2/5 · Pregunta 3/10".
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
      if (progress.isNotEmpty) {
        messages = progress;
        questionCount = messages.where((m) => m['role'] == 'user').length;
        if (questionCount >= maxQuestions) {
          // Si ya respondió todas pero por alguna razón no avanzó, finalizamos
          await _finalizeOnboarding();
        } else if (messages.last['role'] == 'user') {
          // Si el último mensaje es del usuario, toca que Jarvis pregunte
          await _fetchNextQuestion();
        }
      } else {
        await _fetchNextQuestion();
      }
    } catch (e) {
      errorMessage = e.toString();
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
    await _fetchNextQuestion();
  }

  Future<void> _fetchNextQuestion() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.getOnboardingQuestion(messages);
      final question = result['question']?.toString() ?? '';
      currentAreaLabel = result['areaLabel']?.toString();
      currentAreaIndex = result['areaIndex'] is int ? result['areaIndex'] : 0;
      currentQuestionNumber = result['questionNumber'] is int ? result['questionNumber'] : 0;
      messages.add({'role': 'jarvis', 'text': question});
      await _api.saveOnboardingProgress(messages);
    } catch (e) {
      errorMessage = e.toString();
      messages.add({'role': 'jarvis', 'text': 'Error: $e'});
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitAnswer(String answer) async {
    if (answer.trim().isEmpty) return false;

    messages.add({'role': 'user', 'text': answer});
    questionCount++;
    notifyListeners();

    // Guardar progreso en el backend
    await _api.saveOnboardingProgress(messages);

    if (questionCount >= maxQuestions) {
      return await _finalizeOnboarding();
    } else {
      await _fetchNextQuestion();
      return false; // Not finished yet
    }
  }

  Future<bool> _finalizeOnboarding() async {
    isLoading = true;
    messages.add({'role': 'jarvis', 'text': 'Creando tu Life Blueprint...'});
    notifyListeners();

    try {
      final success = await _api.submitAssessment(messages);
      if (!success) throw Exception('Falló al guardar el blueprint');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_blueprint', true);
      await NotificationService.instance.scheduleMorningReminder();

      return true; // Navigates to Chat
    } catch (e) {
      errorMessage = e.toString();
      messages.add({'role': 'jarvis', 'text': 'Error: $e'});
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
