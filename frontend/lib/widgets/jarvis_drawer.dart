import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/api_service.dart';

class JarvisDrawer extends StatelessWidget {
  const JarvisDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final displayName = [ApiService.firstName, ApiService.lastName]
        .where((n) => n != null && n.isNotEmpty)
        .join(' ');
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
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFF00E5FF),
                        child: Icon(Icons.person, color: Colors.black, size: 35),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        displayName.isNotEmpty ? displayName : 'Usuario Jarvis',
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
                  title: 'Chat Principal',
                  route: '/chat',
                  isSelected: currentRoute == '/chat',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.map_outlined,
                  title: 'Mi Plan Maestro',
                  route: '/blueprint',
                  isSelected: currentRoute == '/blueprint',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.bar_chart_outlined,
                  title: 'Historial',
                  route: '/history',
                  isSelected: currentRoute == '/history',
                ),
                const Divider(color: Colors.white12, height: 32),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white54),
                  title: Text('Cerrar sesión', style: GoogleFonts.inter(color: Colors.white54)),
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
