const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const MODEL_NAME = "google/gemini-2.5-flash";

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
        console.error("OpenRouter API Error:", errText);
        throw new Error(`OpenRouter error: ${response.status}`);
    }

    const data = await response.json();
    return data.choices[0].message.content;
};

export const generateBlueprint = async (answers: any): Promise<any> => {
    const systemPrompt = `Act as an expert life planner and psychologist. Ensure the output is strictly valid JSON format.
    Expected JSON Structure:
    {
        "goals": ["string"],
        "daily_routine": "string"
    }`;
    const userPrompt = `Based on the following user assessment, create a comprehensive life blueprint.\nUser answers: ${JSON.stringify(answers)}`;

    const text = await callOpenRouter(systemPrompt, userPrompt, true);
    
    try {
        let jsonStr = text;
        if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
        if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
        if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        return JSON.parse(jsonStr.trim());
    } catch (err) {
        console.error("Failed to parse JSON:", text);
        throw err;
    }
};

export const generateMorningOptions = async (blueprint: any, energyLevel: number): Promise<any> => {
    let modeContext = "";
    if (energyLevel <= 2) {
        modeContext = "MODO REFUGIO: Baja energía (1-2). Elimina tareas complejas sin juzgar. Enfócate en cosas minúsculas.";
    } else if (energyLevel >= 4) {
        modeContext = "MODO ALTA ENERGÍA (Expansión): Energía alta (4-5). Tareas estratégicas y creativas permitidas, pero PON FRENOS SALUDABLES.";
    } else {
        modeContext = "MODO RITMO ESTABLE (Baseline): Energía normal (3). Avance constante sin sobreesfuerzo.";
    }

    const systemPrompt = `Eres Jarvis, el estratega de vida del usuario.
    Devuelve estrictamente un JSON con este formato:
    {
      "greeting": "Mensaje motivacional corto y empático (adaptado a su energía).",
      "goals": [
        {
          "goal_name": "Nombre de la meta (basada en el blueprint)",
          "options": [
            { "level": "Suave", "action": "La acción más pequeña y fácil posible" },
            { "level": "Media", "action": "Acción moderada (normal)" },
            { "level": "Intensa", "action": "Acción que requiere gran esfuerzo y concentración" }
          ]
        }
      ]
    }`;
    
    const userPrompt = `Aquí está el 'Life Blueprint' del usuario: ${JSON.stringify(blueprint)}
    HOY: El usuario reporta un nivel de energía matutino de ${energyLevel}/5. Contexto: ${modeContext}
    Extrae al menos 2 metas del blueprint y dales 3 opciones de intensidad a cada una.`;

    const text = await callOpenRouter(systemPrompt, userPrompt, true);

    try {
        let jsonStr = text;
        if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
        if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
        if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        return JSON.parse(jsonStr.trim());
    } catch (err) {
        throw new Error("Failed to parse morning options JSON");
    }
};

export const generateMidDayAdjustment = async (blueprint: any, morningEnergy: number, middayEnergy: number, chosenActions: any): Promise<string> => {
    const systemPrompt = `Eres Jarvis. Dame un mensaje corto, empático y adaptativo para la tarde. 
    Devuelve SOLO el texto del mensaje directamente, como si se lo dijeras en el chat.`;
    
    const userPrompt = `Esta mañana el usuario tenía energía ${morningEnergy}/5 y se propuso hacer esto: ${JSON.stringify(chosenActions)}.
    Han pasado 6 horas. Su energía AHORA es ${middayEnergy}/5.
    Si la energía bajó drásticamente, dile que es hora de parar y priorizar el descanso.
    Si la energía subió o se mantiene bien, dale un pequeño empujón motivacional pero recordándole cuidar su ciclo de sueño.`;

    return await callOpenRouter(systemPrompt, userPrompt, false);
};

export const generateNextOnboardingQuestion = async (previousQA: any[]): Promise<string> => {
    const systemPrompt = `Eres Jarvis, un terapeuta y estratega de vida altamente inteligente. Estamos en la entrevista inicial (onboarding) del usuario para construir su "Life Blueprint".
    Genera UNA sola pregunta profunda y empática para continuar perfilando sus metas de vida, miedos, hábitos y rutinas ideales.
    No hagas una lista de preguntas. Solo haz la siguiente mejor pregunta, natural y conversacional. No añadas saludos, ve directo al punto con empatía.`;
    
    const userPrompt = `Historial de la conversación hasta ahora: ${JSON.stringify(previousQA)}`;

    return await callOpenRouter(systemPrompt, userPrompt, false);
};

export const transcribeAudio = async (base64Audio: string, mimeType: string): Promise<string> => {
    // OpenRouter doesn't support audio transcription in their chat API directly yet.
    // We will return a placeholder since this feature might be unused for now, 
    // or we'd need Google API specifically for audio.
    console.warn("Audio transcription requested but not supported via OpenRouter free text model.");
    return "[Transcripción de audio no soportada por el modelo actual]";
};

