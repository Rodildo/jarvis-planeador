import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { getBlueprint, saveEnergyLevel } from '../../src/db/database';
import { generateMorningBriefing } from '../../src/ai/gemini';

jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');

const app = express();
app.use(express.json());
app.use('/api', apiRouter);

describe('API Routes - Briefing', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('POST /api/briefing should generate a morning briefing', async () => {
        const mockBlueprint = JSON.stringify({ goals: ['Goal 1'] });
        const mockBriefing = "Good morning! Time to work on Goal 1.";

        (getBlueprint as jest.Mock).mockResolvedValue(mockBlueprint);
        (saveEnergyLevel as jest.Mock).mockResolvedValue(undefined);
        (generateMorningBriefing as jest.Mock).mockResolvedValue(mockBriefing);

        const response = await request(app)
            .post('/api/briefing')
            .send({ userId: 'user_123', date: '2026-09-17', energyLevel: 5 });

        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('success', true);
        expect(response.body.briefing).toEqual(mockBriefing);

        expect(saveEnergyLevel).toHaveBeenCalledWith('user_123', '2026-09-17', 5);
        expect(getBlueprint).toHaveBeenCalledWith('user_123');
        expect(generateMorningBriefing).toHaveBeenCalledWith(JSON.parse(mockBlueprint), 5);
    });

    it('POST /api/briefing should return 404 if blueprint is missing', async () => {
        (getBlueprint as jest.Mock).mockResolvedValue(null);

        const response = await request(app)
            .post('/api/briefing')
            .send({ userId: 'user_123', date: '2026-09-17', energyLevel: 5 });

        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Blueprint not found for user');
    });
});
