enum OnboardingQuestionType { text, scale, choice }

class OnboardingQuestion {
  final String areaKey;
  final String areaLabel;
  final String question;
  final OnboardingQuestionType type;
  final List<String>? options; // solo para choice
  final String? scaleLowLabel; // solo para scale
  final String? scaleHighLabel; // solo para scale

  const OnboardingQuestion(
    this.areaKey,
    this.areaLabel,
    this.question, {
    this.type = OnboardingQuestionType.text,
    this.options,
    this.scaleLowLabel,
    this.scaleHighLabel,
  });
}

// Banco fijo de 50 preguntas (10 por área), con una mezcla de formatos
// (texto libre, escala 1-5, opción múltiple) para que responder no se
// sienta como un formulario repetitivo de 50 renglones iguales.
//
// Debe reflejar las mismas 5 claves de área que LIFE_AREAS en
// backend/src/ai/gemini.ts, para que el blueprint generado por la IA use
// las mismas categorías.
//
// Al no depender de la IA para generar cada pregunta, el brief ya no puede
// fallar por un error transitorio de red/OpenRouter a mitad de camino.
const String _salud = 'Salud física y mental';
const String _carrera = 'Carrera y finanzas';
const String _relaciones = 'Relaciones y familia';
const String _crecimiento = 'Crecimiento personal y hábitos';
const String _proposito = 'Propósito y visión de vida';

