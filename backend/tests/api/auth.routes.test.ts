import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { createUser, getUserByEmail } from '../../src/db/database';

jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');

process.env.JWT_SECRET = 'test_secret';

const app = express();
app.use(express.json());
app.use('/api', apiRouter);

describe('API Routes - Auth', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('POST /api/auth/register creates a user and returns a token', async () => {
        (getUserByEmail as jest.Mock).mockResolvedValue(null);
        (createUser as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app)
            .post('/api/auth/register')
            .send({ email: 'jorge@example.com', password: 'a-strong-password' });

        expect(response.status).toBe(201);
        expect(response.body.success).toBe(true);
        expect(typeof response.body.token).toBe('string');
        expect(typeof response.body.userId).toBe('string');
        expect(createUser).toHaveBeenCalledTimes(1);
    });

    it('POST /api/auth/register rejects an email that is already registered', async () => {
        (getUserByEmail as jest.Mock).mockResolvedValue({ id: 'u1', email: 'jorge@example.com', password_hash: 'x' });

        const response = await request(app)
            .post('/api/auth/register')
            .send({ email: 'jorge@example.com', password: 'a-strong-password' });

        expect(response.status).toBe(409);
    });

    it('POST /api/auth/register rejects a short password', async () => {
        const response = await request(app)
            .post('/api/auth/register')
            .send({ email: 'jorge@example.com', password: 'short' });

        expect(response.status).toBe(400);
    });

    it('POST /api/auth/login rejects unknown emails', async () => {
        (getUserByEmail as jest.Mock).mockResolvedValue(null);

        const response = await request(app)
            .post('/api/auth/login')
            .send({ email: 'nobody@example.com', password: 'whatever123' });

        expect(response.status).toBe(401);
    });

    it('protected routes reject requests with no token', async () => {
        const response = await request(app).get('/api/blueprint');
        expect(response.status).toBe(401);
    });
});
