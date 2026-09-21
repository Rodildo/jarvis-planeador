import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/app_language.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppLanguage>().t;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(t('legal.appBarTitle'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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
              _buildBanner(
                t('legal.betaTitle'),
                t('legal.betaBody'),
                Icons.science_outlined,
              ),
              const SizedBox(height: 12),
              _buildBanner(
                t('legal.noticeTitle'),
                t('legal.noticeBody'),
                Icons.health_and_safety_outlined,
                color: const Color(0xFFFF007F),
              ),
              const SizedBox(height: 28),
              _buildSectionTitle(t('legal.privacyTitle')),
              _buildParagraph(t('legal.lastUpdated')),
              _buildParagraph(t('legal.privacyIntro')),
              _buildSubTitle(t('legal.s1Title')),
              _buildBullet(t('legal.s1Bullet1')),
              _buildBullet(t('legal.s1Bullet2')),
              _buildBullet(t('legal.s1Bullet3')),
              _buildBullet(t('legal.s1Bullet4')),
              _buildBullet(t('legal.s1Bullet5')),
              _buildSubTitle(t('legal.s2Title')),
              _buildParagraph(t('legal.s2Body')),
              _buildSubTitle(t('legal.s3Title')),
              _buildParagraph(t('legal.s3Body')),
              _buildSubTitle(t('legal.s4Title')),
              _buildParagraph(t('legal.s4Body')),
              _buildSubTitle(t('legal.s5Title')),
              _buildParagraph(t('legal.s5Intro')),
              _buildBullet(t('legal.s5Bullet1')),
              _buildBullet(t('legal.s5Bullet2')),
              _buildBullet(t('legal.s5Bullet3')),
              _buildParagraph(t('legal.s5Contact')),
              _buildSubTitle(t('legal.s6Title')),
              _buildParagraph(t('legal.s6Body')),
              _buildSubTitle(t('legal.s7Title')),
              _buildParagraph(t('legal.s7Body')),
              _buildSubTitle(t('legal.s8Title')),
              _buildParagraph(t('legal.s8Body')),

              const SizedBox(height: 32),
              _buildSectionTitle(t('legal.termsTitle')),
              _buildSubTitle(t('legal.t1Title')),
              _buildParagraph(t('legal.t1Body')),
              _buildSubTitle(t('legal.t2Title')),
              _buildParagraph(t('legal.t2Body')),
              _buildSubTitle(t('legal.t3Title')),
              _buildParagraph(t('legal.t3Body')),
              _buildSubTitle(t('legal.t4Title')),
              _buildParagraph(t('legal.t4Body')),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  t('login.copyright'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(String title, String body, IconData icon, {Color color = const Color(0xFF00E5FF)}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(body, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 20)),
    );
  }

  Widget _buildSubTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5)),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontSize: 13)),
          Expanded(child: Text(text, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }
}
