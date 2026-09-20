"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.apiRouter = void 0;
const express_1 = require("express");
const multer_1 = __importDefault(require("multer"));
const gemini_1 = require("../ai/gemini");
const database_1 = require("../db/database");
const upload = (0, multer_1.default)({ storage: multer_1.default.memoryStorage() });
exports.apiRouter = (0, express_1.Router)();
exports.apiRouter.get('/version', (req, res) => {
    res.json({ version: '3.0.0-openrouter' });
});
exports.apiRouter.post('/assessment', async (req, res) => {
    try {
        const { userId, answers } = req.body;
        if (!userId || !answers)
            return res.status(400).json({ error: 'userId and answers are required' });
        const blueprint = await (0, gemini_1.generateBlueprint)(answers);
        await (0, database_1.saveBlueprint)(userId, JSON.stringify(blueprint));
        res.status(200).json({ success: true, blueprint });
    }
    catch (error) {
        console.error('Assessment Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
exports.apiRouter.post('/onboarding/question', async (req, res) => {
    try {
        const { previousQA } = req.body;
        const question = await (0, gemini_1.generateNextOnboardingQuestion)(previousQA || []);
        res.status(200).json({ success: true, question });
    }
    catch (error) {
        console.error('Onboarding Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
exports.apiRouter.post('/transcribe', upload.single('audio'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No audio file provided' });
        }
        const base64Audio = req.file.buffer.toString('base64');
        const mimeType = req.file.mimetype;
        const transcription = await (0, gemini_1.transcribeAudio)(base64Audio, mimeType);
        res.status(200).json({ success: true, text: transcription });
    }
    catch (error) {
        console.error('Transcription Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
exports.apiRouter.post('/briefing', async (req, res) => {
    try {
        const { userId, date, energyLevel } = req.body;
        if (!userId || !date || energyLevel === undefined)
            return res.status(400).json({ error: 'userId, date, and energyLevel are required' });
        await (0, database_1.saveMorningLog)(userId, date, energyLevel);
        const blueprintData = await (0, database_1.getBlueprint)(userId);
        if (!blueprintData)
            return res.status(404).json({ error: 'Blueprint not found for user' });
        const optionsJson = await (0, gemini_1.generateMorningOptions)(JSON.parse(blueprintData), energyLevel);
        res.status(200).json({ success: true, briefing: optionsJson });
    }
    catch (error) {
        console.error('Briefing Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
exports.apiRouter.post('/daily-actions', async (req, res) => {
    try {
        const { userId, date, actions } = req.body;
        if (!userId || !date || !actions)
            return res.status(400).json({ error: 'Missing required fields' });
        await (0, database_1.saveDailyActions)(userId, date, actions);
        res.status(200).json({ success: true });
    }
    catch (error) {
        console.error('Save Actions Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
exports.apiRouter.post('/midday', async (req, res) => {
    try {
        const { userId, date, energyLevel } = req.body;
        if (!userId || !date || energyLevel === undefined)
            return res.status(400).json({ error: 'Missing fields' });
        await (0, database_1.saveMiddayLog)(userId, date, energyLevel);
        const dailyLog = await (0, database_1.getDailyLog)(userId, date);
        const blueprintData = await (0, database_1.getBlueprint)(userId);
        if (!dailyLog || !blueprintData)
            return res.status(404).json({ error: 'Missing log or blueprint' });
        let chosenActions = [];
        if (dailyLog.actions_chosen)
            chosenActions = JSON.parse(dailyLog.actions_chosen);
        const message = await (0, gemini_1.generateMidDayAdjustment)(JSON.parse(blueprintData), dailyLog.energy_morning, energyLevel, chosenActions);
        res.status(200).json({ success: true, message });
    }
    catch (error) {
        console.error('Midday Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
//# sourceMappingURL=routes.js.map