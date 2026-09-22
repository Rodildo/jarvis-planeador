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

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  // Sin red de por medio (todo vive en SharedPreferences), así que esto
  // resuelve casi al instante — no hace falta la lógica de reintentos que
  // sí necesitan Historial/Plan Maestro contra un backend que puede fallar.
  Future<void> _loadNotes() async {
    final notes = await _api.getNotes();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _persist() async {
    await _api.saveNotes(_notes);
  }

  Future<void> _showNoteDialog({Map<String, dynamic>? existing}) async {
    final lang = context.read<AppLanguage>();
    final t = lang.t;
    final controller = TextEditingController(text: existing?['text']?.toString() ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF131B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? t('notes.newNote') : t('notes.editNote'),
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('common.cancel'), style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.pop(dialogContext);
                return;
              }
              if (existing == null) {
                _addNote(text);
              } else {
                _updateNote(existing['id'].toString(), text);
              }
              Navigator.pop(dialogContext);
            },
            child: Text(t('common.save'), style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addNote(String text) {
    final now = DateTime.now().toIso8601String();
    setState(() {
      _notes.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'createdAt': now,
        'updatedAt': now,
      });
    });
    _persist();
  }

  void _updateNote(String id, String text) {
    setState(() {
      final index = _notes.indexWhere((n) => n['id'].toString() == id);
      if (index == -1) return;
      _notes[index] = {
        ..._notes[index],
        'text': text,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final updated = _notes.removeAt(index);
      _notes.insert(0, updated);
    });
    _persist();
  }

  Future<void> _confirmDelete(String id) async {
    final t = context.read<AppLanguage>().t;
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
    if (confirmed == true) {
      setState(() => _notes.removeWhere((n) => n['id'].toString() == id));
      await _persist();
    }
  }

  String _formatUpdatedAt(String? iso, AppLanguage lang) {
    final date = iso == null ? null : DateTime.tryParse(iso);
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
