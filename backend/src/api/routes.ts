import { Router } from 'express';
import { generateBlueprint, generateMorningBriefing } from '../ai/gemini';
import { saveBlueprint, getBlueprint, saveEnergyLevel } from '../db/database';

export const apiRouter = Router();

apiRouter.post('/assessment', async (req, res) => {
    try {
        const { userId, answers } = req.body;
        
        if (!userId || !answers) {
            return res.status(400).json({ error: 'userId and answers are required' });
        }

        const blueprint = await generateBlueprint(answers);
        await saveBlueprint(userId, JSON.stringify(blueprint));

        res.status(200).json({ success: true, blueprint });
    } catch (error: any) {
        console.error('Assessment Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

apiRouter.post('/briefing', async (req, res) => {
    try {
        const { userId, date, energyLevel } = req.body;
        
        if (!userId || !date || energyLevel === undefined) {
            return res.status(400).json({ error: 'userId, date, and energyLevel are required' });
        }

        await saveEnergyLevel(userId, date, energyLevel);
        
        const blueprintData = await getBlueprint(userId);
        if (!blueprintData) {
            return res.status(404).json({ error: 'Blueprint not found for user' });
        }

        const blueprint = JSON.parse(blueprintData);
        const briefing = await generateMorningBriefing(blueprint, energyLevel);

        res.status(200).json({ success: true, briefing });
    } catch (error: any) {
        console.error('Briefing Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
