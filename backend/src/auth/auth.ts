import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { getUserById } from '../db/database';

const TOKEN_TTL = '90d';

const getJwtSecret = (): string => {
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('JWT_SECRET not configured');
    return secret;
};

// Formato razonable de email (RFC-simplificado); no verifica que el
// correo exista, solo rechaza strings que obviamente no son un email.
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export const isValidEmail = (email: string): boolean => EMAIL_REGEX.test(email.trim());

export const hashPassword = (password: string): Promise<string> => bcrypt.hash(password, 10);

export const verifyPassword = (password: string, hash: string): Promise<boolean> => bcrypt.compare(password, hash);

export const signToken = (userId: string): string => jwt.sign({ userId }, getJwtSecret(), { expiresIn: TOKEN_TTL });

export interface AuthedRequest extends Request {
    userId?: string;
}

// Cada usuario solo puede leer/escribir sus propios datos: el userId sale
// del token firmado, nunca de un parámetro que el cliente pueda falsificar.
//
// También verifica que ese userId siga existiendo en la base: una firma
// válida no basta si la cuenta ya no está (borrada por el usuario, o por
// un reseteo manual de la base de datos) — sin este chequeo, un token
// viejo se seguía aceptando y cada endpoint fallaba más abajo con errores
// confusos ("Missing log or blueprint") en vez de mandar al usuario
// limpiamente de vuelta a login.
export const requireAuth = async (req: AuthedRequest, res: Response, next: NextFunction) => {
    const header = req.headers.authorization;
    const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
        res.status(401).json({ error: 'Missing Authorization header' });
        return;
    }
    try {
        const payload = jwt.verify(token, getJwtSecret()) as { userId: string };
        const user = await getUserById(payload.userId);
        if (!user) {
            res.status(401).json({ error: 'Invalid or expired token' });
            return;
        }
        req.userId = payload.userId;
        next();
    } catch {
        res.status(401).json({ error: 'Invalid or expired token' });
    }
};
