import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { getBlueprint, getDailyLog, saveMiddayLog, saveDailyActions, getUserById } from '../../src/db/database';
import { generateMidDayAdjustment, generateMidDayReplan, energyModeChanged } from '../../src/ai/gemini';

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

describe('API Routes - Midday Check', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        (saveMiddayLog as jest.Mock).mockResolvedValue(undefined);
        (getBlueprint as jest.Mock).mockResolvedValue(JSON.stringify({ life_vision: 'Vision', areas: {}, daily_routine: 'Routine' }));
        (getUserById as jest.Mock).mockResolvedValue({ id: 'user_123', first_name: 'Jorge' });
    });

    it('when energy stays in the same range, only asks for a short adaptive message (no replan)', async () => {
        const dailyState = { plan: { greeting: 'hi', morning: [], midday: [{ task: 'A', reason: 'r' }], night: [] }, completed: {}, manualTasks: [] };
        (getDailyLog as jest.Mock).mockResolvedValue({ energy_morning: 3, actions_chosen: JSON.stringify(dailyState) });
        (energyModeChanged as jest.Mock).mockReturnValue(false);
        (generateMidDayAdjustment as jest.Mock).mockResolvedValue('Sigue así.');

        const response = await request(app)
            .post('/api/midday')
            .send({ date: '2026-09-20', energyLevel: 3 });

        expect(response.status).toBe(200);
        expect(response.body).toEqual({ success: true, message: 'Sigue así.' });
        expect(generateMidDayAdjustment).toHaveBeenCalled();
        expect(generateMidDayReplan).not.toHaveBeenCalled();
        expect(saveDailyActions).not.toHaveBeenCalled();
    });

    it('when energy drops into a different range, regenerates midday/night and strips their stale completed flags', async () => {
        const dailyState = {
            plan: { greeting: 'hi', morning: [{ task: 'M', reason: 'r' }], midday: [{ task: 'Old midday', reason: 'r' }], night: [{ task: 'Old night', reason: 'r' }] },
            completed: { 'ai-morning-0': true, 'ai-midday-0': true, 'ai-night-0': false, 'manual-1': true },
            manualTasks: [{ id: 'manual-1', block: 'night', text: 'Custom task' }],
        };
        (getDailyLog as jest.Mock).mockResolvedValue({ energy_morning: 5, actions_chosen: JSON.stringify(dailyState) });
        (energyModeChanged as jest.Mock).mockReturnValue(true);

        const replan = { message: 'Bajemos el ritmo.', midday: [{ task: 'Descansa', reason: 'r' }], night: [{ task: 'Duerme temprano', reason: 'r' }] };
        (generateMidDayReplan as jest.Mock).mockResolvedValue(replan);

        const response = await request(app)
            .post('/api/midday')
            .send({ date: '2026-09-20', energyLevel: 1 });

        expect(response.status).toBe(200);
        expect(response.body.success).toBe(true);
        expect(response.body.message).toBe('Bajemos el ritmo.');
        expect(response.body.plan).toEqual({
            greeting: 'hi',
            morning: [{ task: 'M', reason: 'r' }],
            midday: replan.midday,
            night: replan.night,
        });
        // Las claves de midday/night del plan viejo se descartan; lo de la
        // mañana y las tareas manuales del usuario se conservan.
        expect(response.body.completed).toEqual({ 'ai-morning-0': true, 'manual-1': true });

        expect(generateMidDayReplan).toHaveBeenCalledWith(
            { life_vision: 'Vision', areas: {}, daily_routine: 'Routine' },
            1,
            dailyState.plan,
            'Jorge'
        );
        expect(generateMidDayAdjustment).not.toHaveBeenCalled();
        expect(saveDailyActions).toHaveBeenCalledWith('user_123', '2026-09-20', {
            plan: response.body.plan,
            completed: response.body.completed,
            manualTasks: dailyState.manualTasks,
        });
    });

    it('returns 404 if there is no daily log or blueprint for that date', async () => {
        (getDailyLog as jest.Mock).mockResolvedValue(null);

        const response = await request(app)
            .post('/api/midday')
            .send({ date: '2026-09-20', energyLevel: 2 });

        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Missing log or blueprint');
    });
});
