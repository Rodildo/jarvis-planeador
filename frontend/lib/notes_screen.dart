import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/api_service.dart';
import 'core/i18n/app_language.dart';
import 'widgets/jarvis_drawer.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];
  Timer? _retryTimer;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  // Mismo patrón que Plan Maestro/Historial: la copia en disco se muestra
  // al instante (sin spinner) y de inmediato se dispara una actualización
  // silenciosa contra el backend, que ahora es la fuente de verdad real.
  Future<void> _loadNotes() async {
    final cached = await _api.getCachedNotesFromDisk();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _notes = cached;
        _isLoading = false;
      });
    }
    await _refreshFromNetwork();
  }

  // A diferencia de Historial (que reintenta mientras la lista esté vacía,
  // sin distinguir "vacío de verdad" de "no se pudo saber"), acá sí importa
  // la diferencia: una cuenta nueva legítimamente no tiene notas todavía, y
  // eso debe mostrar el estado vacío normal, no reintentar para siempre.
  // `getNotes()` lanza ante una falla de red (ver api_service.dart), así
  // que solo se reintenta dentro del `catch` — y solo si todavía no hay
  // nada que mostrar.
  Future<void> _refreshFromNetwork() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final notes = await _api.getNotes();
      if (!mounted) return;
      _retryTimer?.cancel();
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      if (_notes.isEmpty && mounted) {
        _retryTimer ??= Timer.periodic(const Duration(seconds: 3), (_) => _refreshFromNetwork());
      }
    } finally {
      _isFetching = false;
    }
  }

  void _showSavingError(AppLanguage lang) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('common.error'))));
  }

  Future<void> _showNoteDialog({Map<String, dynamic>? existing}) async {
    final lang = context.read<AppLanguage>();
    final t = lang.t;
    final controller = TextEditingController(text: existing?['text']?.toString() ?? '');
    bool isSaving = false;
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? t('notes.newNote') : t('notes.editNote'),
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 6,
                minLines: 3,
                enabled: !isSaving,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: t('notes.hint'),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text(t('common.cancel'), style: GoogleFonts.inter(color: Colors.white54)),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        Navigator.pop(dialogContext);
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        localError = null;
                      });
                      final success = existing == null
                          ? await _addNote(text)
                          : await _updateNote(existing['id'].toString(), text);
                      if (success) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } else {
                        setDialogState(() {
                          isSaving = false;
                          localError = t('common.error');
                        });
                      }
                    },
              child: Text(t('common.save'), style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _addNote(String text) async {
    final id = await _api.createNote(text);
    if (id == null) return false;
    final now = DateTime.now().toIso8601String();
    setState(() {
      _notes.insert(0, {'id': id, 'text': text, 'createdAt': now, 'updatedAt': now});
    });
    await _api.cacheNotesLocally(_notes);
    return true;
  }

  Future<bool> _updateNote(String id, String text) async {
    final success = await _api.updateNoteRemote(id, text);
    if (!success) return false;
    setState(() {
      final index = _notes.indexWhere((n) => n['id'].toString() == id);
      if (index == -1) return;
      final updated = {..._notes[index], 'text': text, 'updatedAt': DateTime.now().toIso8601String()};
      _notes.removeAt(index);
      _notes.insert(0, updated);
    });
    await _api.cacheNotesLocally(_notes);
    return true;
  }

  Future<void> _confirmDelete(String id) async {
    final lang = context.read<AppLanguage>();
    final t = lang.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF131B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('notes.deleteConfirmTitle'), style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(t('notes.deleteConfirmBody'), style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('common.cancel'), style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('common.delete'), style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _api.deleteNoteRemote(id);
    if (!success) {
      _showSavingError(lang);
      return;
    }
    setState(() => _notes.removeWhere((n) => n['id'].toString() == id));
    await _api.cacheNotesLocally(_notes);
  }

  String _formatUpdatedAt(String? iso, AppLanguage lang) {
    // .toLocal(): las notas que vienen del servidor traen su timestamp en
    // UTC (ver api_service.dart); las creadas/editadas en este dispositivo
    // ya están en hora local, así que esto es un no-op para esas.
    final date = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (date == null) return '';
    final day = date.day;
    final month = lang.monthAbbrev[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return lang.tr('notes.updatedAt', {'date': '$day $month, $hour:$minute'});
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguage>();
    final t = lang.t;
    return Scaffold(
      drawer: const JarvisDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(t('notes.title'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E5FF),
        onPressed: () => _showNoteDialog(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF131B2F), Color(0xFF070B14)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
            : _buildBody(lang),
      ),
    );
  }

  Widget _buildBody(AppLanguage lang) {
    final t = lang.t;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildBanner(t),
        const SizedBox(height: 20),
        if (_notes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                t('notes.emptyState'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
            ),
          )
        else
          ..._notes.asMap().entries.map((entry) {
            final index = entry.key;
            final note = entry.value;
            return _buildNoteCard(note, lang).animate(delay: (index * 30).ms).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
          }),
      ],
    );
  }

  Widget _buildBanner(String Function(String) t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFF00E5FF), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t('notes.banner'),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, AppLanguage lang) {
    final id = note['id'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () => _showNoteDialog(existing: note),
        borderRadius: BorderRadius.circular(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note['text']?.toString() ?? '',
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatUpdatedAt(note['updatedAt']?.toString(), lang),
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmDelete(id),
              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
