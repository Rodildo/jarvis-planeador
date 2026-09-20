import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { getUserByEmail } from '../../src/db/database';

jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');

process.env.JWT_SECRET = 'test_secret';

// Replica exactamente cómo arranca src/index.ts: detrás de un proxy
// reverso (Traefik en EasyPanel), 'trust proxy' debe estar configurado o
// express-rate-limit lanza ERR_ERL_UNEXPECTED_X_FORWARDED_FOR en cuanto ve
// el header X-Forwarded-For, tumbando el endpoint con un 500. Si alguien
// quita `app.set('trust proxy', 1)` de index.ts, este test debe fallar.
const app = express();
app.set('trust proxy', 1);
app.use(express.json());
app.use('/api', apiRouter);

describe('Rate limiter behind a reverse proxy', () => {
    it('handles a request carrying X-Forwarded-For without throwing', async () => {
        (getUserByEmail as jest.Mock).mockResolvedValue(null);

        const response = await request(app)
            .post('/api/auth/login')
            .set('X-Forwarded-For', '203.0.113.5')
            .send({ email: 'nobody@example.com', password: 'whatever123' });

        // 401 = credenciales inválidas, procesado con normalidad.
        // Un 500 acá significaría que volvió el bug de trust proxy.
        expect(response.status).toBe(401);
    });
});
