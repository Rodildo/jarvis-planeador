const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const MODEL_NAME = "deepseek/deepseek-v3.2";

export interface LifeArea {
    key: string;
    label: string;
}

// El brief inicial (y cada re-brief mensual) cubre estas 5 áreas con 10
// preguntas cada una = 50 preguntas en total.
export const LIFE_AREAS: LifeArea[] = [
    { key: 'salud', label: 'Salud física y mental' },
    { key: 'carrera_finanzas', label: 'Carrera y finanzas' },
    { key: 'relaciones', label: 'Relaciones y familia' },
    { key: 'crecimiento', label: 'Crecimiento personal y hábitos' },
    { key: 'proposito', label: 'Propósito y visión de vida' },
];
export const QUESTIONS_PER_AREA = 10;
export const TOTAL_ONBOARDING_QUESTIONS = LIFE_AREAS.length * QUESTIONS_PER_AREA;

const callOpenRouter = async (systemPrompt: string, userMessage: string, forceJson: boolean = false, maxTokens: number = 700, temperature?: number): Promise<string> => {
    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) throw new Error('OPENROUTER_API_KEY not configured');

    const body: any = {
        model: MODEL_NAME,
        messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userMessage }
        ],
        // Sin esto, el modelo usa su propio default (a veces bajo) y puede
        // cortar la respuesta a mitad de un JSON largo (blueprint/plan
        // diario), dejando un JSON inválido que extractJson no puede
        // parsear. Cada llamada le pasa un valor generoso para lo que
        // realmente necesita generar.
        max_tokens: maxTokens,
    };
    if (temperature !== undefined) body.temperature = temperature;

    if (forceJson) {
        body.response_format = { type: "json_object" };
    }

    let lastError = null;
    for (let attempt = 1; attempt <= 3; attempt++) {
        try {
            const response = await fetch(OPENROUTER_URL, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${apiKey}`,
                    'HTTP-Referer': 'https://jarvisplanner.com',
                    'X-Title': 'Jarvis Life Planner',
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(body)
            });

            if (!response.ok) {
                const errText = await response.text();
                console.error(`OpenRouter API Error (Attempt ${attempt}):`, errText);
                throw new Error(`OpenRouter error: ${response.status}`);
            }

            const data = await response.json();
            if (!data || !data.choices || !data.choices[0]) {
                throw new Error('Invalid OpenRouter response structure');
            }
            return data.choices[0].message.content;
        } catch (error) {
            lastError = error;
            console.error(`Attempt ${attempt} failed:`, error);
            if (attempt < 3) {
                // Wait for 1.5 seconds before retrying
                await new Promise(res => setTimeout(res, 1500));
            }
        }
    }

    throw lastError;
};

const extractJson = (text: string, errorLabel: string): any => {
    try {
        const match = text.match(/\{[\s\S]*\}/);
        if (!match) throw new Error(`No JSON object found in ${errorLabel} response`);
        return JSON.parse(match[0].trim());
    } catch (err) {
        console.error(`Failed to parse ${errorLabel} JSON:`, text);
        throw err;
    }
};

// callOpenRouter ya reintenta fallos de red/HTTP, pero no un JSON que
// vino truncado (la llamada "tuvo éxito", solo que el texto no es JSON
// válido). Ese caso necesita pedirle al modelo que genere de nuevo, no
// solo reparsear lo mismo — por eso reintenta la llamada completa.
const callOpenRouterAndParseJson = async (
    systemPrompt: string, userMessage: string, maxTokens: number, errorLabel: string, temperature?: number
): Promise<any> => {
    let lastError: any = null;
    for (let attempt = 1; attempt <= 2; attempt++) {
        const text = await callOpenRouter(systemPrompt, userMessage, true, maxTokens, temperature);
        try {
            return extractJson(text, errorLabel);
        } catch (err) {
            lastError = err;
            console.error(`${errorLabel}: intento ${attempt} de generar JSON válido falló`);
        }
    }
    throw lastError;
};

// El usuario elige el idioma de la app una sola vez (ver LanguageScreen en
// el frontend) y ese código ('es'/'en') se manda en cada llamada que
// genera contenido con IA, para que el texto que ve (saludo, tareas,
// mensajes) salga en el mismo idioma que el resto de la app — no solo la
// interfaz estática, también lo que genera el modelo.
const languageDirective = (language?: string): string =>
    language === 'en' ? 'Respond only in English, in every text field of your JSON output.' : 'Responde solo en español, en cada campo de texto de tu salida JSON.';

export const generateBlueprint = async (answers: any, previousBlueprint?: any, language?: string): Promise<any> => {
    const areaKeys = LIFE_AREAS.map(a => `"${a.key}"`).join(', ');
    const systemPrompt = `Actúa como un experto planificador de vida y psicólogo. El usuario respondió una entrevista de ${TOTAL_ONBOARDING_QUESTIONS} preguntas organizada en 5 áreas de vida: ${LIFE_AREAS.map(a => a.label).join(', ')}.
    Devuelve estrictamente un JSON válido con este formato exacto:
    {
        "life_vision": "Síntesis breve y potente del propósito y la visión de vida del usuario",
        "areas": {
            ${LIFE_AREAS.map(a => `"${a.key}": { "summary": "string", "goals": ["string", "string", "string"] }`).join(',\n            ')}
        },
        "daily_routine": "Descripción de cómo debería verse un día ideal para esta persona, en 2-3 frases"
    }
    Las claves dentro de "areas" deben ser exactamente estas: ${areaKeys}. Cada área debe tener entre 2 y 4 metas concretas y accionables basadas en las respuestas del usuario. ${languageDirective(language)}`;

    const updateNote = previousBlueprint
        ? `\nEste es un plan de vida EXISTENTE que el usuario está actualizando en su re-brief mensual. Blueprint anterior: ${JSON.stringify(previousBlueprint)}. Evoluciona y actualiza las metas en vez de ignorar lo anterior: conserva lo que sigue vigente y ajusta o reemplaza lo que cambió según las nuevas respuestas.`
        : '';

    const userPrompt = `Respuestas del usuario a las ${TOTAL_ONBOARDING_QUESTIONS} preguntas: ${JSON.stringify(answers)}${updateNote}`;

    return callOpenRouterAndParseJson(systemPrompt, userPrompt, 3000, 'blueprint');
};

// Los mismos 3 baldes de energía se usan para decidir el tono del plan
// (generateDailyPlan) y para decidir si un chequeo de mediodía amerita
// regenerar tareas (generateMidDayReplan / energyModeChanged en routes.ts):
// si el nivel se mueve de un balde a otro, el plan original ya no encaja.
type EnergyMode = 'refugio' | 'estable' | 'expansion';

const energyMode = (level: number): EnergyMode => {
    if (level <= 2) return 'refugio';
    if (level >= 4) return 'expansion';
    return 'estable';
};

export const energyModeChanged = (levelA: number, levelB: number): boolean =>
    energyMode(levelA) !== energyMode(levelB);

const modeDescription = (mode: EnergyMode): string => {
    switch (mode) {
        case 'refugio':
            return "MODO REFUGIO: Baja energía (1-2). Pocas tareas, mínimas y sin culpa. Nada que requiera gran esfuerzo mental o físico.";
        case 'expansion':
            return "MODO ALTA ENERGÍA (Expansión): Energía alta (4-5). Tareas más ambiciosas y estratégicas permitidas, pero incluye al menos un freno saludable (descanso, límite) para evitar el sobreesfuerzo.";
        case 'estable':
            return "MODO RITMO ESTABLE (Baseline): Energía normal (3). Avance constante sin sobreesfuerzo.";
    }
};

// Sin contexto del día, el modelo recibe exactamente lo mismo cada mañana
// (blueprint + energía) y devuelve casi las mismas tarjetas siempre. Para
// que el plan varíe se le pasa: la fecha, un área de vida "foco" que rota
// día a día, y las tareas de los últimos días para que no las repita.
export interface DailyPlanContext {
    date?: string;               // 'YYYY-MM-DD'
    recentTasks?: string[];      // tareas de días anteriores (más reciente primero)
}

const WEEKDAYS_ES = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];

// Rota de forma determinística por fecha, para que cada día (no cada
// llamada) tenga su foco y 5 días seguidos cubran las 5 áreas.
export const focusAreaForDate = (date: string): LifeArea => {
    const dayNumber = Math.floor(Date.parse(`${date}T00:00:00Z`) / 86_400_000);
    const index = ((dayNumber % LIFE_AREAS.length) + LIFE_AREAS.length) % LIFE_AREAS.length;
    return LIFE_AREAS[index]!;
};

const dayContextNote = (ctx?: DailyPlanContext): string => {
    const notes: string[] = [];
    if (ctx?.date && !Number.isNaN(Date.parse(`${ctx.date}T00:00:00Z`))) {
        const weekday = WEEKDAYS_ES[new Date(`${ctx.date}T00:00:00Z`).getUTCDay()];
        const focus = focusAreaForDate(ctx.date);
        notes.push(`Fecha de hoy: ${ctx.date} (${weekday}). Ten en cuenta el día de la semana (p. ej. fin de semana = más espacio para relaciones, ocio, naturaleza o proyectos personales).`);
        notes.push(`ÁREA FOCO DE HOY: "${focus.label}" (clave "${focus.key}"). Al menos una tarea de "midday" debe avanzar una meta de esta área de forma concreta; el resto del plan puede tocar otras áreas.`);
    }
    if (ctx?.recentTasks && ctx.recentTasks.length > 0) {
        notes.push(`Tareas que ya le diste en días recientes (NO las repitas ni con otras palabras; propón acciones nuevas o el siguiente paso lógico de esas metas): ${JSON.stringify(ctx.recentTasks)}`);
    }
    return notes.join('\n    ');
};

export const generateDailyPlan = async (blueprint: any, energyLevel: number, userName?: string, language?: string, context?: DailyPlanContext): Promise<any> => {
    const modeContext = modeDescription(energyMode(energyLevel));

    const nameNote = userName ? `Se llama ${userName}; dirígete a él/ella por su nombre en el saludo, de forma natural (no en cada oración).` : '';

    const systemPrompt = `Eres Jarvis, el guía y estratega de vida del usuario. Tu trabajo es decirle exactamente qué hacer hoy para avanzar hacia su plan de vida, adaptado a su energía de hoy. La energía de una persona puede variar bastante de un día a otro por muchas razones (salud física o mental, sueño, estrés, u otras), así que la adaptación es crítica; nunca asumas ni menciones un diagnóstico específico, solo responde a la energía reportada. ${nameNote}
    Devuelve estrictamente un JSON con este formato exacto:
    {
      "greeting": "Mensaje motivacional corto y empático (adaptado a su energía de hoy).",
      "morning": [ { "task": "Acción concreta", "reason": "Por qué esta tarea, ligada a una meta del blueprint (breve)" } ],
      "midday": [ { "task": "Acción concreta", "reason": "string breve" } ],
      "night": [ { "task": "Acción concreta", "reason": "string breve" } ]
    }
    Reglas:
    - "morning": lo primero que debe hacer al levantarse (rutina, mentalidad, algo pequeño y activador).
    - "midday": tareas para el transcurso del día, las que más avanzan sus metas activas.
    - "night": cierre del día (reflexión breve, descanso, preparación para mañana).
    - Cantidad de tareas por lista según la energía: MODO REFUGIO 1-2; RITMO ESTABLE 2-4; ALTA ENERGÍA 3-5.
    - Todas las tareas deben conectar con al menos una meta del blueprint, nunca genéricas o vacías.
    - VARIEDAD: el plan de hoy debe sentirse distinto al de días anteriores. Reparte las tareas entre varias áreas de vida (salud, carrera/finanzas, relaciones, crecimiento, propósito) y mezcla tipos de acción: física, aprendizaje, social/contacto con alguien, creativa, organización/finanzas, reflexión, descanso o disfrute. Solo los hábitos base de su rutina ideal pueden repetirse, y aun así cambia el enfoque o el detalle (p. ej. otro tipo de ejercicio, otro tema de lectura).
    - Sé específico: en vez de "haz ejercicio" di qué, cuánto o dónde; en vez de "avanza tu proyecto" di el paso concreto.
    ${languageDirective(language)}`;

    const userPrompt = `Life Blueprint del usuario: ${JSON.stringify(blueprint)}
    HOY: el usuario reporta un nivel de energía matutino de ${energyLevel}/5. Contexto: ${modeContext}
    ${dayContextNote(context)}
    Genera el plan completo del día (morning/midday/night) siguiendo el formato indicado.`;

    // Temperatura algo más alta que el default para favorecer variedad
    // entre días sin perder coherencia con el blueprint.
    return callOpenRouterAndParseJson(systemPrompt, userPrompt, 2500, 'daily plan', 0.9);
};

export const generateMidDayAdjustment = async (blueprint: any, morningEnergy: number, middayEnergy: number, dailyPlan: any, language?: string): Promise<string> => {
    const systemPrompt = `Eres Jarvis. Dame un mensaje corto, empático y adaptativo para la tarde.
    Devuelve SOLO el texto del mensaje directamente, como si se lo dijeras en el chat. ${languageDirective(language)}`;

    const userPrompt = `Esta mañana el usuario tenía energía ${morningEnergy}/5 y su plan del día era: ${JSON.stringify(dailyPlan)}.
    Han pasado varias horas. Su energía AHORA es ${middayEnergy}/5.
    Si la energía bajó drásticamente, dile que es hora de parar y priorizar el descanso, y que simplifique las tareas de la tarde/noche.
    Si la energía subió o se mantiene bien, dale un pequeño empujón motivacional para las tareas de "midday"/"night" pendientes, recordándole cuidar su ciclo de sueño.`;

    return await callOpenRouter(systemPrompt, userPrompt, false, 300);
};

// Se usa en vez de generateMidDayAdjustment cuando el nivel de energía a
// mitad de día cruzó a un balde distinto (ver energyModeChanged): ahí el
// plan original ya no encaja de verdad, así que en vez de solo un mensaje
// de ánimo se regeneran las tareas que faltan (midday/night — lo de la
// mañana ya pasó, no se toca).
export const generateMidDayReplan = async (
    blueprint: any, middayEnergy: number, currentPlan: any, userName?: string, language?: string
): Promise<{ message: string; midday: any[]; night: any[] }> => {
    const modeContext = modeDescription(energyMode(middayEnergy));
    const nameNote = userName ? `Se llama ${userName}; dirígete a él/ella por su nombre de forma natural.` : '';

    const systemPrompt = `Eres Jarvis, el guía y estratega de vida del usuario. Ya le diste un plan para hoy esta mañana, pero su energía cambió de forma importante a mitad del día y ese plan ya no encaja. Ajusta SOLO lo que falta del día: las tareas de "durante el día" (midday) y "al final del día" (night). No toques ni menciones lo de la mañana, eso ya pasó. La energía de una persona puede variar bastante de un día a otro por muchas razones (salud física o mental, sueño, estrés, u otras); nunca asumas ni menciones un diagnóstico específico, solo responde a la energía reportada. ${nameNote}
    Devuelve estrictamente un JSON con este formato exacto:
    {
      "message": "Mensaje corto y empático explicando el ajuste (por qué cambia el plan de aquí en adelante).",
      "midday": [ { "task": "Acción concreta", "reason": "Por qué esta tarea, ligada a una meta del blueprint (breve)" } ],
      "night": [ { "task": "Acción concreta", "reason": "string breve" } ]
    }
    Reglas:
    - Cada lista debe tener entre 1 y 4 tareas según el nuevo nivel de energía (menos y más simples si bajó, pueden ser más ambiciosas si subió).
    - Todas las tareas deben conectar con al menos una meta del blueprint, nunca genéricas o vacías.
    - Si la energía bajó mucho, prioriza descanso y lo mínimo indispensable, sin culpa.
    ${languageDirective(language)}`;

    const userPrompt = `Life Blueprint del usuario: ${JSON.stringify(blueprint)}
    Plan original de hoy (su "midday"/"night" ya no están vigentes): ${JSON.stringify(currentPlan)}
    Nueva energía reportada a mitad del día: ${middayEnergy}/5. Contexto: ${modeContext}
    Genera el ajuste de "midday" y "night" siguiendo el formato indicado.`;

    return callOpenRouterAndParseJson(systemPrompt, userPrompt, 1800, 'midday replan');
};

