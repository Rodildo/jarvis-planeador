import { Router } from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import { generateBlueprint, generateDailyPlan, generateMidDayAdjustment, LIFE_AREAS } from '../ai/gemini';
import {
    saveBlueprint, getBlueprint, getBlueprintUpdatedAt, saveMorningLog, saveMiddayLog, saveDailyActions, getDailyLog,
    getRecentDailyLogs, hasBlueprint, saveOnboardingProgress, getOnboardingProgress, clearOnboardingProgress,
    createUser, getUserByEmail, getUserById
} from '../db/database';
import { requireAuth, hashPassword, verifyPassword, signToken, isValidEmail, AuthedRequest } from '../auth/auth';

export const apiRouter = Router();

apiRouter.get('/version', (req, res) => {
    res.json({ version: '5.1.0-user-profile' });
});

apiRouter.get('/life-areas', (req, res) => {
    res.status(200).json({ success: true, areas: LIFE_AREAS });
});

// Protección básica contra abuso: limita cuántos registros/logins puede
// intentar una misma IP en poco tiempo, sin depender de servicios externos.
const registerLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 8,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Demasiados intentos de registro. Intenta de nuevo en unos minutos.' },
});
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 20,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Demasiados intentos de inicio de sesión. Intenta de nuevo en unos minutos.' },
});

