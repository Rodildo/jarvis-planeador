import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/api_service.dart';
import '../core/i18n/app_language.dart';

class JarvisDrawer extends StatelessWidget {
  const JarvisDrawer({super.key});

  ImageProvider? _avatarImage() {
    final avatarUri = ApiService.avatar;
    if (avatarUri == null) return null;
    try {
      return MemoryImage(base64Decode(avatarUri.split(',').last));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppLanguage>().t;
    final currentRoute = GoRouterState.of(context).uri.toString();
    final displayName = [ApiService.firstName, ApiService.lastName]
        .where((n) => n != null && n.isNotEmpty)
        .join(' ');
    final avatarImage = _avatarImage();
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: const Color(0xFF070B14).withValues(alpha: 0.85),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF00E5FF),
                        backgroundImage: avatarImage,
                        child: avatarImage == null ? const Icon(Icons.person, color: Colors.black, size: 35) : null,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        displayName.isNotEmpty ? displayName : t('drawer.defaultUser'),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: t('drawer.mainChat'),
                  route: '/chat',
                  isSelected: currentRoute == '/chat',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.map_outlined,
                  title: t('drawer.masterPlan'),
                  route: '/blueprint',
                  isSelected: currentRoute == '/blueprint',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.bar_chart_outlined,
                  title: t('drawer.history'),
                  route: '/history',
                  isSelected: currentRoute == '/history',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: t('drawer.myAccount'),
                  route: '/account',
                  isSelected: currentRoute == '/account',
                ),
                const Divider(color: Colors.white12, height: 32),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white54),
                  title: Text(t('drawer.logout'), style: GoogleFonts.inter(color: Colors.white54)),
                  onTap: () async {
                    Navigator.pop(context);
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required bool isSelected,
  }) {
    final activeColor = const Color(0xFF00E5FF);
    return ListTile(
      leading: Icon(icon, color: isSelected ? activeColor : Colors.white70),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: isSelected ? activeColor : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: activeColor.withValues(alpha: 0.1),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (!isSelected) {
          context.go(route);
        }
      },
    );
  }
}
