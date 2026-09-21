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
//
// Hay una versión en español y una en inglés, en el mismo orden y con el
// mismo tipo/opciones por índice — así el resto del código (progreso
// guardado, índice de área/pregunta actual) no necesita saber en qué
// idioma está, solo en qué posición.
const String _saludEs = 'Salud física y mental';
const String _carreraEs = 'Carrera y finanzas';
const String _relacionesEs = 'Relaciones y familia';
const String _crecimientoEs = 'Crecimiento personal y hábitos';
const String _propositoEs = 'Propósito y visión de vida';

const List<OnboardingQuestion> _onboardingQuestionsEs = [
  // Salud física y mental
  OnboardingQuestion('salud', _saludEs, '¿Cómo describirías tu energía física en un día promedio?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Muy baja', scaleHighLabel: 'Muy alta'),
  OnboardingQuestion('salud', _saludEs, '¿Duermes lo que necesitas normalmente?',
      type: OnboardingQuestionType.choice, options: ['Sí, duermo bien', 'Más o menos', 'No, es un problema']),
  OnboardingQuestion('salud', _saludEs, 'Cuando piensas en tu salud mental, ¿qué es lo que más te pesa actualmente?'),
  OnboardingQuestion('salud', _saludEs, '¿Haces algún tipo de actividad física regularmente?',
      type: OnboardingQuestionType.choice, options: ['Sí, con frecuencia', 'A veces', 'Casi nunca']),
  OnboardingQuestion('salud', _saludEs, '¿Cómo te alimentas normalmente?',
      type: OnboardingQuestionType.choice,
      options: ['Cuido bastante mi alimentación', 'Como lo que hay, sin pensarlo mucho', 'Sé que como mal y quisiera cambiarlo']),
  OnboardingQuestion('salud', _saludEs, '¿Qué señales notas en ti cuando estás entrando en un momento de baja energía o poca motivación? (si hay alguna condición o patrón de fondo que influya, también puedes mencionarlo aquí)'),
  OnboardingQuestion('salud', _saludEs, '¿Y cuáles son las señales de que estás en un momento de mucha energía o activación?'),
  OnboardingQuestion('salud', _saludEs, '¿Qué tanto sientes que cuidas tu estabilidad emocional día a día (terapia, medicación, rutinas)?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada', scaleHighLabel: 'Mucho'),
  OnboardingQuestion('salud', _saludEs, 'Si pudieras cambiar una sola cosa de tu salud física o mental en los próximos 3 meses, ¿cuál sería?'),
  OnboardingQuestion('salud', _saludEs, '¿Qué te gustaría que Jarvis nunca te sugiera hacer en un día de energía baja?'),

  // Carrera y finanzas
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿A qué te dedicas actualmente y qué tan alineado sientes que está con lo que realmente quieres hacer?'),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Cuál es tu mayor meta profesional en el próximo año o dos?'),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Cómo es tu relación con el dinero?',
      type: OnboardingQuestionType.choice, options: ['Me da tranquilidad', 'Me genera ansiedad', 'Prefiero no pensarlo mucho']),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Tienes ahorros o un plan financiero?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, tengo un plan sólido', 'Tengo algo, pero no es constante', 'No, es un área descuidada']),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Qué habilidad te gustaría desarrollar o mejorar que impulsaría tu carrera?'),
  OnboardingQuestion('carrera_finanzas', _carreraEs, 'Si el dinero no fuera un problema, ¿a qué te dedicarías?'),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Qué tanto afecta tu energía diaria a tu productividad laboral?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada', scaleHighLabel: 'Muchísimo'),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Tienes alguna deuda o compromiso financiero que te genere estrés?',
      type: OnboardingQuestionType.choice, options: ['Sí, bastante', 'Un poco', 'No']),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Cómo te gustaría que se viera tu situación financiera en 5 años?'),
  OnboardingQuestion('carrera_finanzas', _carreraEs, '¿Qué es lo que más te frustra de tu trabajo o situación laboral actual?'),

  // Relaciones y familia
  OnboardingQuestion('relaciones', _relacionesEs, '¿Cómo describirías tu círculo cercano de apoyo: familia, pareja, amigos?'),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Hay alguna relación en tu vida que te gustaría fortalecer o reparar?'),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Sientes que las personas cercanas a ti entienden cómo te afectan tus días de baja energía o ánimo?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, bastante bien', 'Algunas sí, otras no', 'No, casi nadie lo entiende']),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Cómo sueles comunicar cuando estás pasando por un día difícil emocionalmente?'),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Tienes a alguien con quien puedas ser completamente honesto sin miedo a ser juzgado?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, una o más personas', 'Solo una persona muy puntual', 'No, la verdad no']),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Qué tan seguido pasas tiempo de calidad con las personas que más te importan?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Casi nunca', scaleHighLabel: 'Muy seguido'),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Hay algún conflicto o distancia en alguna relación que te pese actualmente?'),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Qué tipo de apoyo necesitas de tu entorno cercano en los días de baja energía?'),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Cómo te gustaría que fuera tu vida social o romántica en el futuro?'),
  OnboardingQuestion('relaciones', _relacionesEs, '¿Qué límite te cuesta poner con otras personas?'),

  // Crecimiento personal y hábitos
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Qué hábito te gustaría construir que sabes que cambiaría tu vida?'),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Qué hábito actual sientes que te está frenando?'),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Cómo sueles reaccionar ante el fracaso o los contratiempos?',
      type: OnboardingQuestionType.choice,
      options: ['Me lo tomo con calma y sigo', 'Me cuesta, pero me recupero', 'Se me hace muy difícil superarlo']),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Qué actividad te hace perder la noción del tiempo, en el buen sentido?'),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Aprendes algo nuevo regularmente?',
      type: OnboardingQuestionType.choice, options: ['Sí, constantemente', 'De vez en cuando', 'Casi nunca']),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Qué tan constante eres cumpliendo las metas que te propones?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada constante', scaleHighLabel: 'Muy constante'),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Qué rol juega la disciplina frente a la flexibilidad en tu vida, considerando tus altibajos de energía?'),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Qué te ha hecho sentir orgulloso de ti mismo recientemente?'),
  OnboardingQuestion('crecimiento', _crecimientoEs, '¿Qué tan duro eres contigo mismo cuando no logras hacer lo que querías?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Nada duro', scaleHighLabel: 'Muy duro'),
  OnboardingQuestion('crecimiento', _crecimientoEs, 'Si tuvieras un mentor ideal, ¿qué te ayudaría a construir en ti mismo?'),

  // Propósito y visión de vida
  OnboardingQuestion('proposito', _propositoEs, 'Si miras 10 años hacia adelante, ¿cómo te imaginas tu vida ideal?'),
  OnboardingQuestion('proposito', _propositoEs, '¿Qué crees que es tu propósito, o lo que más sentido le da a tu vida?'),
  OnboardingQuestion('proposito', _propositoEs, '¿Qué legado o impacto te gustaría dejar en las personas que te rodean?'),
  OnboardingQuestion('proposito', _propositoEs, '¿Qué tan clara sientes tu dirección de vida en este momento?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Muy perdido', scaleHighLabel: 'Muy claro'),
  OnboardingQuestion('proposito', _propositoEs, '¿Hay algo que siempre has querido hacer pero has pospuesto por miedo o circunstancias?',
      type: OnboardingQuestionType.choice,
      options: ['Sí, y lo pienso seguido', 'Sí, pero ya casi no lo pienso', 'No, la verdad no']),
  OnboardingQuestion('proposito', _propositoEs, '¿Qué valores son innegociables para ti en la forma en que vives?'),
  OnboardingQuestion('proposito', _propositoEs, '¿Qué significa para ti el éxito, más allá del dinero o el estatus?'),
  OnboardingQuestion('proposito', _propositoEs, '¿Hay algún reto personal (de salud, energía, o cualquier otro) que te gustaría que fuera parte de tu historia de superación, y no un obstáculo en ella?'),
  OnboardingQuestion('proposito', _propositoEs, 'Si pudieras darle un consejo a tu yo de hace 5 años, ¿cuál sería?'),
  OnboardingQuestion('proposito', _propositoEs, '¿Qué necesitas creer sobre ti mismo para perseguir la vida que realmente quieres?'),
];

