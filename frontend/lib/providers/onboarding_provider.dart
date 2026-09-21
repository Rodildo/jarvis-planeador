import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/notification_service.dart';
import '../core/onboarding_questions.dart';
import '../core/i18n/app_language.dart';

class OnboardingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final AppLanguage _lang;

  static const String _localBackupKey = 'onboarding_local_backup';

  List<Map<String, String>> messages = [];
  bool isLoading = false;
  int questionCount = 0;
  final int maxQuestions = totalOnboardingQuestions;
  String? errorMessage;

  /// Cuando se responden las 50 preguntas, no se genera el blueprint de
  /// inmediato: se deja revisar/editar cualquier respuesta antes de
  /// confirmar, para no perder el brief entero por una respuesta apurada.
  bool reviewMode = false;

  // Progreso por área (5 áreas x 10 preguntas), para mostrar
  // "Área 2/5 · Pregunta 3/10". Viene del banco fijo de preguntas, no de
  // la IA, así que nunca falla por red.
  String? currentAreaLabel;
  int currentAreaIndex = 0;
  int currentQuestionNumber = 0;

  List<OnboardingQuestion> get questions => getOnboardingQuestions(_lang.code);

  OnboardingProvider(this._lang) {
    _initOnboarding();
  }

  Future<void> _initOnboarding() async {
    isLoading = true;
    notifyListeners();

    try {
      final progress = await _api.getOnboardingProgress();
      if (progress.isNotEmpty && _isProgressCompatible(progress)) {
        _restoreFromMessages(progress);
      } else if (progress.isNotEmpty) {
        // Progreso guardado de una versión anterior del brief (preguntas
        // generadas por IA que ya no coinciden con el banco fijo actual, o
        // corrupto por el bug de errores-como-preguntas). Se descarta y se
        // empieza de cero, tanto local como en el backend.
        messages = [];
        questionCount = 0;
        await _api.saveOnboardingProgress(messages);
        await _clearLocalBackup();
        _fetchNextQuestion();
      } else {
        _fetchNextQuestion();
      }
    } catch (e) {
      // No pudimos confirmar con el backend si había progreso guardado (sin
      // conexión, servidor caído, etc.). Antes de asumir que no hay nada y
      // hacer perder un brief a medias, probamos con el respaldo local.
      final backup = await _loadLocalBackup();
      if (backup != null && backup.isNotEmpty && _isProgressCompatible(backup)) {
        _restoreFromMessages(backup);
      } else {
        messages = [];
        questionCount = 0;
        _fetchNextQuestion();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _restoreFromMessages(List<Map<String, String>> progress) {
    messages = progress;
    questionCount = messages.where((m) => m['role'] == 'user').length;
    if (questionCount >= maxQuestions) {
      // Ya respondió las 50: que revise/confirme en vez de generar solo.
      reviewMode = true;
    } else if (messages.last['role'] == 'user') {
      // Si el último mensaje es del usuario, toca que Jarvis pregunte
      _fetchNextQuestion();
    } else {
      // El último mensaje ya es la pregunta pendiente; solo restauramos
      // el indicador de área/progreso para que coincida.
      _syncAreaProgress();
    }
  }

  /// Reinicia la conversación para un re-brief mensual (actualizar metas)
  /// en vez de retomar la del onboarding original que ya quedó completa.
  Future<void> startRebrief() async {
    messages = [];
    questionCount = 0;
    errorMessage = null;
    reviewMode = false;
    currentAreaLabel = null;
    currentAreaIndex = 0;
    currentQuestionNumber = 0;
    notifyListeners();
    _fetchNextQuestion();
  }

  /// Compara el progreso guardado contra el banco fijo de preguntas
  /// actual, pregunta por pregunta. Si alguna no coincide (venía de la IA
  /// generándolas dinámicamente en una versión anterior, el banco de
  /// preguntas cambió, o el idioma cambió a mitad de un brief), el
  /// progreso ya no es válido.
  bool _isProgressCompatible(List<Map<String, String>> progress) {
    final qs = questions;
    int qIndex = 0;
    for (final m in progress) {
      if (m['role'] != 'jarvis') continue;
      if (qIndex >= qs.length) return false;
      if (m['text'] != qs[qIndex].question) return false;
      qIndex++;
    }
    return true;
  }

  void _syncAreaProgress() {
    final qs = questions;
    if (questionCount >= qs.length) return;
    final q = qs[questionCount];
    currentAreaLabel = q.areaLabel;
    currentAreaIndex = questionCount ~/ questionsPerArea;
    currentQuestionNumber = (questionCount % questionsPerArea) + 1;
  }

  // Se guarda en el backend en segundo plano (sin esperar) y también en un
  // respaldo local: si el backend falla, no se pierde nada localmente
  // durante la sesión, y si la app se cierra sin conexión, el respaldo
  // local permite retomar en el próximo arranque.
  void _persistProgress() {
    _api.saveOnboardingProgress(messages);
    _saveLocalBackup();
  }

  Future<void> _saveLocalBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localBackupKey, jsonEncode(messages));
  }

  Future<List<Map<String, String>>?> _loadLocalBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localBackupKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, String>.from(e)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearLocalBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localBackupKey);
  }

  // Pregunta local: viene de un banco fijo de 50 preguntas, no de una
  // llamada a la IA, así que nunca puede fallar por red.
  void _fetchNextQuestion() {
    final qs = questions;
    if (questionCount >= qs.length) return;
    final q = qs[questionCount];
    currentAreaLabel = q.areaLabel;
    currentAreaIndex = questionCount ~/ questionsPerArea;
    currentQuestionNumber = (questionCount % questionsPerArea) + 1;
    messages.add({'role': 'jarvis', 'text': q.question});
    notifyListeners();
    _persistProgress();
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
    reviewMode = false;
    _syncAreaProgress();
    notifyListeners();
    _persistProgress();
  }

  /// Si el usuario no entiende o no quiere responder una pregunta, avanza
  /// igual que una respuesta normal pero con un texto neutral, para que la
  /// IA no construya conclusiones sobre una respuesta que no existió.
  Future<bool> skipQuestion() => submitAnswer(_lang.t('onboarding.skippedAnswer'));

  Future<bool> submitAnswer(String answer) async {
    if (answer.trim().isEmpty) return false;

    messages.add({'role': 'user', 'text': answer});
    questionCount++;
    errorMessage = null;
    notifyListeners();
    _persistProgress();

    if (questionCount >= maxQuestions) {
      // No generamos el blueprint todavía: se deja revisar/editar primero.
      reviewMode = true;
      notifyListeners();
      return false;
    } else {
      _fetchNextQuestion();
      return false; // Not finished yet
    }
  }

  /// Pares (pregunta, respuesta) para la pantalla de revisión final.
  List<MapEntry<String, String>> get reviewPairs {
    final pairs = <MapEntry<String, String>>[];
    for (int i = 0; i + 1 < messages.length; i += 2) {
      pairs.add(MapEntry(messages[i]['text'] ?? '', messages[i + 1]['text'] ?? ''));
    }
    return pairs;
  }

  /// Edita una respuesta ya dada desde la pantalla de revisión, sin tener
  /// que rehacer todo el brief.
  void updateAnswer(int pairIndex, String newAnswer) {
    final userIndex = pairIndex * 2 + 1;
    if (userIndex >= messages.length || messages[userIndex]['role'] != 'user') return;
    if (newAnswer.trim().isEmpty) return;
    messages[userIndex] = {'role': 'user', 'text': newAnswer.trim()};
    notifyListeners();
    _persistProgress();
  }

  /// Único paso que todavía llama a la IA (genera el Life Blueprint a
  /// partir de las 50 respuestas). Si falla por un error transitorio, no
  /// se pierde ninguna respuesta: solo hay que reintentar este paso.
  Future<bool> finalizeOnboarding() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final success = await _api.submitAssessment(messages, _lang.code);
      if (!success) throw Exception(_lang.t('onboarding.blueprintSaveFailed'));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_blueprint', true);
      await _clearLocalBackup();
      await NotificationService.instance.scheduleMorningReminder();
      await NotificationService.instance.scheduleNightReminder();

      return true; // Navigates to Chat
    } catch (e) {
      errorMessage = _lang.tr('onboarding.finalizeError', {'error': e.toString().replaceFirst('Exception: ', '')});
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
