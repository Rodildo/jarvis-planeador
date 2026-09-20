import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { saveBlueprint, getBlueprint, getRecentDailyLogs } from '../../src/db/database';
import { generateBlueprint } from '../../src/ai/gemini';

jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');
jest.mock('../../src/auth/auth', () => ({
    requireAuth: (req: any, _res: any, next: any) => {
        req.userId = 'user_123';
        next();
    },
    hashPassword: jest.fn(),
    verifyPassword: jest.fn(),
    signToken: jest.fn(),
}));

const app = express();
app.use(express.json());
app.use('/api', apiRouter);

describe('API Routes', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('POST /api/assessment should generate and save a blueprint', async () => {
        const mockAnswers = { q1: 'answer 1' };
        const mockBlueprint = { life_vision: 'Mock vision', areas: {}, daily_routine: 'Mock Routine' };

        (getBlueprint as jest.Mock).mockResolvedValue(null);
        (generateBlueprint as jest.Mock).mockResolvedValue(mockBlueprint);
        (saveBlueprint as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app)
            .post('/api/assessment')
            .send({ answers: mockAnswers });

        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('success', true);
        expect(response.body.blueprint).toEqual(mockBlueprint);

        expect(generateBlueprint).toHaveBeenCalledWith(mockAnswers, undefined);
        expect(saveBlueprint).toHaveBeenCalledWith('user_123', JSON.stringify(mockBlueprint));
    });

    it('POST /api/assessment should return 400 if answers is missing', async () => {
        const response = await request(app)
            .post('/api/assessment')
            .send({});

        expect(response.status).toBe(400);
    });

    it('GET /api/history should return the recent daily logs for the authenticated user', async () => {
        const mockLogs = [{ date: '2026-09-18', energy_morning: 4, energy_midday: 3, actions_chosen: '{}' }];
        (getRecentDailyLogs as jest.Mock).mockResolvedValue(mockLogs);

        const response = await request(app).get('/api/history?days=14');

        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('success', true);
        expect(response.body.logs).toEqual(mockLogs);
        expect(getRecentDailyLogs).toHaveBeenCalledWith('user_123', 14);
    });
});
