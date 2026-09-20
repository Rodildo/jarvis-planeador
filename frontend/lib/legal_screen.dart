import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Privacidad y Términos', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
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
                'Jarvis Planeador está en fase BETA',
                'Algunas funciones pueden cambiar, fallar o no estar disponibles temporalmente mientras seguimos desarrollando la app.',
                Icons.science_outlined,
              ),
              const SizedBox(height: 12),
              _buildBanner(
                'Aviso importante',
                'Jarvis Planeador es una herramienta de organización personal. No es un servicio médico ni sustituye la atención de un profesional de salud mental o física. Si estás en una crisis de salud mental, contacta a un profesional o a los servicios de emergencia de tu país.',
                Icons.health_and_safety_outlined,
                color: const Color(0xFFFF007F),
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('Política de Privacidad'),
              _buildParagraph('Última actualización: enero de 2026'),
              _buildParagraph(
                'Jarvis Planeador ("la App") es desarrollada por Kinetiqsystem. Esta política explica qué datos recopilamos, para qué los usamos y qué derechos tienes sobre ellos.',
              ),
              _buildSubTitle('1. Datos que recopilamos'),
              _buildBullet('Datos de cuenta: correo electrónico, nombre, apellido y contraseña (almacenada cifrada, nunca en texto plano).'),
              _buildBullet('Foto de perfil, si eliges agregar una.'),
              _buildBullet('Tus respuestas al brief inicial de 50 preguntas (salud, carrera, relaciones, crecimiento personal y propósito de vida) y de cualquier actualización mensual.'),
              _buildBullet('Tu Life Blueprint: el plan de vida generado a partir de tus respuestas.'),
              _buildBullet('Tus registros diarios de energía (mañana y mediodía) y las tareas que marcas como completadas.'),
              _buildSubTitle('2. Cómo usamos tus datos'),
              _buildParagraph('Usamos esta información exclusivamente para generar y personalizar tu plan de vida y tus recomendaciones diarias dentro de la App. No vendemos tus datos ni los usamos con fines publicitarios.'),
              _buildSubTitle('3. Terceros que procesan tus datos'),
              _buildParagraph('Para generar tu Life Blueprint y tu plan diario, tus respuestas del brief y tu blueprint se envían a OpenRouter (un proveedor externo de modelos de inteligencia artificial) para su procesamiento. Esa información se usa únicamente para generar la respuesta que ves en la App.'),
              _buildSubTitle('4. Dónde se almacenan tus datos'),
              _buildParagraph('Tus datos se almacenan en un servidor operado por Kinetiqsystem. La App no usa servicios de analítica ni rastreo de terceros.'),
              _buildSubTitle('5. Tus derechos'),
              _buildParagraph('Desde "Mi Cuenta" dentro de la App puedes, en cualquier momento:'),
              _buildBullet('Editar tu nombre y apellido.'),
              _buildBullet('Cambiar tu contraseña.'),
              _buildBullet('Eliminar tu cuenta de forma permanente, lo que borra tu Life Blueprint, tu historial diario y tu progreso del brief.'),
              _buildParagraph('Si tienes alguna pregunta sobre tus datos, escríbenos a georjucho@gmail.com.'),
              _buildSubTitle('6. Notificaciones'),
              _buildParagraph('Los recordatorios (matutino, chequeo de mitad de día y cierre nocturno) se agendan localmente en tu dispositivo, no a través de un servidor externo.'),
              _buildSubTitle('7. Menores de edad'),
              _buildParagraph('La App no está dirigida a menores de 18 años.'),
              _buildSubTitle('8. Cambios a esta política'),
              _buildParagraph('Podemos actualizar esta política a medida que la App evoluciona durante su fase Beta. Te avisaremos dentro de la App si hay cambios importantes.'),

              const SizedBox(height: 32),
              _buildSectionTitle('Términos de Uso'),
              _buildSubTitle('1. Uso aceptable'),
              _buildParagraph('Te comprometes a usar la App de forma personal, no fraudulenta, y a proporcionar información veraz al registrarte.'),
              _buildSubTitle('2. Propiedad intelectual'),
              _buildParagraph('El nombre, diseño, contenido y funcionamiento de Jarvis Planeador son propiedad de Kinetiqsystem y no pueden reproducirse sin autorización.'),
              _buildSubTitle('3. Limitación de responsabilidad'),
              _buildParagraph('La App se ofrece "tal cual", especialmente durante su fase Beta. Kinetiqsystem no garantiza que la App esté libre de errores y no se hace responsable por decisiones tomadas exclusivamente con base en las recomendaciones generadas por la App.'),
              _buildSubTitle('4. Contacto'),
              _buildParagraph('Para cualquier consulta legal o de privacidad: georjucho@gmail.com'),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  '© 2026 Kinetiqsystem. Todos los derechos reservados.',
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
