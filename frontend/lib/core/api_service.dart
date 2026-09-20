import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://app-jarvisplanner.hzedxy.easypanel.host/api';
  static const String userId = 'default_user';

  Future<String?> transcribeAudio(String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/transcribe'));
    request.files.add(await http.MultipartFile.fromPath('audio', filePath));
    final response = await request.send();
    if (response.statusCode == 200) {
      final resData = await response.stream.bytesToString();
      return jsonDecode(resData)['text'];
    }
    return null;
  }

  Future<bool> checkProfile() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/profile/$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['hasBlueprint'] ?? false;
      }
    } catch (e) {
      print('Check profile error: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getLifeBlueprint() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/blueprint/$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['blueprint'];
      }
    } catch (e) {
      print('Get blueprint error: $e');
    }
    return null;
  }

  Future<List<Map<String, String>>> getOnboardingProgress() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/onboarding/progress/$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['messages'] != null) {
          return List<Map<String, String>>.from(
            (data['messages'] as List).map((e) => Map<String, String>.from(e))
          );
        }
      }
    } catch (e) {
      print('Get onboarding progress error: $e');
    }
    return [];
  }

  Future<void> saveOnboardingProgress(List<Map<String, String>> messages) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/onboarding/progress'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'messages': messages}),
      );
    } catch (e) {
      print('Save onboarding progress error: $e');
    }
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
    throw Exception('Failed to fetch briefing: ${response.body}');
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
