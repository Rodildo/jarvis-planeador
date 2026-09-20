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
describe('API Routes', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });
    it('POST /api/assessment should generate and save a blueprint', async () => {
        const mockAnswers = { q1: 'answer 1' };
        const mockBlueprint = { goals: ['Mock Goal'], daily_routine: 'Mock Routine' };
        gemini_1.generateBlueprint.mockResolvedValue(mockBlueprint);
        database_1.saveBlueprint.mockResolvedValue(undefined);
        const response = await (0, supertest_1.default)(app)
            .post('/api/assessment')
            .send({ userId: 'user_123', answers: mockAnswers });
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('success', true);
        expect(response.body.blueprint).toEqual(mockBlueprint);
        expect(gemini_1.generateBlueprint).toHaveBeenCalledWith(mockAnswers);
        expect(database_1.saveBlueprint).toHaveBeenCalledWith('user_123', JSON.stringify(mockBlueprint));
    });
    it('POST /api/assessment should return 400 if userId or answers are missing', async () => {
        const response = await (0, supertest_1.default)(app)
            .post('/api/assessment')
            .send({ answers: {} }); // missing userId
        expect(response.status).toBe(400);
    });
});
//# sourceMappingURL=routes.test.js.map