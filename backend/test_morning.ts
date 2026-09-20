import { generateDailyPlan } from './src/ai/gemini';
import * as dotenv from 'dotenv';
dotenv.config();

async function run() {
    const blueprint = {
        life_vision: "Construir una carrera técnica sólida mientras cuida su salud física y mental.",
        areas: {
            salud: { summary: "Energía irregular, busca rutinas sostenibles.", goals: ["Hacer ejercicio 3x/semana", "Dormir 7-8 horas"] },
            carrera_finanzas: { summary: "Quiere crecer profesionalmente.", goals: ["Mejorar skills técnicos", "Ahorrar 10% del ingreso"] },
            relaciones: { summary: "Valora el tiempo en familia.", goals: ["Cenar en familia 3x/semana"] },
            crecimiento: { summary: "Busca hábitos consistentes.", goals: ["Leer 15 min al día"] },
            proposito: { summary: "Busca balance vida-trabajo.", goals: ["Definir su propósito a 5 años"] },
        },
        daily_routine: "Despertar 6 AM, ejercicio, trabajo profundo en la mañana, tiempo en familia en la noche.",
    };
    try {
        const res = await generateDailyPlan(blueprint, 3);
        console.log("Success:", JSON.stringify(res, null, 2));
    } catch (e) {
        console.error("Error:", e);
    }
}
run();
