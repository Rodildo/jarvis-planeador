import { Router } from 'express';
import crypto from 'crypto';
import rateLimit from 'express-rate-limit';
import { generateBlueprint, generateDailyPlan, generateMidDayAdjustment, generateMidDayReplan, energyModeChanged, LIFE_AREAS } from '../ai/gemini';
import {
    saveBlueprint, getBlueprint, getBlueprintUpdatedAt, saveMorningLog, saveMiddayLog, saveDailyActions, getDailyLog,
    getRecentDailyLogs, hasBlueprint, saveOnboardingProgress, getOnboardingProgress, clearOnboardingProgress,
    createUser, getUserByEmail, getUserById, updateUserName, updateUserPassword, updateUserAvatar, deleteUserAccount
} from '../db/database';
import { requireAuth, hashPassword, verifyPassword, signToken, isValidEmail, AuthedRequest } from '../auth/auth';

export const apiRouter = Router();

// minBuildNumber se sube a mano cada vez que se quiere forzar que todos
// los usuarios actualicen a una versión nueva del APK (ej. tras un cambio
// incompatible). Se compara contra kAppBuildNumber del cliente
// (frontend/lib/core/app_info.dart, que a su vez debe ir sincronizado con
// el "+N" de la versión en pubspec.yaml en cada release) — si el cliente
// tiene un build menor, se bloquea con la pantalla de actualización
// obligatoria. Ver docs/reference/06-decisions.md.
const MIN_SUPPORTED_BUILD_NUMBER = 1;

