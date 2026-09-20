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

const callOpenRouter = async (systemPrompt: string, userMessage: string, forceJson: boolean = false): Promise<string> => {
    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) throw new Error('OPENROUTER_API_KEY not configured');

    const body: any = {
        model: MODEL_NAME,
        messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userMessage }
        ]
    };

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

export const generateBlueprint = async (answers: any, previousBlueprint?: any): Promise<any> => {
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
    Las claves dentro de "areas" deben ser exactamente estas: ${areaKeys}. Cada área debe tener entre 2 y 4 metas concretas y accionables basadas en las respuestas del usuario.`;

    const updateNote = previousBlueprint
        ? `\nEste es un plan de vida EXISTENTE que el usuario está actualizando en su re-brief mensual. Blueprint anterior: ${JSON.stringify(previousBlueprint)}. Evoluciona y actualiza las metas en vez de ignorar lo anterior: conserva lo que sigue vigente y ajusta o reemplaza lo que cambió según las nuevas respuestas.`
        : '';

    const userPrompt = `Respuestas del usuario a las ${TOTAL_ONBOARDING_QUESTIONS} preguntas: ${JSON.stringify(answers)}${updateNote}`;

    const text = await callOpenRouter(systemPrompt, userPrompt, true);
    return extractJson(text, 'blueprint');
};

export const generateDailyPlan = async (blueprint: any, energyLevel: number): Promise<any> => {
    let modeContext = "";
    if (energyLevel <= 2) {
        modeContext = "MODO REFUGIO: Baja energía (1-2). Pocas tareas, mínimas y sin culpa. Nada que requiera gran esfuerzo mental o físico.";
    } else if (energyLevel >= 4) {
        modeContext = "MODO ALTA ENERGÍA (Expansión): Energía alta (4-5). Tareas más ambiciosas y estratégicas permitidas, pero incluye al menos un freno saludable (descanso, límite) para evitar el sobreesfuerzo.";
    } else {
        modeContext = "MODO RITMO ESTABLE (Baseline): Energía normal (3). Avance constante sin sobreesfuerzo.";
    }

    const systemPrompt = `Eres Jarvis, el guía y estratega de vida del usuario. Tu trabajo es decirle exactamente qué hacer hoy para avanzar hacia su plan de vida, adaptado a su energía de hoy (el usuario es bipolar: algunos días tiene mucha energía y otros muy poca, así que la adaptación es crítica).
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
    - Cada lista debe tener entre 1 y 4 tareas según el nivel de energía (menos y más simples si la energía es baja).
    - Todas las tareas deben conectar con al menos una meta del blueprint, nunca genéricas o vacías.`;

    const userPrompt = `Life Blueprint del usuario: ${JSON.stringify(blueprint)}
    HOY: el usuario reporta un nivel de energía matutino de ${energyLevel}/5. Contexto: ${modeContext}
    Genera el plan completo del día (morning/midday/night) siguiendo el formato indicado.`;

    const text = await callOpenRouter(systemPrompt, userPrompt, true);
    return extractJson(text, 'daily plan');
};

export const generateMidDayAdjustment = async (blueprint: any, morningEnergy: number, middayEnergy: number, dailyPlan: any): Promise<string> => {
    const systemPrompt = `Eres Jarvis. Dame un mensaje corto, empático y adaptativo para la tarde.
    Devuelve SOLO el texto del mensaje directamente, como si se lo dijeras en el chat.`;

    const userPrompt = `Esta mañana el usuario tenía energía ${morningEnergy}/5 y su plan del día era: ${JSON.stringify(dailyPlan)}.
    Han pasado varias horas. Su energía AHORA es ${middayEnergy}/5.
    Si la energía bajó drásticamente, dile que es hora de parar y priorizar el descanso, y que simplifique las tareas de la tarde/noche.
    Si la energía subió o se mantiene bien, dale un pequeño empujón motivacional para las tareas de "midday"/"night" pendientes, recordándole cuidar su ciclo de sueño.`;

    return await callOpenRouter(systemPrompt, userPrompt, false);
};

