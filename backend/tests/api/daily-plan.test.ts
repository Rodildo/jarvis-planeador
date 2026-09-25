import request from 'supertest';
import express from 'express';
import { apiRouter, extractRecentTasks } from '../../src/api/routes';
import { getBlueprint, saveMorningLog, getUserById, getRecentDailyLogs } from '../../src/db/database';
import { generateDailyPlan } from '../../src/ai/gemini';

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

describe('API Routes - Daily Plan', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('POST /api/daily-plan should generate the day plan', async () => {
        const mockBlueprint = JSON.stringify({ life_vision: 'Vision', areas: {}, daily_routine: 'Routine' });
        const mockPlan = { greeting: 'Good morning!', morning: [], midday: [], night: [] };

        (getBlueprint as jest.Mock).mockResolvedValue(mockBlueprint);
        (saveMorningLog as jest.Mock).mockResolvedValue(undefined);
        (getUserById as jest.Mock).mockResolvedValue({ id: 'user_123', email: 'jorge@example.com', password_hash: 'x', first_name: 'Jorge', last_name: 'Castillo' });
        (generateDailyPlan as jest.Mock).mockResolvedValue(mockPlan);
        (getRecentDailyLogs as jest.Mock).mockResolvedValue([
            { date: '2026-09-17', actions_chosen: JSON.stringify({ plan: { morning: [{ task: 'Hoy' }] } }) },
            { date: '2026-09-16', actions_chosen: JSON.stringify({ plan: { morning: [{ task: 'Meditar 10 min' }], midday: [], night: [] }, completed: {} }) },
        ]);

        const response = await request(app)
            .post('/api/daily-plan')
            .send({ date: '2026-09-17', energyLevel: 5 });

        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('success', true);
        expect(response.body.plan).toEqual(mockPlan);

        expect(saveMorningLog).toHaveBeenCalledWith('user_123', '2026-09-17', 5);
        expect(getBlueprint).toHaveBeenCalledWith('user_123');
        expect(generateDailyPlan).toHaveBeenCalledWith(JSON.parse(mockBlueprint), 5, 'Jorge', undefined, { date: '2026-09-17', recentTasks: ['Meditar 10 min'] });
    });

    it('POST /api/daily-plan should return 404 if blueprint is missing', async () => {
        (getBlueprint as jest.Mock).mockResolvedValue(null);

        const response = await request(app)
            .post('/api/daily-plan')
            .send({ date: '2026-09-17', energyLevel: 5 });

        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Blueprint not found for user');
    });

    it('extractRecentTasks skips today, dedupes, and tolerates old/bad logs', () => {
        const logs = [
            { date: '2026-09-17', actions_chosen: JSON.stringify({ plan: { morning: [{ task: 'Hoy' }] } }) },
            { date: '2026-09-16', actions_chosen: JSON.stringify({ plan: { morning: [{ task: 'A' }], midday: [{ task: 'B' }], night: [{ task: 'A' }] } }) },
            { date: '2026-09-15', actions_chosen: JSON.stringify({ morning: [{ task: 'C' }] }) },
            { date: '2026-09-14', actions_chosen: 'not json' },
            { date: '2026-09-13', actions_chosen: null },
        ];
        expect(extractRecentTasks(logs, '2026-09-17')).toEqual(['A', 'B', 'C']);
    });
});
