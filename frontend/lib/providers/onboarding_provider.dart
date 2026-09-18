import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../core/api_service.dart';

class OnboardingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  List<Map<String, String>> messages = [];
  bool isLoading = false;
  bool isRecording = false;
  int questionCount = 0;
  final int maxQuestions = 5;
  String? errorMessage;

  OnboardingProvider() {
    _fetchNextQuestion();
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
      return true; // Navigates to Chat
    } catch (e) {
      errorMessage = e.toString();
      messages.add({'role': 'jarvis', 'text': 'Error: $e'});
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      await _audioRecorder.start(const RecordConfig(), path: 'audio.webm');
      isRecording = true;
      notifyListeners();
    }
  }

  Future<bool> stopRecordingAndSubmit() async {
    if (!isRecording) return false;
    final path = await _audioRecorder.stop();
    isRecording = false;
    notifyListeners();
    
    if (path != null) {
      isLoading = true;
      notifyListeners();
      try {
        final text = await _api.transcribeAudio(path);
        if (text != null && text.isNotEmpty) {
          return await submitAnswer(text);
        }
      } catch (e) {
        errorMessage = e.toString();
        messages.add({'role': 'jarvis', 'text': 'Error subiendo audio: $e'});
      } finally {
        isLoading = false;
        notifyListeners();
      }
    }
    return false;
  }
}