const List<OnboardingQuestion> onboardingQuestions = [
  // Salud física y mental
  OnboardingQuestion('salud', _salud, '¿Cómo describirías tu energía física en un día promedio?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Muy baja', scaleHighLabel: 'Muy alta'),
  OnboardingQuestion('salud', _salud, '¿Duermes lo que necesitas normalmente?',
      type: OnboardingQuestionType.choice, options: ['Sí, duermo bien', 'Más o menos', 'No, es un problema']),
  OnboardingQuestion('salud', _salud, 'Cuando piensas en tu salud mental, ¿qué es lo que más te pesa actualmente?'),
  OnboardingQuestion('salud', _salud, '¿Haces algún tipo de actividad física regularmente?',
      type: OnboardingQuestionType.choice, options: ['Sí, con frecuencia', 'A veces', 'Casi nunca']),
  OnboardingQuestion('salud', _salud, '¿Cómo te alimentas normalmente?',
      type: OnboardingQuestionType.choice,
      options: ['Cuido bastante mi alimentación', 'Como lo que hay, sin pensarlo mucho', 'Sé que como mal y quisiera cambiarlo']),
  OnboardingQuestion('salud', _salud, '¿Qué señales notas en ti cuando estás entrando en un momento de baja energía o poca motivación? (si hay alguna condición o patrón de fondo que influya, también puedes mencionarlo aquí)'),
  OnboardingQuestion('salud', _salud, '¿Y cuáles son las señales de que estás en un momento de mucha energía o activación?'),
  OnboardingQuestion('salud', _salud, '¿Qué tanto sientes que cuidas tu estabilidad emocional día a día (terapia, medicación, rutinas)?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada', scaleHighLabel: 'Mucho'),
  OnboardingQuestion('salud', _salud, 'Si pudieras cambiar una sola cosa de tu salud física o mental en los próximos 3 meses, ¿cuál sería?'),
  OnboardingQuestion('salud', _salud, '¿Qué te gustaría que Jarvis nunca te sugiera hacer en un día de energía baja?'),

  // Carrera y finanzas
  OnboardingQuestion('carrera_finanzas', _carrera, '¿A qué te dedicas actualmente y qué tan alineado sientes que está con lo que realmente quieres hacer?'),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Cuál es tu mayor meta profesional en el próximo año o dos?'),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Cómo es tu relación con el dinero?',
      type: OnboardingQuestionType.choice, options: ['Me da tranquilidad', 'Me genera ansiedad', 'Prefiero no pensarlo mucho']),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Tienes ahorros o un plan financiero?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, tengo un plan sólido', 'Tengo algo, pero no es constante', 'No, es un área descuidada']),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Qué habilidad te gustaría desarrollar o mejorar que impulsaría tu carrera?'),
  OnboardingQuestion('carrera_finanzas', _carrera, 'Si el dinero no fuera un problema, ¿a qué te dedicarías?'),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Qué tanto afecta tu energía diaria a tu productividad laboral?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada', scaleHighLabel: 'Muchísimo'),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Tienes alguna deuda o compromiso financiero que te genere estrés?',
      type: OnboardingQuestionType.choice, options: ['Sí, bastante', 'Un poco', 'No']),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Cómo te gustaría que se viera tu situación financiera en 5 años?'),
  OnboardingQuestion('carrera_finanzas', _carrera, '¿Qué es lo que más te frustra de tu trabajo o situación laboral actual?'),

  // Relaciones y familia
  OnboardingQuestion('relaciones', _relaciones, '¿Cómo describirías tu círculo cercano de apoyo: familia, pareja, amigos?'),
  OnboardingQuestion('relaciones', _relaciones, '¿Hay alguna relación en tu vida que te gustaría fortalecer o reparar?'),
  OnboardingQuestion('relaciones', _relaciones, '¿Sientes que las personas cercanas a ti entienden cómo te afectan tus días de baja energía o ánimo?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, bastante bien', 'Algunas sí, otras no', 'No, casi nadie lo entiende']),
  OnboardingQuestion('relaciones', _relaciones, '¿Cómo sueles comunicar cuando estás pasando por un día difícil emocionalmente?'),
  OnboardingQuestion('relaciones', _relaciones, '¿Tienes a alguien con quien puedas ser completamente honesto sin miedo a ser juzgado?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, una o más personas', 'Solo una persona muy puntual', 'No, la verdad no']),
  OnboardingQuestion('relaciones', _relaciones, '¿Qué tan seguido pasas tiempo de calidad con las personas que más te importan?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Casi nunca', scaleHighLabel: 'Muy seguido'),
  OnboardingQuestion('relaciones', _relaciones, '¿Hay algún conflicto o distancia en alguna relación que te pese actualmente?'),
  OnboardingQuestion('relaciones', _relaciones, '¿Qué tipo de apoyo necesitas de tu entorno cercano en los días de baja energía?'),
  OnboardingQuestion('relaciones', _relaciones, '¿Cómo te gustaría que fuera tu vida social o romántica en el futuro?'),
  OnboardingQuestion('relaciones', _relaciones, '¿Qué límite te cuesta poner con otras personas?'),

  // Crecimiento personal y hábitos
  OnboardingQuestion('crecimiento', _crecimiento, '¿Qué hábito te gustaría construir que sabes que cambiaría tu vida?'),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Qué hábito actual sientes que te está frenando?'),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Cómo sueles reaccionar ante el fracaso o los contratiempos?',
      type: OnboardingQuestionType.choice,
      options: ['Me lo tomo con calma y sigo', 'Me cuesta, pero me recupero', 'Se me hace muy difícil superarlo']),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Qué actividad te hace perder la noción del tiempo, en el buen sentido?'),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Aprendes algo nuevo regularmente?',
      type: OnboardingQuestionType.choice, options: ['Sí, constantemente', 'De vez en cuando', 'Casi nunca']),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Qué tan constante eres cumpliendo las metas que te propones?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada constante', scaleHighLabel: 'Muy constante'),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Qué rol juega la disciplina frente a la flexibilidad en tu vida, considerando tus altibajos de energía?'),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Qué te ha hecho sentir orgulloso de ti mismo recientemente?'),
  OnboardingQuestion('crecimiento', _crecimiento, '¿Qué tan duro eres contigo mismo cuando no logras hacer lo que querías?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada duro', scaleHighLabel: 'Muy duro'),
  OnboardingQuestion('crecimiento', _crecimiento, 'Si tuvieras un mentor ideal, ¿qué te ayudaría a construir en ti mismo?'),

  // Propósito y visión de vida
  OnboardingQuestion('proposito', _proposito, 'Si miras 10 años hacia adelante, ¿cómo te imaginas tu vida ideal?'),
  OnboardingQuestion('proposito', _proposito, '¿Qué crees que es tu propósito, o lo que más sentido le da a tu vida?'),
  OnboardingQuestion('proposito', _proposito, '¿Qué legado o impacto te gustaría dejar en las personas que te rodean?'),
  OnboardingQuestion('proposito', _proposito, '¿Qué tan clara sientes tu dirección de vida en este momento?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Muy perdido', scaleHighLabel: 'Muy claro'),
  OnboardingQuestion('proposito', _proposito, '¿Hay algo que siempre has querido hacer pero has pospuesto por miedo o circunstancias?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, y lo pienso seguido', 'Sí, pero ya casi no lo pienso', 'No, la verdad no']),
  OnboardingQuestion('proposito', _proposito, '¿Qué valores son innegociables para ti en la forma en que vives?'),
  OnboardingQuestion('proposito', _proposito, '¿Qué significa para ti el éxito, más allá del dinero o el estatus?'),
  OnboardingQuestion('proposito', _proposito, '¿Hay algún reto personal (de salud, energía, o cualquier otro) que te gustaría que fuera parte de tu historia de superación, y no un obstáculo en ella?'),
  OnboardingQuestion('proposito', _proposito, 'Si pudieras darle un consejo a tu yo de hace 5 años, ¿cuál sería?'),
  OnboardingQuestion('proposito', _proposito, '¿Qué necesitas creer sobre ti mismo para perseguir la vida que realmente quieres?'),
];

const int questionsPerArea = 10;
const int totalOnboardingQuestions = 50;
