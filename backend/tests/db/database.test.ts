import { initDB, saveBlueprint, getBlueprint, closeDB } from '../../src/db/database';
import fs from 'fs';

describe('Database Layer', () => {
    const testDbPath = './test-jarvis.sqlite';

    beforeAll(async () => {
        await initDB(testDbPath);
    });

    afterAll(async () => {
        await closeDB();
        if (fs.existsSync(testDbPath)) fs.unlinkSync(testDbPath);
    });

    it('should save and retrieve a life blueprint', async () => {
        const userId = 'user_1';
        const blueprint = JSON.stringify({ goals: ['Learn Node'] });
        await saveBlueprint(userId, blueprint);
        const retrieved = await getBlueprint(userId);
        expect(retrieved).toEqual(blueprint);
    });
});