apiRouter.get('/version', (req, res) => {
    res.json({ version: '5.2.0-i18n', minBuildNumber: MIN_SUPPORTED_BUILD_NUMBER });
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

// Estos endpoints le pegan a OpenRouter (cuestan dinero real por cada
// llamada), así que además de proteger contra abuso, este límite protege
// contra un bug en el cliente que dispare llamadas en bucle.
const aiCostLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 30,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Demasiadas solicitudes a Jarvis en poco tiempo. Intenta de nuevo en un rato.' },
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
            avatar: user?.avatar ?? null,
        });
    } catch (error: any) {
        console.error('Profile Check Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

// Tamaño máximo del data URI aceptado (~750KB en base64, de sobra para una
// foto de perfil ya comprimida/redimensionada del lado del cliente).
const MAX_AVATAR_LENGTH = 1_000_000;

apiRouter.put('/profile/avatar', async (req: AuthedRequest, res) => {
    try {
        const { avatar } = req.body;
        if (typeof avatar !== 'string' || !avatar.startsWith('data:image/')) {
            return res.status(400).json({ error: 'avatar debe ser una imagen en formato data URI (data:image/...)' });
        }
        if (avatar.length > MAX_AVATAR_LENGTH) {
            return res.status(413).json({ error: 'La imagen es demasiado grande. Intenta con una más pequeña.' });
        }
        await updateUserAvatar(req.userId!, avatar);
        res.status(200).json({ success: true, avatar });
    } catch (error: any) {
        console.error('Update Avatar Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.delete('/profile/avatar', async (req: AuthedRequest, res) => {
    try {
        await updateUserAvatar(req.userId!, null);
        res.status(200).json({ success: true });
    } catch (error: any) {
        console.error('Delete Avatar Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.patch('/profile', async (req: AuthedRequest, res) => {
    try {
        const { firstName, lastName } = req.body;
        const trimmedFirstName = String(firstName ?? '').trim();
        const trimmedLastName = String(lastName ?? '').trim();
        if (!trimmedFirstName || !trimmedLastName) {
            return res.status(400).json({ error: 'firstName and lastName are required' });
        }
        await updateUserName(req.userId!, trimmedFirstName, trimmedLastName);
        res.status(200).json({ success: true, firstName: trimmedFirstName, lastName: trimmedLastName });
    } catch (error: any) {
        console.error('Update Profile Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.post('/auth/change-password', async (req: AuthedRequest, res) => {
    try {
        const { currentPassword, newPassword } = req.body;
        if (!currentPassword || !newPassword) {
            return res.status(400).json({ error: 'currentPassword and newPassword are required' });
        }
        if (String(newPassword).length < 8) return res.status(400).json({ error: 'newPassword must be at least 8 characters' });

        const user = await getUserById(req.userId!);
        if (!user) return res.status(404).json({ error: 'User not found' });

        const valid = await verifyPassword(currentPassword, user.password_hash);
        if (!valid) return res.status(401).json({ error: 'La contraseña actual no es correcta' });

        const newHash = await hashPassword(newPassword);
        await updateUserPassword(user.id, newHash);
        res.status(200).json({ success: true });
    } catch (error: any) {
        console.error('Change Password Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

// Verifica la contraseña actual sin ningún efecto secundario (a diferencia
// de /auth/change-password o /account, que si la validan pero además
// cambian algo). Lo usa el cliente para pedir confirmación con contraseña
// antes de acciones destructivas/importantes que no son ni cambiar la
// clave ni borrar la cuenta — ej. regenerar el Life Blueprint.
apiRouter.post('/auth/verify-password', loginLimiter, async (req: AuthedRequest, res) => {
    try {
        const { password } = req.body;
        if (!password) return res.status(400).json({ error: 'password is required' });

        const user = await getUserById(req.userId!);
        if (!user) return res.status(404).json({ error: 'User not found' });

        const valid = await verifyPassword(password, user.password_hash);
        if (!valid) return res.status(401).json({ error: 'Contraseña incorrecta' });

        res.status(200).json({ success: true });
    } catch (error: any) {
        console.error('Verify Password Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.delete('/account', async (req: AuthedRequest, res) => {
    try {
        const { password } = req.body;
        if (!password) return res.status(400).json({ error: 'password is required to confirm account deletion' });

        const user = await getUserById(req.userId!);
        if (!user) return res.status(404).json({ error: 'User not found' });

        const valid = await verifyPassword(password, user.password_hash);
        if (!valid) return res.status(401).json({ error: 'Contraseña incorrecta' });

        await deleteUserAccount(req.userId!);
        res.status(200).json({ success: true });
    } catch (error: any) {
        console.error('Delete Account Error:', error);
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

apiRouter.post('/assessment', aiCostLimiter, async (req: AuthedRequest, res) => {
    try {
        const { answers, language } = req.body;
        if (!answers) return res.status(400).json({ error: 'answers is required' });

        const userId = req.userId!;
        // Si ya existía un blueprint (re-brief mensual), se lo pasamos como
        // contexto para que el plan evolucione en vez de partir de cero.
        const existingBlueprint = await getBlueprint(userId);
        const blueprint = await generateBlueprint(answers, existingBlueprint ? JSON.parse(existingBlueprint) : undefined, language);
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
        // Tope alto (un año) para que la predicción de energía tenga
        // suficiente historial de patrones por día de la semana.
        const days = Math.min(parseInt(String(req.query.days ?? '30'), 10) || 30, 365);
        const logs = await getRecentDailyLogs(req.userId!, days);
        res.status(200).json({ success: true, logs });
    } catch (error: any) {
        console.error('Get History Error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});

apiRouter.post('/daily-plan', aiCostLimiter, async (req: AuthedRequest, res) => {
    try {
        const { date, energyLevel, language } = req.body;
        if (!date || energyLevel === undefined) return res.status(400).json({ error: 'date and energyLevel are required' });

        const userId = req.userId!;
        await saveMorningLog(userId, date, energyLevel);

        const blueprintData = await getBlueprint(userId);
        if (!blueprintData) return res.status(404).json({ error: 'Blueprint not found for user' });

        const user = await getUserById(userId);
        const plan = await generateDailyPlan(JSON.parse(blueprintData), energyLevel, user?.first_name, language);
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

apiRouter.post('/midday', aiCostLimiter, async (req: AuthedRequest, res) => {
    try {
        const { date, energyLevel, language } = req.body;
        if (!date || energyLevel === undefined) return res.status(400).json({ error: 'Missing fields' });

        const userId = req.userId!;
        await saveMiddayLog(userId, date, energyLevel);

        const dailyLog = await getDailyLog(userId, date);
        const blueprintData = await getBlueprint(userId);

        if (!dailyLog || !blueprintData) return res.status(404).json({ error: 'Missing log or blueprint' });

        let dailyState: any = {};
        if (dailyLog.actions_chosen) dailyState = JSON.parse(dailyLog.actions_chosen);

        const blueprint = JSON.parse(blueprintData);
        const morningEnergy = dailyLog.energy_morning;
        const currentPlan = dailyState.plan ?? dailyState;

        // Si el nivel de energía cruzó a un balde distinto (refugio/estable/
        // expansión) desde la mañana, el plan original ya no encaja de
        // verdad: se regeneran midday/night en vez de solo dar un mensaje.
        if (morningEnergy != null && energyModeChanged(morningEnergy, energyLevel)) {
            const user = await getUserById(userId);
            const replan = await generateMidDayReplan(blueprint, energyLevel, currentPlan, user?.first_name, language);

            const updatedPlan = { ...currentPlan, midday: replan.midday, night: replan.night };

            // Las tareas de midday/night cambiaron, así que los "completada"
            // guardados para esos bloques ya no corresponden a nada real;
            // se descartan. Lo de la mañana y las tareas manuales del
            // usuario quedan intactos.
            const oldCompleted: Record<string, boolean> = dailyState.completed ?? {};
            const completed: Record<string, boolean> = {};
            for (const key of Object.keys(oldCompleted)) {
                if (key.startsWith('ai-midday-') || key.startsWith('ai-night-')) continue;
                completed[key] = oldCompleted[key] ?? false;
            }

            const updatedState = { plan: updatedPlan, completed, manualTasks: dailyState.manualTasks ?? [] };
            await saveDailyActions(userId, date, updatedState);

            res.status(200).json({ success: true, message: replan.message, plan: updatedPlan, completed });
        } else {
            const message = await generateMidDayAdjustment(blueprint, morningEnergy, energyLevel, currentPlan, language);
            res.status(200).json({ success: true, message });
        }
    } catch (error: any) {
        console.error('Midday Error:', error);
        res.status(500).json({ error: error.stack || String(error) || 'Internal server error' });
    }
});
