import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings_es.dart';
import 'strings_en.dart';
import '../notification_service.dart';

/// Idioma de la app: 'es' o 'en'. Se elige una sola vez al primer arranque
/// (ver LanguageScreen) y se persiste en SharedPreferences — es una
/// preferencia del dispositivo, no de la cuenta, así que no vive en el
/// backend. También se manda como `language` en las llamadas que generan
/// contenido con IA (blueprint, plan diario, chequeo de mediodía) para que
/// ese contenido salga en el mismo idioma.
class AppLanguage extends ChangeNotifier {
  static const _prefsKey = 'app_language';

  String _code = 'es';
  bool _isSelected = false;

  String get code => _code;
  bool get isSelected => _isSelected;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'es' || saved == 'en') {
      _code = saved!;
      _isSelected = true;
    }
    // NotificationService es un singleton fuera del árbol de providers y
    // no puede leer AppLanguage por context: se le empuja el idioma actual
    // para que los recordatorios que agende salgan en el idioma correcto.
    NotificationService.instance.languageCode = _code;
  }

  Future<void> setLanguage(String code) async {
    _code = code;
    _isSelected = true;
    NotificationService.instance.languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
    notifyListeners();
  }

  /// Busca [key] en el idioma actual; si falta ahí, cae al español (nunca
  /// debe quedar en blanco); si falta en los dos, devuelve la propia clave
  /// para que un texto faltante sea visible/reportable en vez de invisible.
  String t(String key) {
    final map = _code == 'en' ? stringsEn : stringsEs;
    return map[key] ?? stringsEs[key] ?? key;
  }

  // Listas de calendario: distintas de un simple lookup de texto (son
  // arreglos posicionales), así que viven aparte del mapa plano de claves.
  static const _weekdayAbbrevEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _weekdayAbbrevEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdayFullEs = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _weekdayFullEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _monthAbbrevEs = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  static const _monthAbbrevEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  List<String> get weekdayAbbrev => _code == 'en' ? _weekdayAbbrevEn : _weekdayAbbrevEs;
  List<String> get weekdayFull => _code == 'en' ? _weekdayFullEn : _weekdayFullEs;
  List<String> get monthAbbrev => _code == 'en' ? _monthAbbrevEn : _monthAbbrevEs;

  /// Igual que [t], pero reemplaza marcadores `{nombre}` en el texto con
  /// los valores de [params] — para frases con variables (conteos, días,
  /// nombres) sin tener que armar el string a mano concatenando piezas
  /// traducidas por separado (el orden de las palabras cambia entre
  /// idiomas, así que concatenar piezas sueltas no es seguro).
  String tr(String key, Map<String, String> params) {
    var value = t(key);
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }
}
