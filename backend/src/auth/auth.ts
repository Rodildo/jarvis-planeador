import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

const TOKEN_TTL = '90d';

const getJwtSecret = (): string => {
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('JWT_SECRET not configured');
    return secret;
};

export const hashPassword = (password: string): Promise<string> => bcrypt.hash(password, 10);

export const verifyPassword = (password: string, hash: string): Promise<boolean> => bcrypt.compare(password, hash);

export const signToken = (userId: string): string => jwt.sign({ userId }, getJwtSecret(), { expiresIn: TOKEN_TTL });

export interface AuthedRequest extends Request {
    userId?: string;
}

// Cada usuario solo puede leer/escribir sus propios datos: el userId sale
// del token firmado, nunca de un parámetro que el cliente pueda falsificar.
export const requireAuth = (req: AuthedRequest, res: Response, next: NextFunction) => {
    const header = req.headers.authorization;
    const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
        res.status(401).json({ error: 'Missing Authorization header' });
        return;
    }
    try {
        const payload = jwt.verify(token, getJwtSecret()) as { userId: string };
        req.userId = payload.userId;
        next();
    } catch {
        res.status(401).json({ error: 'Invalid or expired token' });
    }
};
