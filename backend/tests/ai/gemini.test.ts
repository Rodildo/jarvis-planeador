import { generateBlueprint } from '../../src/ai/gemini';
import { GoogleGenAI } from '@google/genai';

jest.mock('@google/genai', () => {
    return {
        GoogleGenAI: jest.fn().mockImplementation(() => {
            return {
                models: {
                    generateContent: jest.fn().mockResolvedValue({
                        text: '{"goals": ["Test Goal"], "daily_routine": "Wake up at 6am"}'
                    })
                }
            };
        })
    };
});

describe('Gemini AI Layer', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env.GEMINI_API_KEY = 'mocked_test_key';
    });

    it('should generate a structured life blueprint based on answers', async () => {
        const mockAnswers = { "goals": "To be more organized", "condition": "bipolar" };
        const result = await generateBlueprint(mockAnswers);
        
        expect(result).toHaveProperty('goals');
        expect(result.goals).toContain('Test Goal');
        expect(result).toHaveProperty('daily_routine');
    });
});
