"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const database_1 = require("../../src/db/database");
const fs_1 = __importDefault(require("fs"));
describe('Database Layer', () => {
    const testDbPath = './test-jarvis.sqlite';
    beforeAll(async () => {
        await (0, database_1.initDB)(testDbPath);
    });
    afterAll(async () => {
        await (0, database_1.closeDB)();
        if (fs_1.default.existsSync(testDbPath))
            fs_1.default.unlinkSync(testDbPath);
    });
    it('should save and retrieve a life blueprint', async () => {
        const userId = 'user_1';
        const blueprint = JSON.stringify({ goals: ['Learn Node'] });
        await (0, database_1.saveBlueprint)(userId, blueprint);
        const retrieved = await (0, database_1.getBlueprint)(userId);
        expect(retrieved).toEqual(blueprint);
    });
});
//# sourceMappingURL=database.test.js.map