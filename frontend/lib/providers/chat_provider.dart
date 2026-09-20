import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool isLoading = false;
  bool isRecording = false;
  String jarvisMessage = "¡Buenos días! Soy Jarvis. ¿Del 1 al 5, cómo está tu nivel de energía hoy?";
  
  Map<String, dynamic>? morningOptions;
  Map<String, dynamic> selectedActions = {};
  bool dayStarted = false;
  bool showMiddayInput = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  void toggleAction(String goal, dynamic option) {
    selectedActions[goal] = option;
    notifyListeners();
  }

  Future<void> requestBriefing(String textInput) async {
    final text = textInput.trim();
    int? energyLevel = int.tryParse(text);
    if (energyLevel == null) {
      final match = RegExp(r'[1-5]').firstMatch(text);
      if (match != null) energyLevel = int.parse(match.group(0)!);
    }

    if (energyLevel == null || energyLevel < 1 || energyLevel > 5) {
      jarvisMessage = "Por favor ingresa un nivel válido del 1 al 5.";
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final responseData = await _api.getBriefing(energyLevel);
      
      if (responseData.containsKey('greeting')) {
        jarvisMessage = responseData['greeting'];
      } else {
        jarvisMessage = "Aquí tienes tus opciones para hoy. Selecciona una intensidad por cada objetivo.";
      }

      Map<String, dynamic> formattedOptions = {};
      if (responseData.containsKey('goals') && responseData['goals'] is List) {
        for (var goalData in responseData['goals']) {
          String goalName = goalData['goal_name'] ?? 'Meta';
          List options = goalData['options'] ?? [];
          for (var opt in options) {
            if (opt is Map<String, dynamic>) {
              if (opt.containsKey('level') && !opt.containsKey('intensity')) {
                opt['intensity'] = opt['level'];
              }
            }
          }
          formattedOptions[goalName] = options;
        }
        morningOptions = formattedOptions;
      } else {
        morningOptions = responseData;
      }
    } catch (e) {
      jarvisMessage = "Error de conexión: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmDay() async {
    isLoading = true;
    notifyListeners();
    
    try {
      await _api.confirmDailyActions(selectedActions);
      dayStarted = true;
      jarvisMessage = "¡Día guardado con éxito! Ve a cumplir tus metas. Me comunicaré contigo en 6 horas.";
    } catch (e) {
      jarvisMessage = "Error guardando el día: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void showMidday() {
    showMiddayInput = true;
    jarvisMessage = "Han pasado 6 horas. ¿Cómo está tu nivel de energía en este momento (1-5)?";
    notifyListeners();
  }

  Future<void> triggerMiddayCheck(String textInput) async {
    final text = textInput.trim();
    int? energyLevel = int.tryParse(text);
    if (energyLevel == null) {
      final match = RegExp(r'[1-5]').firstMatch(text);
      if (match != null) energyLevel = int.parse(match.group(0)!);
    }

    if (energyLevel == null || energyLevel < 1 || energyLevel > 5) return;
    
    isLoading = true;
    notifyListeners();
    
    try {
      jarvisMessage = await _api.triggerMiddayCheck(energyLevel);
      showMiddayInput = false;
    } catch (e) {
      jarvisMessage = "Error en el chequeo de 6h: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      await _audioRecorder.start(const RecordConfig(), path: '${dir.path}/audio.webm');
      isRecording = true;
      notifyListeners();
    }
  }

  Future<String?> stopRecordingAndTranscribe() async {
    if (!isRecording) return null;
    final path = await _audioRecorder.stop();
    isRecording = false;
    notifyListeners();
    
    if (path != null) {
      isLoading = true;
      notifyListeners();
      try {
        return await _api.transcribeAudio(path);
      } catch (e) {
        jarvisMessage = "Error subiendo audio: $e";
      } finally {
        isLoading = false;
        notifyListeners();
      }
    }
    return null;
  }
}
