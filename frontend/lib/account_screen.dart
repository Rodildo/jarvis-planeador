import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'providers/auth_provider.dart';
import 'core/api_service.dart';
import 'core/notification_service.dart';
import 'widgets/jarvis_drawer.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _firstNameController = TextEditingController(text: ApiService.firstName ?? '');
  final _lastNameController = TextEditingController(text: ApiService.lastName ?? '');
  String? _profileMessage;
  bool _profileMessageIsError = false;

  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _nightTime = const TimeOfDay(hour: 21, minute: 0);
  bool _loadingTimes = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationTimes();
  }

  Future<void> _loadNotificationTimes() async {
    final morning = await NotificationService.instance.getMorningTime();
    final night = await NotificationService.instance.getNightTime();
    if (!mounted) return;
    setState(() {
      _morningTime = morning;
      _nightTime = night;
      _loadingTimes = false;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(AuthProvider auth) async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileMessage = 'No se pudo abrir la galería.';
        _profileMessageIsError = true;
      });
      return;
    }
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType ?? 'image/jpeg';
    final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';

    final success = await auth.uploadAvatar(dataUri);
    if (!mounted) return;
    setState(() {
      _profileMessage = success ? 'Foto de perfil actualizada.' : auth.errorMessage;
      _profileMessageIsError = !success;
    });
  }

  Future<void> _removeAvatar(AuthProvider auth) async {
    final success = await auth.removeAvatar();
    if (!mounted) return;
    setState(() {
      _profileMessage = success ? 'Foto de perfil eliminada.' : auth.errorMessage;
      _profileMessageIsError = !success;
    });
  }

  Future<void> _showAvatarOptions(AuthProvider auth) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131B2F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF00E5FF)),
              title: Text('Elegir de la galería', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAvatar(auth);
              },
            ),
            if (ApiService.avatar != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Quitar foto', style: GoogleFonts.inter(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeAvatar(auth);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AuthProvider auth) {
    final avatarUri = ApiService.avatar;
    ImageProvider? imageProvider;
    if (avatarUri != null) {
      try {
        imageProvider = MemoryImage(base64Decode(avatarUri.split(',').last));
      } catch (_) {
        imageProvider = null;
      }
    }

    return Center(
      child: GestureDetector(
        onTap: auth.isLoading ? null : () => _showAvatarOptions(auth),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              backgroundImage: imageProvider,
              child: imageProvider == null ? const Icon(Icons.person, color: Color(0xFF00E5FF), size: 44) : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF070B14), width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF070B14), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() {
        _profileMessage = 'El nombre y el apellido no pueden estar vacíos.';
        _profileMessageIsError = true;
      });
      return;
    }
    final success = await auth.updateProfile(firstName, lastName);
    if (!mounted) return;
    setState(() {
      _profileMessage = success ? 'Perfil actualizado.' : auth.errorMessage;
      _profileMessageIsError = !success;
    });
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(context: context, initialTime: _morningTime);
    if (picked == null) return;
    await NotificationService.instance.setMorningTime(picked);
    if (!mounted) return;
    setState(() => _morningTime = picked);
  }

  Future<void> _pickNightTime() async {
    final picked = await showTimePicker(context: context, initialTime: _nightTime);
    if (picked == null) return;
    await NotificationService.instance.setNightTime(picked);
    if (!mounted) return;
    setState(() => _nightTime = picked);
  }

  Future<void> _showChangePasswordDialog(AuthProvider auth) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Cambiar contraseña', style: GoogleFonts.outfit(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(currentController, 'Contraseña actual', true),
              const SizedBox(height: 10),
              _buildDialogField(newController, 'Nueva contraseña', true),
              const SizedBox(height: 10),
              _buildDialogField(confirmController, 'Confirma la nueva contraseña', true),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            TextButton(
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      if (newController.text != confirmController.text) {
                        setDialogState(() => localError = 'Las contraseñas nuevas no coinciden.');
                        return;
                      }
                      if (newController.text.length < 8) {
                        setDialogState(() => localError = 'La nueva contraseña debe tener al menos 8 caracteres.');
                        return;
                      }
                      final success = await auth.changePassword(currentController.text, newController.text);
                      if (success) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          setState(() {
                            _profileMessage = 'Contraseña actualizada.';
                            _profileMessageIsError = false;
                          });
                        }
                      } else {
                        setDialogState(() => localError = auth.errorMessage);
                      }
                    },
              child: Text('Cambiar', style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(AuthProvider auth) async {
    final passwordController = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Eliminar tu cuenta', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esto borra tu cuenta, tu Life Blueprint y todo tu historial de forma permanente. No se puede deshacer.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildDialogField(passwordController, 'Confirma tu contraseña', true),
              if (localError != null) ...[
                const SizedBox(height: 10),
                Text(localError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            TextButton(
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      final success = await auth.deleteAccount(passwordController.text);
                      if (success) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) context.go('/login');
                      } else {
                        setDialogState(() => localError = auth.errorMessage);
                      }
                    },
              child: Text('Eliminar definitivamente', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String hint, bool obscure) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildTimeRow(String label, TimeOfDay time, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
              ),
              child: Text(time.format(context), style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      drawer: const JarvisDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Mi Cuenta', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF131B2F), Color(0xFF070B14)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildAvatarSection(auth),
              const SizedBox(height: 28),
              _buildSectionTitle('Perfil'),
              _buildCard(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDialogField(_firstNameController, 'Nombre', false)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDialogField(_lastNameController, 'Apellido', false)),
                    ],
                  ),
                  if (_profileMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _profileMessage!,
                      style: TextStyle(color: _profileMessageIsError ? Colors.redAccent : const Color(0xFF00E5FF), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : () => _saveProfile(auth),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF070B14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Guardar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              _buildSectionTitle('Notificaciones'),
              _buildCard(
                children: _loadingTimes
                    ? [const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))]
                    : [
                        _buildTimeRow('Recordatorio matutino', _morningTime, _pickMorningTime),
                        _buildTimeRow('Recordatorio nocturno', _nightTime, _pickNightTime),
                      ],
              ),
              _buildSectionTitle('Seguridad'),
              _buildCard(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showChangePasswordDialog(auth),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00E5FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cambiar contraseña', style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              _buildSectionTitle('Legal'),
              _buildCard(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/legal'),
                      icon: const Icon(Icons.description_outlined, color: Color(0xFF00E5FF)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00E5FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      label: Text('Privacidad y Términos', style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              _buildSectionTitle('Zona de peligro'),
              _buildCard(
                children: [
                  Text(
                    'Eliminar tu cuenta borra tu Life Blueprint y todo tu historial de forma permanente.',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showDeleteAccountDialog(auth),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Eliminar mi cuenta', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '© 2026 Kinetiqsystem. Todos los derechos reservados.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
