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
