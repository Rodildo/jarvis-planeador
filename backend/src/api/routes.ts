import { Router } from 'express';
import { generateBlueprint } from '../ai/gemini';
import { saveBlueprint } from '../db/database';

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
