import { Router } from 'express';
import multer from 'multer';
import { generateBlueprint, generateMorningOptions, generateMidDayAdjustment, generateNextOnboardingQuestion, transcribeAudio } from '../ai/gemini';
import { saveBlueprint, getBlueprint, saveMorningLog, saveMiddayLog, saveDailyActions, getDailyLog } from '../db/database';

const upload = multer({ storage: multer.memoryStorage() });
export const apiRouter = Router();

apiRouter.post('/assessment', async (req, res) => {
    try {
        const { userId, answers } = req.body;
        if (!userId || !answers) return res.status(400).json({ error: 'userId and answers are required' });
        const blueprint = await generateBlueprint(answers);
        await saveBlueprint(userId, JSON.stringify(blueprint));
        res.status(200).json({ success: true, blueprint });
    } catch (error: any) {
        console.error('Assessment Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

apiRouter.post('/onboarding/question', async (req, res) => {
    try {
        const { previousQA } = req.body;
        const question = await generateNextOnboardingQuestion(previousQA || []);
        res.status(200).json({ success: true, question });
    } catch (error: any) {
        console.error('Onboarding Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

apiRouter.post('/transcribe', upload.single('audio'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No audio file provided' });
        }
        
        const base64Audio = req.file.buffer.toString('base64');
        const mimeType = req.file.mimetype;
        
        const transcription = await transcribeAudio(base64Audio, mimeType);
        res.status(200).json({ success: true, text: transcription });
    } catch (error: any) {
        console.error('Transcription Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

apiRouter.post('/briefing', async (req, res) => {
    try {
        const { userId, date, energyLevel } = req.body;
        if (!userId || !date || energyLevel === undefined) return res.status(400).json({ error: 'userId, date, and energyLevel are required' });
        
        await saveMorningLog(userId, date, energyLevel);
        
        const blueprintData = await getBlueprint(userId);
        if (!blueprintData) return res.status(404).json({ error: 'Blueprint not found for user' });
        
        const optionsJson = await generateMorningOptions(JSON.parse(blueprintData), energyLevel);
        res.status(200).json({ success: true, briefing: optionsJson });
    } catch (error: any) {
        console.error('Briefing Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

apiRouter.post('/daily-actions', async (req, res) => {
    try {
        const { userId, date, actions } = req.body;
        if (!userId || !date || !actions) return res.status(400).json({ error: 'Missing required fields' });
        
        await saveDailyActions(userId, date, actions);
        res.status(200).json({ success: true });
    } catch (error: any) {
        console.error('Save Actions Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

apiRouter.post('/midday', async (req, res) => {
    try {
        const { userId, date, energyLevel } = req.body;
        if (!userId || !date || energyLevel === undefined) return res.status(400).json({ error: 'Missing fields' });
        
        await saveMiddayLog(userId, date, energyLevel);
        
        const dailyLog = await getDailyLog(userId, date);
        const blueprintData = await getBlueprint(userId);
        
        if (!dailyLog || !blueprintData) return res.status(404).json({ error: 'Missing log or blueprint' });
        
        let chosenActions = [];
        if (dailyLog.actions_chosen) chosenActions = JSON.parse(dailyLog.actions_chosen);
        
        const message = await generateMidDayAdjustment(JSON.parse(blueprintData), dailyLog.energy_morning, energyLevel, chosenActions);
        res.status(200).json({ success: true, message });
    } catch (error: any) {
        console.error('Midday Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
