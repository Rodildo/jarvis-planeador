"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const supertest_1 = __importDefault(require("supertest"));
const express_1 = __importDefault(require("express"));
const routes_1 = require("../../src/api/routes");
const database_1 = require("../../src/db/database");
const gemini_1 = require("../../src/ai/gemini");
jest.mock('../../src/db/database');
jest.mock('../../src/ai/gemini');
const app = (0, express_1.default)();
app.use(express_1.default.json());
app.use('/api', routes_1.apiRouter);
describe('API Routes - Briefing', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });
    it('POST /api/briefing should generate a morning briefing', async () => {
        const mockBlueprint = JSON.stringify({ goals: ['Goal 1'] });
        const mockBriefing = "Good morning! Time to work on Goal 1.";
        database_1.getBlueprint.mockResolvedValue(mockBlueprint);
        database_1.saveEnergyLevel.mockResolvedValue(undefined);
        gemini_1.generateMorningBriefing.mockResolvedValue(mockBriefing);
        const response = await (0, supertest_1.default)(app)
            .post('/api/briefing')
            .send({ userId: 'user_123', date: '2026-09-17', energyLevel: 5 });
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('success', true);
        expect(response.body.briefing).toEqual(mockBriefing);
        expect(database_1.saveEnergyLevel).toHaveBeenCalledWith('user_123', '2026-09-17', 5);
        expect(database_1.getBlueprint).toHaveBeenCalledWith('user_123');
        expect(gemini_1.generateMorningBriefing).toHaveBeenCalledWith(JSON.parse(mockBlueprint), 5);
    });
    it('POST /api/briefing should return 404 if blueprint is missing', async () => {
        database_1.getBlueprint.mockResolvedValue(null);
        const response = await (0, supertest_1.default)(app)
            .post('/api/briefing')
            .send({ userId: 'user_123', date: '2026-09-17', energyLevel: 5 });
        expect(response.status).toBe(404);
        expect(response.body.error).toBe('Blueprint not found for user');
    });
});
//# sourceMappingURL=briefing.test.js.map