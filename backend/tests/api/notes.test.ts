import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { createNote, getNotes, updateNote, deleteNote } from '../../src/db/database';

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

describe('Notes API', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('GET /api/notes should return the notes for the authenticated user, camelCased', async () => {
        (getNotes as jest.Mock).mockResolvedValue([
            { id: 'n1', text: 'Comprar leche', created_at: '2026-09-22 10:00:00', updated_at: '2026-09-22 10:00:00' },
        ]);

        const response = await request(app).get('/api/notes');

        expect(response.status).toBe(200);
        expect(response.body.notes).toEqual([
            { id: 'n1', text: 'Comprar leche', createdAt: '2026-09-22 10:00:00', updatedAt: '2026-09-22 10:00:00' },
        ]);
        expect(getNotes).toHaveBeenCalledWith('user_123');
    });

    it('POST /api/notes should create a note and return its id', async () => {
        (createNote as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app).post('/api/notes').send({ text: '  Llamar al dentista  ' });

        expect(response.status).toBe(201);
        expect(response.body.success).toBe(true);
        expect(typeof response.body.id).toBe('string');
        expect(createNote).toHaveBeenCalledWith(response.body.id, 'user_123', 'Llamar al dentista');
    });

    it('POST /api/notes should reject empty text', async () => {
        const response = await request(app).post('/api/notes').send({ text: '   ' });
        expect(response.status).toBe(400);
        expect(createNote).not.toHaveBeenCalled();
    });

    it('PUT /api/notes/:id should update the note text', async () => {
        (updateNote as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app).put('/api/notes/n1').send({ text: 'Texto editado' });

        expect(response.status).toBe(200);
        expect(updateNote).toHaveBeenCalledWith('n1', 'user_123', 'Texto editado');
    });

    it('DELETE /api/notes/:id should delete the note', async () => {
        (deleteNote as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app).delete('/api/notes/n1');

        expect(response.status).toBe(200);
        expect(deleteNote).toHaveBeenCalledWith('n1', 'user_123');
    });
});
