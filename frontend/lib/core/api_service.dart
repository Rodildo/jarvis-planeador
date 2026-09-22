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
  static const String _firstNamePrefsKey = 'user_first_name';
  static const String _lastNamePrefsKey = 'user_last_name';
  static const String _avatarPrefsKey = 'user_avatar';

  static String? _token;
  static String? _firstName;
  static String? _lastName;
  static String? _avatar;

  // Caché en memoria (dura lo que dura la sesión de la app, se limpia en
  // logout). El blueprint casi no cambia (solo en un re-brief mensual) y
  // el historial de hoy no cambia por fuera de esta misma app, así que no
  // hay riesgo real de mostrar algo desactualizado dentro de una sesión.
  static Map<String, dynamic>? _cachedBlueprint;
  static List<Map<String, dynamic>>? _cachedHistory;

  /// Se dispara cuando cualquier llamada devuelve 401 (token vencido o
  /// revocado), para que la app pueda cerrar sesión y volver a /login.
  static VoidCallback? onUnauthorized;

  /// Mensaje a mostrar una sola vez en la pantalla de login después de que
  /// el token quedó inválido en medio de una sesión (no aplica a un login
  /// fallido normal, ese ya tiene su propio mensaje de error).
  static String? sessionExpiredMessage;

  static bool get isLoggedIn => _token != null;
  static String? get firstName => _firstName;
  static String? get lastName => _lastName;
  /// Data URI (data:image/jpeg;base64,...) o null si no hay foto de perfil.
  static String? get avatar => _avatar;

  // Ninguna llamada de red de este archivo tenía timeout explícito: sin
  // esto, un `http.get`/`post` puede quedarse esperando el default del
  // sistema operativo (mucho más largo que unos segundos, sobre todo justo
  // después de un rato con la app cerrada y la conexión "dormida") en vez
  // de fallar rápido y dejar que la lógica de reintentos de cada método
  // haga su trabajo. `_defaultTimeout` cubre los endpoints normales
  // (lectura/escritura simple contra la base de datos, deberían responder
  // casi al instante); `_aiTimeout` es más generoso para los 3 endpoints
  // que le pegan a la IA (OpenRouter), que legítimamente pueden tardar
  // más — sobre todo si el backend necesita reintentar una generación con
  // JSON truncado (ver backend/src/ai/gemini.ts).
  static const Duration _defaultTimeout = Duration(seconds: 12);
  static const Duration _uploadTimeout = Duration(seconds: 30);
  static const Duration _aiTimeout = Duration(seconds: 90);

  static Never _timeoutError() =>
      throw Exception('Se agotó el tiempo de espera. Revisa tu conexión e intenta de nuevo.');

  static Future<void> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenPrefsKey);
    _firstName = prefs.getString(_firstNamePrefsKey);
    _lastName = prefs.getString(_lastNamePrefsKey);
    _avatar = prefs.getString(_avatarPrefsKey);
  }

  static Future<void> _setSession(String token, String firstName, String lastName) async {
    _token = token;
    _firstName = firstName;
    _lastName = lastName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefsKey, token);
    await prefs.setString(_firstNamePrefsKey, firstName);
    await prefs.setString(_lastNamePrefsKey, lastName);
  }

  Future<void> logout() async {
    ApiService._token = null;
    ApiService._firstName = null;
    ApiService._lastName = null;
    ApiService._avatar = null;
    ApiService._cachedBlueprint = null;
    ApiService._cachedHistory = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefsKey);
    await prefs.remove(_firstNamePrefsKey);
    await prefs.remove(_lastNamePrefsKey);
    await prefs.remove(_avatarPrefsKey);
    await prefs.remove('has_blueprint');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Extrae el mensaje de error del backend si viene en formato legible
  /// (ej. límites de solicitudes, validaciones). Si no (por ejemplo, un
  /// timeout del proxy que devuelve una página HTML de error en vez de
  /// JSON — el caso típico tras un rato de inactividad del servidor),
  /// usa el mensaje genérico pero le agrega el código HTTP real, para
  /// que quede algo diagnosticable en vez de un mensaje mudo.
  String _friendlyError(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
    } catch (_) {}
    return '$fallback (código ${response.statusCode})';
  }

  void _reportIfUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      sessionExpiredMessage = 'Tu sesión expiró. Inicia sesión de nuevo.';
      logout();
      onUnauthorized?.call();
    }
  }

  /// Público, sin auth. Se consulta al arrancar la app para saber si esta
  /// versión instalada ya quedó obsoleta (ver kAppBuildNumber en
  /// core/app_info.dart) y hay que bloquear el uso pidiendo actualizar.
  /// Si la llamada falla (sin red, servidor caído), devuelve null — nunca
  /// debe bloquear al usuario por un problema de conexión, solo por una
  /// versión de verdad desactualizada.
  Future<Map<String, dynamic>?> getVersionInfo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/version')).timeout(_defaultTimeout, onTimeout: _timeoutError);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Get version info error: $e');
    }
    return null;
  }

  Future<void> register(String email, String password, String firstName, String lastName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'firstName': firstName, 'lastName': lastName}),
    ).timeout(_defaultTimeout, onTimeout: _timeoutError);
    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['token'] != null) {
      await _setSession(data['token'], data['firstName'] ?? firstName, data['lastName'] ?? lastName);
      return;
    }
    throw Exception(data['error'] ?? 'No se pudo crear la cuenta.');
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(_defaultTimeout, onTimeout: _timeoutError);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      await _setSession(data['token'], data['firstName'] ?? '', data['lastName'] ?? '');
      return;
    }
    throw Exception(data['error'] ?? 'Correo o contraseña incorrectos.');
  }

  Future<bool> checkProfile() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/profile'), headers: _headers).timeout(_defaultTimeout, onTimeout: _timeoutError);
      _reportIfUnauthorized(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        if (data['firstName'] != null && data['lastName'] != null) {
          _firstName = data['firstName'];
          _lastName = data['lastName'];
          await prefs.setString(_firstNamePrefsKey, _firstName!);
          await prefs.setString(_lastNamePrefsKey, _lastName!);
        }
        _avatar = data['avatar'];
        if (_avatar != null) {
          await prefs.setString(_avatarPrefsKey, _avatar!);
        } else {
          await prefs.remove(_avatarPrefsKey);
        }
        return data['hasBlueprint'] ?? false;
      }
    } catch (e) {
      print('Check profile error: $e');
    }
    return false;
  }

  Future<void> updateProfile(String firstName, String lastName) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/profile'),
      headers: _headers,
      body: jsonEncode({'firstName': firstName, 'lastName': lastName}),
    ).timeout(_defaultTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _firstName = data['firstName'] ?? firstName;
      _lastName = data['lastName'] ?? lastName;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_firstNamePrefsKey, _firstName!);
      await prefs.setString(_lastNamePrefsKey, _lastName!);
      return;
    }
    throw Exception(data['error'] ?? 'No se pudo actualizar tu perfil.');
  }

  /// [dataUri] ya debe venir comprimido/redimensionado del lado del
  /// cliente (ver image_picker maxWidth/maxHeight/imageQuality), en
  /// formato "data:image/jpeg;base64,...".
  Future<void> uploadAvatar(String dataUri) async {
    final response = await http.put(
      Uri.parse('$baseUrl/profile/avatar'),
      headers: _headers,
      body: jsonEncode({'avatar': dataUri}),
    ).timeout(_uploadTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      _avatar = dataUri;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefsKey, dataUri);
      return;
    }
    throw Exception(_friendlyError(response, 'No se pudo subir la foto de perfil.'));
  }

  Future<void> removeAvatar() async {
    final response = await http.delete(Uri.parse('$baseUrl/profile/avatar'), headers: _headers).timeout(_defaultTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      _avatar = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_avatarPrefsKey);
      return;
    }
    throw Exception(_friendlyError(response, 'No se pudo quitar la foto de perfil.'));
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: _headers,
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    ).timeout(_defaultTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) return;
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'No se pudo cambiar tu contraseña.');
  }

  /// Verifica la contraseña actual sin ningún efecto secundario (a
  /// diferencia de changePassword/deleteAccount, que sí cambian algo). Se
  /// usa para pedir confirmación con contraseña antes de acciones
  /// importantes, como regenerar el Life Blueprint.
  Future<void> verifyPassword(String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-password'),
      headers: _headers,
      body: jsonEncode({'password': password}),
    ).timeout(_defaultTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) return;
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'No se pudo verificar tu contraseña.');
  }

  /// Elimina la cuenta (y todos sus datos) en el backend, y limpia la
  /// sesión local si tiene éxito.
  Future<void> deleteAccount(String password) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/account'),
      headers: _headers,
      body: jsonEncode({'password': password}),
    ).timeout(_defaultTimeout, onTimeout: _timeoutError);
    if (response.statusCode == 200) {
      await logout();
      return;
    }
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'No se pudo eliminar tu cuenta.');
  }

  /// Se llama justo al abrir la app (antes de que la conexión termine de
  /// "despertar" tras un arranque en frío), así que un solo intento fallido
  /// aquí no debe bastar para asumir que no hay plan guardado hoy — eso
  /// mandaría al usuario a pedir energía de nuevo y, si la responde,
  /// generaría un plan nuevo que pisa el de verdad. Reintenta un par de
  /// veces antes de rendirse.
  Future<Map<String, dynamic>?> getTodayLog() async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/daily-log/$date'), headers: _headers).timeout(_defaultTimeout, onTimeout: _timeoutError);
        _reportIfUnauthorized(response);
        if (response.statusCode == 200) {
          return jsonDecode(response.body)['dailyLog'];
        }
        return null;
      } catch (e) {
        print('Get today log error (intento $attempt): $e');
        if (attempt < 3) await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    return null;
  }

  // Future en curso, compartido entre llamadas simultáneas a getHistory
  // (ver más abajo por qué hace falta).
  static Future<List<Map<String, dynamic>>>? _historyInFlight;

  /// Con caché en memoria: si ya se pidió el historial antes en esta
  /// sesión, se devuelve al instante sin esperar otro viaje de red. Se
  /// llama en segundo plano apenas se entra a /chat (ver ChatProvider)
  /// para que, cuando el usuario abra Historial, ya esté listo.
  ///
  /// **De-duplicación de peticiones en curso**: si `ChatProvider` ya
  /// disparó esta misma llamada en segundo plano y el usuario abre
  /// Historial antes de que termine, sin esto se dispararían DOS viajes de
  /// red independientes al mismo endpoint — justo en el peor momento
  /// (arranque en frío, conexión recién reconectando), duplicando la carga
  /// de red cuando menos ancho de banda hay disponible. En vez de eso, la
  /// segunda llamada espera el resultado de la que ya estaba en curso.
  Future<List<Map<String, dynamic>>> getHistory({int days = 30, bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedHistory != null) return _cachedHistory!;
    final inFlight = _historyInFlight;
    if (inFlight != null) return inFlight;

    final future = _fetchHistory(days);
    _historyInFlight = future;
    try {
      return await future;
    } finally {
      _historyInFlight = null;
    }
  }

  // Un solo intento (con timeout) por llamada: history_screen.dart ya
  // reintenta por su cuenta cada 3 segundos mientras no haya datos (ver
  // docs/reference/06-decisions.md), así que reintentar también aquí
  // adentro solo alargaba cada ciclo sin necesidad (hasta ~36s por llamada
  // antes de este cambio, sumado a los reintentos de la pantalla).
  Future<List<Map<String, dynamic>>> _fetchHistory(int days) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/history?days=$days'), headers: _headers).timeout(_defaultTimeout, onTimeout: _timeoutError);
      _reportIfUnauthorized(response);
      if (response.statusCode == 200) {
        final logs = (jsonDecode(response.body)['logs'] as List).cast<Map<String, dynamic>>();
        _cachedHistory = logs;
        return logs;
      }
    } catch (e) {
      print('Get history error: $e');
    }
    return _cachedHistory ?? [];
  }

  static Future<Map<String, dynamic>?>? _blueprintInFlight;

  /// Devuelve { 'blueprint': {...}, 'updatedAt': 'ISO date string' } o null
  /// si el usuario todavía no completó su primer brief. Con caché en
  /// memoria: justo después de terminar el brief (submitAssessment) ya
  /// queda precargado, así que la primera vez que se abre "Mi Plan
  /// Maestro" no hace falta esperar otro viaje de red.
  ///
  /// De-duplicación de peticiones en curso: mismo motivo que getHistory
  /// (la precarga en segundo plano de `ChatProvider` y esta pantalla
  /// pueden pedir lo mismo casi al mismo tiempo).
  Future<Map<String, dynamic>?> getLifeBlueprint({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBlueprint != null) return _cachedBlueprint;
    final inFlight = _blueprintInFlight;
    if (inFlight != null) return inFlight;

    final future = _fetchLifeBlueprint();
    _blueprintInFlight = future;
    try {
      return await future;
    } finally {
      _blueprintInFlight = null;
    }
  }

  // Un solo intento (con timeout) por llamada — blueprint_screen.dart ya
  // reintenta por su cuenta cada 3 segundos mientras no haya datos. Un 404
  // real (el usuario nunca hizo el brief) no es un fallo de red, es la
  // respuesta definitiva; de cualquier forma esta función ya no distingue
  // ese caso del de una falla real, porque sin loop interno no hace falta
  // — ambos simplemente devuelven null y dejan que la pantalla decida.
  Future<Map<String, dynamic>?> _fetchLifeBlueprint() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/blueprint'), headers: _headers).timeout(_defaultTimeout, onTimeout: _timeoutError);
      _reportIfUnauthorized(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = {'blueprint': data['blueprint'], 'updatedAt': data['updatedAt']};
        _cachedBlueprint = result;
        return result;
      }
    } catch (e) {
      print('Get blueprint error: $e');
    }
    return null;
  }

  /// A diferencia de la mayoría de los GET de este archivo, este SÍ lanza
  /// en caso de fallo de red/servidor en vez de devolver []: el llamador
  /// necesita distinguir "no hay progreso guardado todavía" (200 con
  /// mensajes vacíos) de "no pudimos saberlo" (para no perder el brief de
  /// un usuario que ya iba avanzado por un simple corte de conexión).
  Future<List<Map<String, String>>> getOnboardingProgress() async {
    final response = await http.get(Uri.parse('$baseUrl/onboarding/progress'), headers: _headers).timeout(_defaultTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['messages'] != null) {
        return List<Map<String, String>>.from(
          (data['messages'] as List).map((e) => Map<String, String>.from(e))
        );
      }
      return [];
    }
    throw Exception(_friendlyError(response, 'No se pudo cargar tu progreso.'));
  }

  Future<void> saveOnboardingProgress(List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/onboarding/progress'),
        headers: _headers,
        body: jsonEncode({'messages': messages}),
      ).timeout(_defaultTimeout, onTimeout: _timeoutError);
      _reportIfUnauthorized(response);
    } catch (e) {
      print('Save onboarding progress error: $e');
    }
  }

  Future<bool> submitAssessment(List<Map<String, String>> messages, String language) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assessment'),
      headers: _headers,
      body: jsonEncode({'answers': jsonEncode(messages), 'language': language}),
    ).timeout(_aiTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode != 200) return false;

    // El backend no manda `updatedAt` en esta respuesta (solo lo hace el
    // GET /blueprint); como se acaba de guardar, "ahora mismo" en UTC es
    // exacto. Mismo formato que CURRENT_TIMESTAMP de SQLite para que
    // blueprint_screen.dart lo parsee igual que si viniera del backend.
    final blueprint = jsonDecode(response.body)['blueprint'];
    if (blueprint != null) {
      final now = DateTime.now().toUtc().toIso8601String().split('.').first.replaceFirst('T', ' ');
      _cachedBlueprint = {'blueprint': blueprint, 'updatedAt': now};
    }
    return true;
  }

  /// Devuelve { greeting, morning: [{task, reason}], midday: [...], night: [...] }.
  Future<Map<String, dynamic>> getDailyPlan(int energyLevel, String language) async {
    final response = await http.post(
      Uri.parse('$baseUrl/daily-plan'),
      headers: _headers,
      body: jsonEncode({
        'date': DateTime.now().toIso8601String().split('T')[0],
        'energyLevel': energyLevel,
        'language': language,
      }),
    ).timeout(_aiTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['plan'];
    }
    throw Exception(_friendlyError(response, 'No se pudo generar tu plan del día.'));
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
    ).timeout(_defaultTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    return response.statusCode == 200;
  }

  /// Devuelve { message, plan, completed }. `plan`/`completed` solo vienen
  /// presentes cuando el backend decidió que el cambio de energía ameritaba
  /// regenerar las tareas restantes del día (mediodía/noche); si no, vienen
  /// null y el plan actual no cambia.
  Future<Map<String, dynamic>> triggerMiddayCheck(int energyLevel, String language) async {
    final response = await http.post(
      Uri.parse('$baseUrl/midday'),
      headers: _headers,
      body: jsonEncode({
        'date': DateTime.now().toIso8601String().split('T')[0],
        'energyLevel': energyLevel,
        'language': language,
      }),
    ).timeout(_aiTimeout, onTimeout: _timeoutError);
    _reportIfUnauthorized(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'message': data['message'],
        'plan': data['plan'],
        'completed': data['completed'],
      };
    }
    throw Exception(_friendlyError(response, 'No se pudo hacer el chequeo de energía.'));
  }
}
