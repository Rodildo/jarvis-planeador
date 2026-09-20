import request from 'supertest';
import express from 'express';
import { apiRouter } from '../../src/api/routes';
import { getUserById, updateUserName, updateUserPassword, updateUserAvatar, deleteUserAccount } from '../../src/db/database';

jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');
jest.mock('../../src/auth/auth', () => ({
    requireAuth: (req: any, _res: any, next: any) => {
        req.userId = 'user_123';
        next();
    },
    hashPassword: jest.fn().mockResolvedValue('new_hashed_password'),
    verifyPassword: jest.fn(),
    signToken: jest.fn(),
    isValidEmail: jest.fn().mockReturnValue(true),
}));

const { verifyPassword } = require('../../src/auth/auth');

const app = express();
app.use(express.json());
app.use('/api', apiRouter);

const mockUser = { id: 'user_123', email: 'jorge@example.com', password_hash: 'old_hash', first_name: 'Jorge', last_name: 'Castillo' };

describe('API Routes - Account management', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('PATCH /api/profile updates first and last name', async () => {
        (updateUserName as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app)
            .patch('/api/profile')
            .send({ firstName: 'Jorge Luis', lastName: 'Castillo' });

        expect(response.status).toBe(200);
        expect(response.body.firstName).toBe('Jorge Luis');
        expect(updateUserName).toHaveBeenCalledWith('user_123', 'Jorge Luis', 'Castillo');
    });

    it('PATCH /api/profile rejects an empty name', async () => {
        const response = await request(app)
            .patch('/api/profile')
            .send({ firstName: '', lastName: 'Castillo' });

        expect(response.status).toBe(400);
    });

    it('POST /api/auth/change-password changes the password when current password is correct', async () => {
        (getUserById as jest.Mock).mockResolvedValue(mockUser);
        (verifyPassword as jest.Mock).mockResolvedValue(true);
        (updateUserPassword as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app)
            .post('/api/auth/change-password')
            .send({ currentPassword: 'old-password', newPassword: 'new-strong-password' });

        expect(response.status).toBe(200);
        expect(updateUserPassword).toHaveBeenCalledWith('user_123', 'new_hashed_password');
    });

    it('POST /api/auth/change-password rejects a wrong current password', async () => {
        (getUserById as jest.Mock).mockResolvedValue(mockUser);
        (verifyPassword as jest.Mock).mockResolvedValue(false);

        const response = await request(app)
            .post('/api/auth/change-password')
            .send({ currentPassword: 'wrong-password', newPassword: 'new-strong-password' });

        expect(response.status).toBe(401);
        expect(updateUserPassword).not.toHaveBeenCalled();
    });

    it('POST /api/auth/change-password rejects a short new password', async () => {
        const response = await request(app)
            .post('/api/auth/change-password')
            .send({ currentPassword: 'old-password', newPassword: 'short' });

        expect(response.status).toBe(400);
    });

    it('DELETE /api/account deletes the account when the password is correct', async () => {
        (getUserById as jest.Mock).mockResolvedValue(mockUser);
        (verifyPassword as jest.Mock).mockResolvedValue(true);
        (deleteUserAccount as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app)
            .delete('/api/account')
            .send({ password: 'old-password' });

        expect(response.status).toBe(200);
        expect(deleteUserAccount).toHaveBeenCalledWith('user_123');
    });

    it('DELETE /api/account rejects a wrong password', async () => {
        (getUserById as jest.Mock).mockResolvedValue(mockUser);
        (verifyPassword as jest.Mock).mockResolvedValue(false);

        const response = await request(app)
            .delete('/api/account')
            .send({ password: 'wrong-password' });

        expect(response.status).toBe(401);
        expect(deleteUserAccount).not.toHaveBeenCalled();
    });

    it('PUT /api/profile/avatar stores a valid data URI', async () => {
        (updateUserAvatar as jest.Mock).mockResolvedValue(undefined);
        const avatar = 'data:image/jpeg;base64,AAAA';

        const response = await request(app)
            .put('/api/profile/avatar')
            .send({ avatar });

        expect(response.status).toBe(200);
        expect(updateUserAvatar).toHaveBeenCalledWith('user_123', avatar);
    });

    it('PUT /api/profile/avatar rejects a non-image payload', async () => {
        const response = await request(app)
            .put('/api/profile/avatar')
            .send({ avatar: 'not-an-image' });

        expect(response.status).toBe(400);
        expect(updateUserAvatar).not.toHaveBeenCalled();
    });

    it('PUT /api/profile/avatar rejects an oversized payload', async () => {
        const hugeAvatar = 'data:image/jpeg;base64,' + 'A'.repeat(1_100_000);

        const response = await request(app)
            .put('/api/profile/avatar')
            .send({ avatar: hugeAvatar });

        expect(response.status).toBe(413);
        expect(updateUserAvatar).not.toHaveBeenCalled();
    });

    it('DELETE /api/profile/avatar removes the avatar', async () => {
        (updateUserAvatar as jest.Mock).mockResolvedValue(undefined);

        const response = await request(app).delete('/api/profile/avatar');

        expect(response.status).toBe(200);
        expect(updateUserAvatar).toHaveBeenCalledWith('user_123', null);
    });
});