apiRouter.post('/auth/register', registerLimiter, async (req, res) => {
    try {
        const { email, password, firstName, lastName } = req.body;
        if (!email || !password || !firstName || !lastName) {
            return res.status(400).json({ error: 'email, password, firstName and lastName are required' });
        }
        if (!isValidEmail(email)) return res.status(400).json({ error: 'Ingresa un correo con formato válido' });
        if (String(password).length < 8) return res.status(400).json({ error: 'password must be at least 8 characters' });

        const normalizedEmail = String(email).trim().toLowerCase();
        const existing = await getUserByEmail(normalizedEmail);
        if (existing) return res.status(409).json({ error: 'Email already registered' });

        const id = crypto.randomUUID();
        const passwordHash = await hashPassword(password);
        const trimmedFirstName = String(firstName).trim();
        const trimmedLastName = String(lastName).trim();
        await createUser(id, normalizedEmail, passwordHash, trimmedFirstName, trimmedLastName);

        const token = signToken(id);
        res.status(201).json({ success: true, token, userId: id, firstName: trimmedFirstName, lastName: trimmedLastName });
    } catch (error: any) {
        console.error('Register Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.post('/auth/login', loginLimiter, async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) return res.status(400).json({ error: 'email and password are required' });

        const normalizedEmail = String(email).trim().toLowerCase();
        const user = await getUserByEmail(normalizedEmail);
        if (!user) return res.status(401).json({ error: 'Invalid email or password' });

        const valid = await verifyPassword(password, user.password_hash);
        if (!valid) return res.status(401).json({ error: 'Invalid email or password' });

        const token = signToken(user.id);
        res.status(200).json({ success: true, token, userId: user.id, firstName: user.first_name, lastName: user.last_name });
    } catch (error: any) {
        console.error('Login Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

// Todo lo que sigue requiere un token válido; el userId sale de ahí, nunca
// de un parámetro/body que el cliente podría falsificar para leer datos
// ajenos.
apiRouter.use(requireAuth);

apiRouter.get('/profile', async (req: AuthedRequest, res) => {
    try {
        const complete = await hasBlueprint(req.userId!);
        const user = await getUserById(req.userId!);
        res.status(200).json({
            success: true,
            hasBlueprint: complete,
            firstName: user?.first_name ?? '',
            lastName: user?.last_name ?? '',
        });
    } catch (error: any) {
        console.error('Profile Check Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.get('/blueprint', async (req: AuthedRequest, res) => {
    try {
        const blueprint = await getBlueprint(req.userId!);
        if (blueprint) {
            const updatedAt = await getBlueprintUpdatedAt(req.userId!);
            res.status(200).json({ success: true, blueprint: JSON.parse(blueprint), updatedAt });
        } else {
            res.status(404).json({ error: 'Blueprint not found' });
        }
    } catch (error: any) {
        console.error('Get Blueprint Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.get('/onboarding/progress', async (req: AuthedRequest, res) => {
    try {
        const messages = await getOnboardingProgress(req.userId!);
        res.status(200).json({ success: true, messages: messages || [] });
    } catch (error: any) {
        console.error('Get Onboarding Progress Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.post('/onboarding/progress', async (req: AuthedRequest, res) => {
    try {
        const { messages } = req.body;
        if (!messages) return res.status(400).json({ error: 'messages is required' });
        await saveOnboardingProgress(req.userId!, messages);
        res.status(200).json({ success: true });
    } catch (error: any) {
        console.error('Save Onboarding Progress Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.post('/assessment', async (req: AuthedRequest, res) => {
    try {
        const { answers } = req.body;
        if (!answers) return res.status(400).json({ error: 'answers is required' });

        const userId = req.userId!;
        // Si ya existía un blueprint (re-brief mensual), se lo pasamos como
        // contexto para que el plan evolucione en vez de partir de cero.
        const existingBlueprint = await getBlueprint(userId);
        const blueprint = await generateBlueprint(answers, existingBlueprint ? JSON.parse(existingBlueprint) : undefined);
        await saveBlueprint(userId, JSON.stringify(blueprint));
        await clearOnboardingProgress(userId);
        res.status(200).json({ success: true, blueprint });
    } catch (error: any) {
        console.error('Assessment Error:', error);
        res.status(500).json({ error: error.stack || String(error) || 'Internal server error' });
    }
});

apiRouter.get('/daily-log/:date', async (req: AuthedRequest, res) => {
    try {
        const date = req.params.date;
        if (!date || Array.isArray(date)) return res.status(400).json({ error: 'date is required' });
        const dailyLog = await getDailyLog(req.userId!, date);
        res.status(200).json({ success: true, dailyLog });
    } catch (error: any) {
        console.error('Get Daily Log Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.get('/history', async (req: AuthedRequest, res) => {
    try {
        const days = Math.min(parseInt(String(req.query.days ?? '30'), 10) || 30, 90);
        const logs = await getRecentDailyLogs(req.userId!, days);
        res.status(200).json({ success: true, logs });
    } catch (error: any) {
        console.error('Get History Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.post('/daily-plan', async (req: AuthedRequest, res) => {
    try {
        const { date, energyLevel } = req.body;
        if (!date || energyLevel === undefined) return res.status(400).json({ error: 'date and energyLevel are required' });

        const userId = req.userId!;
        await saveMorningLog(userId, date, energyLevel);

        const blueprintData = await getBlueprint(userId);
        if (!blueprintData) return res.status(404).json({ error: 'Blueprint not found for user' });

        const user = await getUserById(userId);
        const plan = await generateDailyPlan(JSON.parse(blueprintData), energyLevel, user?.first_name);
        res.status(200).json({ success: true, plan });
    } catch (error: any) {
        console.error('Daily Plan Error:', error);
        res.status(500).json({ error: error.stack || String(error) || 'Internal server error' });
    }
});

apiRouter.post('/daily-actions', async (req: AuthedRequest, res) => {
    try {
        const { date, actions } = req.body;
        if (!date || !actions) return res.status(400).json({ error: 'Missing required fields' });

        await saveDailyActions(req.userId!, date, actions);
        res.status(200).json({ success: true });
    } catch (error: any) {
        console.error('Save Actions Error:', error);
        res.status(500).json({ error: error.stack || String(error) || 'Internal server error' });
    }
});

apiRouter.post('/midday', async (req: AuthedRequest, res) => {
    try {
        const { date, energyLevel } = req.body;
        if (!date || energyLevel === undefined) return res.status(400).json({ error: 'Missing fields' });

        const userId = req.userId!;
        await saveMiddayLog(userId, date, energyLevel);

        const dailyLog = await getDailyLog(userId, date);
        const blueprintData = await getBlueprint(userId);

        if (!dailyLog || !blueprintData) return res.status(404).json({ error: 'Missing log or blueprint' });

        let dailyState: any = {};
        if (dailyLog.actions_chosen) dailyState = JSON.parse(dailyLog.actions_chosen);

        const message = await generateMidDayAdjustment(JSON.parse(blueprintData), dailyLog.energy_morning, energyLevel, dailyState.plan ?? dailyState);
        res.status(200).json({ success: true, message });
    } catch (error: any) {
        console.error('Midday Error:', error);
        res.status(500).json({ error: error.stack || String(error) || 'Internal server error' });
    }
});
