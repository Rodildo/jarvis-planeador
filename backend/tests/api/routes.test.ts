import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { saveBlueprint } from '../../src/db/database';
import { generateBlueprint } from '../../src/ai/gemini';

jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');

const app = express();
app.use(express.json());
app.use('/api', apiRouter);

describe('API Routes', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('POST /api/assessment should generate and save a blueprint', async () => {
        const mockAnswers = { q1: 'answer 1' };
        const mockBlueprint = { goals: ['Mock Goal'], daily_routine: 'Mock Routine' };

        (generateBlueprint as jest.Mock).mockResolvedValue(mockBlueprint);
        (saveBlueprint as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app)
            .post('/api/assessment')
            .send({ userId: 'user_123', answers: mockAnswers });

        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('success', true);
        expect(response.body.blueprint).toEqual(mockBlueprint);

        expect(generateBlueprint).toHaveBeenCalledWith(mockAnswers);
        expect(saveBlueprint).toHaveBeenCalledWith('user_123', JSON.stringify(mockBlueprint));
    });
    
    it('POST /api/assessment should return 400 if userId or answers are missing', async () => {
        const response = await request(app)
            .post('/api/assessment')
            .send({ answers: {} }); // missing userId

        expect(response.status).toBe(400);
    });
});
