import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://app-jarvisplanner.hzedxy.easypanel.host/api';
  static const String userId = 'default_user';

  Future<String?> transcribeAudio(String path) async {
    final bytes = await File(path).readAsBytes();
    
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/transcribe'));
    request.files.add(http.MultipartFile.fromBytes('audio', bytes, filename: 'audio.webm'));
    
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return jsonDecode(responseData)['text'];
    }
    throw Exception('Error transcribing audio');
  }

  Future<String> getOnboardingQuestion(List<Map<String, String>> previousQA) async {
    final response = await http.post(
      Uri.parse('$baseUrl/onboarding/question'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'previousQA': previousQA}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['question'];
    }
    throw Exception('Failed to fetch question: ${response.body}');
  }

  Future<bool> submitAssessment(List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assessment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'answers': jsonEncode(messages)}),
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> getBriefing(int energyLevel) async {
    final response = await http.post(
      Uri.parse('$baseUrl/briefing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'energyLevel': energyLevel
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['briefing'];
    }
    throw Exception('Failed to fetch briefing');
  }

  Future<bool> confirmDailyActions(Map<String, dynamic> selectedActions) async {
    final response = await http.post(
      Uri.parse('$baseUrl/daily-actions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'actions': selectedActions
      }),
    );
    return response.statusCode == 200;
  }

  Future<String> triggerMiddayCheck(int energyLevel) async {
    final response = await http.post(
      Uri.parse('$baseUrl/midday'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'energyLevel': energyLevel
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['message'];
    }
    throw Exception('Failed midday check');
  }
}