const String _healthEn = 'Physical & mental health';
const String _careerEn = 'Career & finances';
const String _relationshipsEn = 'Relationships & family';
const String _growthEn = 'Personal growth & habits';
const String _purposeEn = 'Purpose & life vision';

const List<OnboardingQuestion> _onboardingQuestionsEn = [
  // Physical & mental health
  OnboardingQuestion('salud', _healthEn, 'How would you describe your physical energy on an average day?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Very low', scaleHighLabel: 'Very high'),
  OnboardingQuestion('salud', _healthEn, 'Do you usually get the sleep you need?',
      type: OnboardingQuestionType.choice, options: ['Yes, I sleep well', 'Sort of', "No, it's a problem"]),
  OnboardingQuestion('salud', _healthEn, 'When you think about your mental health, what weighs on you the most right now?'),
  OnboardingQuestion('salud', _healthEn, 'Do you do any kind of physical activity regularly?',
      type: OnboardingQuestionType.choice, options: ['Yes, frequently', 'Sometimes', 'Almost never']),
  OnboardingQuestion('salud', _healthEn, 'How do you usually eat?',
      type: OnboardingQuestionType.choice,
      options: ['I take good care of my diet', "I eat what's around, without thinking much", 'I know I eat poorly and would like to change it']),
  OnboardingQuestion('salud', _healthEn, 'What signs do you notice in yourself when you\'re heading into a low-energy or low-motivation period? (if there\'s an underlying condition or pattern that plays a role, feel free to mention it here too)'),
  OnboardingQuestion('salud', _healthEn, 'And what are the signs that you\'re in a high-energy or activated period?'),
  OnboardingQuestion('salud', _healthEn, 'How much do you feel you take care of your emotional stability day to day (therapy, medication, routines)?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Not at all', scaleHighLabel: 'A lot'),
  OnboardingQuestion('salud', _healthEn, 'If you could change just one thing about your physical or mental health in the next 3 months, what would it be?'),
  OnboardingQuestion('salud', _healthEn, 'What would you like Jarvis to never suggest on a low-energy day?'),

  // Career & finances
  OnboardingQuestion('carrera_finanzas', _careerEn, 'What do you currently do, and how aligned does it feel with what you really want to do?'),
  OnboardingQuestion('carrera_finanzas', _careerEn, "What's your biggest professional goal for the next year or two?"),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'What is your relationship with money like?',
      type: OnboardingQuestionType.choice, options: ['It gives me peace of mind', 'It causes me anxiety', "I'd rather not think about it much"]),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'Do you have savings or a financial plan?',
      type: OnboardingQuestionType.choice,
      options: ['Yes, I have a solid plan', "I have something, but it's not consistent", "No, it's a neglected area"]),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'What skill would you like to develop or improve that would boost your career?'),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'If money were not an issue, what would you do?'),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'How much does your daily energy affect your work productivity?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Not at all', scaleHighLabel: 'A great deal'),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'Do you have any debt or financial commitment that stresses you out?',
      type: OnboardingQuestionType.choice, options: ['Yes, quite a bit', 'A little', 'No']),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'How would you like your financial situation to look in 5 years?'),
  OnboardingQuestion('carrera_finanzas', _careerEn, 'What frustrates you most about your current job or work situation?'),

  // Relationships & family
  OnboardingQuestion('relaciones', _relationshipsEn, 'How would you describe your close support circle: family, partner, friends?'),
  OnboardingQuestion('relaciones', _relationshipsEn, "Is there a relationship in your life you'd like to strengthen or repair?"),
  OnboardingQuestion('relaciones', _relationshipsEn, 'Do you feel the people close to you understand how your low-energy or low-mood days affect you?',
      type: OnboardingQuestionType.choice,
      options: ['Yes, pretty well', 'Some do, some don\'t', "No, almost no one understands"]),
  OnboardingQuestion('relaciones', _relationshipsEn, 'How do you usually communicate when you\'re going through an emotionally hard day?'),
  OnboardingQuestion('relaciones', _relationshipsEn, 'Do you have someone you can be completely honest with, without fear of being judged?',
      type: OnboardingQuestionType.choice,
      options: ['Yes, one or more people', 'Only one very specific person', 'No, honestly not'],
  ),
  OnboardingQuestion('relaciones', _relationshipsEn, 'How often do you spend quality time with the people who matter most to you?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Almost never', scaleHighLabel: 'Very often'),
  OnboardingQuestion('relaciones', _relationshipsEn, 'Is there a conflict or distance in any relationship that weighs on you right now?'),
  OnboardingQuestion('relaciones', _relationshipsEn, 'What kind of support do you need from the people close to you on low-energy days?'),
  OnboardingQuestion('relaciones', _relationshipsEn, 'How would you like your social or romantic life to be in the future?'),
  OnboardingQuestion('relaciones', _relationshipsEn, 'What boundary do you find hard to set with other people?'),

  // Personal growth & habits
  OnboardingQuestion('crecimiento', _growthEn, 'What habit would you like to build that you know would change your life?'),
  OnboardingQuestion('crecimiento', _growthEn, 'What current habit do you feel is holding you back?'),
  OnboardingQuestion('crecimiento', _growthEn, 'How do you usually react to failure or setbacks?',
      type: OnboardingQuestionType.choice,
      options: ['I take it calmly and move on', 'It\'s hard, but I recover', "It's very hard for me to get over it"]),
  OnboardingQuestion('crecimiento', _growthEn, 'What activity makes you lose track of time, in a good way?'),
  OnboardingQuestion('crecimiento', _growthEn, 'Do you learn something new regularly?',
      type: OnboardingQuestionType.choice, options: ['Yes, constantly', 'Now and then', 'Almost never']),
  OnboardingQuestion('crecimiento', _growthEn, 'How consistent are you at following through on the goals you set for yourself?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Not consistent at all', scaleHighLabel: 'Very consistent'),
  OnboardingQuestion('crecimiento', _growthEn, 'What role does discipline play against flexibility in your life, considering your energy ups and downs?'),
  OnboardingQuestion('crecimiento', _growthEn, 'What has made you feel proud of yourself recently?'),
  OnboardingQuestion('crecimiento', _growthEn, "How hard are you on yourself when you don't manage to do what you wanted?",
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Not hard at all', scaleHighLabel: 'Very hard'),
  OnboardingQuestion('crecimiento', _growthEn, 'If you had an ideal mentor, what would you want their help building in you?'),

  // Purpose & life vision
  OnboardingQuestion('proposito', _purposeEn, 'Looking 10 years ahead, how do you picture your ideal life?'),
  OnboardingQuestion('proposito', _purposeEn, 'What do you believe your purpose is, or what gives your life the most meaning?'),
  OnboardingQuestion('proposito', _purposeEn, "What legacy or impact would you like to leave on the people around you?"),
  OnboardingQuestion('proposito', _purposeEn, 'How clear does your life direction feel to you right now?',
      type: OnboardingQuestionType.scale, scaleLowLabel: 'Very lost', scaleHighLabel: 'Very clear'),
  OnboardingQuestion('proposito', _purposeEn, "Is there something you've always wanted to do but have put off out of fear or circumstances?",
      type: OnboardingQuestionType.choice,
      options: ['Yes, and I think about it often', "Yes, but I barely think about it anymore", 'No, honestly not']),
  OnboardingQuestion('proposito', _purposeEn, 'What values are non-negotiable for you in the way you live?'),
  OnboardingQuestion('proposito', _purposeEn, 'What does success mean to you, beyond money or status?'),
  OnboardingQuestion('proposito', _purposeEn, "Is there a personal challenge (health, energy, or anything else) you'd like to be part of your story of overcoming, rather than an obstacle in it?"),
  OnboardingQuestion('proposito', _purposeEn, 'If you could give one piece of advice to yourself from 5 years ago, what would it be?'),
  OnboardingQuestion('proposito', _purposeEn, 'What do you need to believe about yourself to pursue the life you truly want?'),
];

const int questionsPerArea = 10;
const int totalOnboardingQuestions = 50;

/// Devuelve el banco de preguntas en el idioma pedido. Mismo orden, mismo
/// tipo y mismas opciones por índice en los dos idiomas — así el progreso
/// guardado (posición + respuesta) es comparable sin importar el idioma.
List<OnboardingQuestion> getOnboardingQuestions(String languageCode) =>
    languageCode == 'en' ? _onboardingQuestionsEn : _onboardingQuestionsEs;
