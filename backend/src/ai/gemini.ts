import { GoogleGenAI } from '@google/genai';

const getAI = () => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY not configured');
    return new GoogleGenAI({ apiKey });
};

export const generateBlueprint = async (answers: any): Promise<any> => {
    const ai = getAI();
    const prompt = `
    Act as an expert life planner and psychologist. Based on the following user assessment, create a comprehensive life blueprint.
    Ensure the output is strictly valid JSON format.
    
    User answers: ${JSON.stringify(answers)}
    
    Expected JSON Structure:
    {
        "goals": ["string"],
        "daily_routine": "string"
    }
    `;

    const response = await ai.models.generateContent({
        model: 'gemini-1.5-flash',
        contents: prompt,
        config: {
            responseMimeType: "application/json",
        }
    });

    if (!response.text) {
        throw new Error("Failed to generate blueprint from Gemini");
    }

    return JSON.parse(response.text);
};

export const generateMorningOptions = async (blueprint: any, energyLevel: number): Promise<any> => {
    const ai = getAI();
    let modeContext = "";
    
    if (energyLevel <= 2) {
        modeContext = "MODO REFUGIO: Baja energía (1-2). Elimina tareas complejas sin juzgar. Enfócate en cosas minúsculas (ej. lavarse la cara, descansar). No lo satures.";
    } else if (energyLevel >= 4) {
        modeContext = "MODO ALTA ENERGÍA (Expansión): Energía alta (4-5). Tareas estratégicas y creativas permitidas, pero PON FRENOS SALUDABLES (máximo 3 frentes). Exige que no sacrifique horas de sueño bajo ningún motivo. ¡Protege el biorritmo!";
    } else {
        modeContext = "MODO RITMO ESTABLE (Baseline): Energía normal (3). Avance constante sin sobreesfuerzo.";
    }

    const prompt = `
    Eres Jarvis, el estratega de vida del usuario.
    Aquí está el 'Life Blueprint' del usuario: ${JSON.stringify(blueprint)}
    
    HOY:
    El usuario reporta un nivel de energía matutino de ${energyLevel}/5.
    Contexto: ${modeContext}
    
    Devuelve estrictamente un JSON con este formato:
    {
      "greeting": "Mensaje motivacional corto y empático (adaptado a su energía).",
      "goals": [
        {
          "goal_name": "Nombre de la meta (basada en el blueprint, ej. Salud, Proyecto X)",
          "options": [
            { "level": "Suave", "action": "La acción más pequeña y fácil posible" },
            { "level": "Media", "action": "Acción moderada (normal)" },
            { "level": "Intensa", "action": "Acción que requiere gran esfuerzo y concentración" }
          ]
        }
      ]
    }
    Extrae al menos 2 metas del blueprint y dales 3 opciones de intensidad a cada una.
    `;

    const response = await ai.models.generateContent({
        model: 'gemini-1.5-flash',
        contents: prompt,
        config: { responseMimeType: "application/json" }
    });

    if (!response.text) throw new Error("Failed to generate morning options");
    return JSON.parse(response.text);
};

export const generateMidDayAdjustment = async (blueprint: any, morningEnergy: number, middayEnergy: number, chosenActions: any): Promise<string> => {
    const ai = getAI();
    const prompt = `
    Eres Jarvis. 
    Esta mañana el usuario tenía energía ${morningEnergy}/5 y se propuso hacer esto: ${JSON.stringify(chosenActions)}.
    Han pasado 6 horas. Su energía AHORA es ${middayEnergy}/5.
    
    Dame un mensaje corto, empático y adaptativo para la tarde. 
    Si la energía bajó drásticamente, dile que es hora de parar y priorizar el descanso, validando su esfuerzo.
    Si la energía subió o se mantiene bien, dale un pequeño empujón motivacional pero recordándole cuidar su ciclo de sueño.
    Devuelve SOLO el texto del mensaje directamente, como si se lo dijeras en el chat.
    `;
    const response = await ai.models.generateContent({
        model: 'gemini-1.5-flash',
        contents: prompt,
    });
    return response.text || "Aquí estoy para lo que necesites esta tarde.";
};

export const generateNextOnboardingQuestion = async (previousQA: any[]): Promise<string> => {
    const ai = getAI();
    const prompt = `
    Eres Jarvis, un terapeuta y estratega de vida altamente inteligente. Estamos en la entrevista inicial (onboarding) del usuario para construir su "Life Blueprint".
    Historial de la conversación hasta ahora: ${JSON.stringify(previousQA)}
    
    Basado en este historial, genera UNA sola pregunta profunda y empática para continuar perfilando sus metas de vida, miedos, hábitos y rutinas ideales.
    No hagas una lista de preguntas. Solo haz la siguiente mejor pregunta, natural y conversacional. No añadas saludos, ve directo al punto con empatía.
    `;
    const response = await ai.models.generateContent({
        model: 'gemini-1.5-flash',
        contents: prompt,
    });
    return response.text || "¿Qué aspecto de tu rutina diaria te gustaría transformar primero y por qué?";
};

export const transcribeAudio = async (base64Audio: string, mimeType: string): Promise<string> => {
    const ai = getAI();
    const response = await ai.models.generateContent({
        model: 'gemini-1.5-flash',
        contents: [
            "Escucha este audio y transcribe exactamente lo que dice el usuario en su nota de voz. No agregues saludos, solo devuelve el texto transcrito. Si no logras entender, devuelve '[Audio ininteligible]'.",
            {
                inlineData: {
                    data: base64Audio,
                    mimeType: mimeType
                }
            }
        ],
    });
    return (response.text || "").trim();
};
