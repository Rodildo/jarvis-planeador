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
        model: 'gemini-2.5-flash',
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

export const generateMorningBriefing = async (blueprint: any, energyLevel: number): Promise<string> => {
    const ai = getAI();
    let modeContext = "";
    
    if (energyLevel <= 2) {
        modeContext = "MODO REFUGIO: El usuario tiene baja energía (1-2). Elimina tareas complejas sin juzgar. Enfócate en 1) Hidratación/comida, 2) Caminata de 15 min, 3) Cero culpa. No lo satures.";
    } else if (energyLevel >= 4) {
        modeContext = "MODO ALTA ENERGÍA (Expansión): El usuario se siente muy bien (4-5). Tareas estratégicas y creativas permitidas, pero PON FRENOS SALUDABLES (máximo 3 frentes). Exige que no sacrifique horas de sueño bajo ningún motivo. ¡Protege el biorritmo!";
    } else {
        modeContext = "MODO RITMO ESTABLE (Baseline): Energía normal (3). Manda un recordatorio de avance constante en las 3 prioridades del día sin sobreesfuerzo.";
    }

    const prompt = `
    Eres Jarvis, el estratega de vida del usuario.
    Aquí está el 'Life Blueprint' del usuario: ${JSON.stringify(blueprint)}
    
    HOY:
    El usuario reporta un nivel de energía de ${energyLevel}/5.
    ${modeContext}
    
    Genera un mensaje de "Morning Briefing" de buenos días en texto claro, amigable y empático, estructurado para leerse en un chat. NO devuelvas JSON, devuelve el texto directamente. Usa viñetas o emojis para hacerlo dinámico.
    `;

    const response = await ai.models.generateContent({
        model: 'gemini-2.5-flash',
        contents: prompt,
    });

    if (!response.text) {
        throw new Error("Failed to generate morning briefing");
    }

    return response.text;
};
