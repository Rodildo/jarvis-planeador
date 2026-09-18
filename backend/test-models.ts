import { GoogleGenAI } from '@google/genai';
import dotenv from 'dotenv';

dotenv.config();

const run = async () => {
    const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY as string });
    try {
        const response = await ai.models.generateContent({
            model: 'gemini-1.5-flash',
            contents: 'Hi'
        });
        console.log('gemini-1.5-flash Success:', response.text);
    } catch (e) {
        console.error('gemini-1.5-flash Error:', e);
    }
    
    try {
        const response = await ai.models.generateContent({
            model: 'gemini-2.5-flash',
            contents: 'Hi'
        });
        console.log('gemini-2.5-flash Success:', response.text);
    } catch (e) {
        console.error('gemini-2.5-flash Error:', e);
    }
};

run();
