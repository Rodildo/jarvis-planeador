import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';

class OnboardingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<Map<String, String>> messages = [];
  bool isLoading = false;
  int questionCount = 0;
  final int maxQuestions = 5;
  String? errorMessage;

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
          // Si ya respondió 5 pero por alguna razón no avanzó, finalizamos
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

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _fetchNextQuestion() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    
    try {
      final question = await _api.getOnboardingQuestion(messages);
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
