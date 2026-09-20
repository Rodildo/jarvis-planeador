import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { getUserByEmail } from '../../src/db/database';

jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');

process.env.JWT_SECRET = 'test_secret';

const app = express();
app.use(express.json());
app.use('/api', apiRouter);

describe('API Routes - Rate limiting', () => {
    it('blocks a single IP after too many login attempts in the window', async () => {
        (getUserByEmail as jest.Mock).mockResolvedValue(null);

        let lastStatus = 0;
        for (let i = 0; i < 21; i++) {
            const response = await request(app)
                .post('/api/auth/login')
                .send({ email: 'nobody@example.com', password: 'whatever123' });
            lastStatus = response.status;
        }

        expect(lastStatus).toBe(429);
    });
});
