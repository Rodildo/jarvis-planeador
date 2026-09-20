import { generateMorningOptions } from './src/ai/gemini';
import * as dotenv from 'dotenv';
dotenv.config();

async function run() {
    const blueprint = {"goals":["Professional Skill Development","Physical Health Improvement","Work-Life Balance Optimization","Financial Stability"],"daily_routine":"Wake up at 6 AM, morning exercise 6:30-7:15, healthy breakfast 7:30, deep work 8:30-12:00, nutritious lunch 12:30, skill development 14:00-16:00, family/social time 17:00-19:00, light reading/planning 20:00-21:00, sleep by 22:00"};
    try {
        const res = await generateMorningOptions(blueprint, 3);
        console.log("Success:", JSON.stringify(res, null, 2));
    } catch (e) {
        console.error("Error:", e);
    }
}
run();
