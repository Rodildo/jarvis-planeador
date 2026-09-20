import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'JARVIS_API_URL',
    defaultValue: 'https://app-jarvisplanner.hzedxy.easypanel.host/api',
  );
  static const String _tokenPrefsKey = 'auth_token';

  static String? _token;

  /// Se dispara cuando cualquier llamada devuelve 401 (token vencido o
  /// revocado), para que la app pueda cerrar sesión y volver a /login.
  static VoidCallback? onUnauthorized;

  static bool get isLoggedIn => _token != null;

  static Future<void> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenPrefsKey);
  }

  static Future<void> _setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefsKey, token);
  }

  Future<void> logout() async {
    ApiService._token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefsKey);
    await prefs.remove('has_blueprint');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  void _reportIfUnauthorized(http.Response response) {
    if (response.statusCode == 401) onUnauthorized?.call();
  }

  Future<void> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['token'] != null) {
      await _setToken(data['token']);
      return;
    }
    throw Exception(data['error'] ?? 'No se pudo crear la cuenta.');
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      await _setToken(data['token']);
      return;
    }
    throw Exception(data['error'] ?? 'Correo o contraseña incorrectos.');
  }

  Future<bool> checkProfile() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/profile'), headers: _headers);
      _reportIfUnauthorized(response);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['hasBlueprint'] ?? false;
      }
    } catch (e) {
      print('Check profile error: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getTodayLog() async {
    try {
      final date = DateTime.now().toIso8601String().split('T')[0];
      final response = await http.get(Uri.parse('$baseUrl/daily-log/$date'), headers: _headers);
      _reportIfUnauthorized(response);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['dailyLog'];
      }
    } catch (e) {
      print('Get today log error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getHistory({int days = 30}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/history?days=$days'), headers: _headers);
      _reportIfUnauthorized(response);
      if (response.statusCode == 200) {
        final logs = jsonDecode(response.body)['logs'] as List;
        return logs.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Get history error: $e');
    }
    return [];
  }

  /// Devuelve { 'blueprint': {...}, 'updatedAt': 'ISO date string' } o null
  /// si el usuario todavía no completó su primer brief.
  Future<Map<String, dynamic>?> getLifeBlueprint() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/blueprint'), headers: _headers);
      _reportIfUnauthorized(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'blueprint': data['blueprint'], 'updatedAt': data['updatedAt']};
      }
    } catch (e) {
      print('Get blueprint error: $e');
    }
    return null;
  }

  Future<List<Map<String, String>>> getOnboardingProgress() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/onboarding/progress'), headers: _headers);
      _reportIfUnauthorized(response);
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
      final response = await http.post(
        Uri.parse('$baseUrl/onboarding/progress'),
        headers: _headers,
        body: jsonEncode({'messages': messages}),
      );
      _reportIfUnauthorized(response);
    } catch (e) {
      print('Save onboarding progress error: $e');
    }
  }

  /// Devuelve { question, areaKey, areaLabel, areaIndex, questionNumber, totalQuestions }.
  Future<Map<String, dynamic>> getOnboardingQuestion(List<Map<String, String>> previousQA) async {
    final response = await http.post(
      Uri.parse('$baseUrl/onboarding/question'),
      headers: _headers,
      body: jsonEncode({'previousQA': previousQA}),
    );
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch question: ${response.body}');
  }

  Future<bool> submitAssessment(List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assessment'),
      headers: _headers,
      body: jsonEncode({'answers': jsonEncode(messages)}),
    );
    _reportIfUnauthorized(response);
    return response.statusCode == 200;
  }

  /// Devuelve { greeting, morning: [{task, reason}], midday: [...], night: [...] }.
  Future<Map<String, dynamic>> getDailyPlan(int energyLevel) async {
    final response = await http.post(
      Uri.parse('$baseUrl/daily-plan'),
      headers: _headers,
      body: jsonEncode({
        'date': DateTime.now().toIso8601String().split('T')[0],
        'energyLevel': energyLevel
      }),
    );
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['plan'];
    }
    throw Exception('Failed to fetch daily plan: ${response.body}');
  }

  /// Guarda el estado completo del día (plan + tareas completadas + tareas
  /// manuales). Se llama cada vez que algo cambia, no solo una vez.
  Future<bool> saveDailyState(Map<String, dynamic> state) async {
    final response = await http.post(
      Uri.parse('$baseUrl/daily-actions'),
      headers: _headers,
      body: jsonEncode({
        'date': DateTime.now().toIso8601String().split('T')[0],
        'actions': state
      }),
    );
    _reportIfUnauthorized(response);
    return response.statusCode == 200;
  }

  Future<String> triggerMiddayCheck(int energyLevel) async {
    final response = await http.post(
      Uri.parse('$baseUrl/midday'),
      headers: _headers,
      body: jsonEncode({
        'date': DateTime.now().toIso8601String().split('T')[0],
        'energyLevel': energyLevel
      }),
    );
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['message'];
    }
    throw Exception('Failed midday check');
  }
}
