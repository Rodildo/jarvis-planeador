import { hashPassword, verifyPassword, signToken, requireAuth, AuthedRequest } from '../../src/auth/auth';
import { Response } from 'express';

describe('Auth module', () => {
    beforeEach(() => {
        process.env.JWT_SECRET = 'test_secret';
    });

    it('hashes a password and verifies it correctly', async () => {
        const hash = await hashPassword('super-secret-1');
        expect(hash).not.toBe('super-secret-1');
        expect(await verifyPassword('super-secret-1', hash)).toBe(true);
        expect(await verifyPassword('wrong-password', hash)).toBe(false);
    });

    it('signs a token that requireAuth can verify and attach as userId', () => {
        const token = signToken('user_abc');

        const req = { headers: { authorization: `Bearer ${token}` } } as AuthedRequest;
        const res = {} as Response;
        const next = jest.fn();

        requireAuth(req, res, next);

        expect(req.userId).toBe('user_abc');
        expect(next).toHaveBeenCalled();
    });

    it('rejects requests without an Authorization header', () => {
        const req = { headers: {} } as AuthedRequest;
        const json = jest.fn();
        const res = { status: jest.fn().mockReturnValue({ json }) } as unknown as Response;
        const next = jest.fn();

        requireAuth(req, res, next);

        expect(res.status).toHaveBeenCalledWith(401);
        expect(next).not.toHaveBeenCalled();
    });

    it('rejects requests with an invalid token', () => {
        const req = { headers: { authorization: 'Bearer not-a-real-token' } } as AuthedRequest;
        const json = jest.fn();
        const res = { status: jest.fn().mockReturnValue({ json }) } as unknown as Response;
        const next = jest.fn();

        requireAuth(req, res, next);

        expect(res.status).toHaveBeenCalledWith(401);
        expect(next).not.toHaveBeenCalled();
    });
});
