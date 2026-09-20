import { generateBlueprint } from '../../src/ai/gemini';

describe('Gemini AI Layer (OpenRouter)', () => {
    beforeEach(() => {
        jest.restoreAllMocks();
        process.env.OPENROUTER_API_KEY = 'mocked_test_key';
    });

    it('should generate a structured life blueprint based on answers', async () => {
        const mockAnswers = { goals: 'To be more organized', condition: 'bipolar' };

        global.fetch = jest.fn().mockResolvedValue({
            ok: true,
            json: async () => ({
                choices: [
                    { message: { content: '{"goals": ["Test Goal"], "daily_routine": "Wake up at 6am"}' } }
                ]
            })
        }) as unknown as typeof fetch;

        const result = await generateBlueprint(mockAnswers);

        expect(result).toHaveProperty('goals');
        expect(result.goals).toContain('Test Goal');
        expect(result).toHaveProperty('daily_routine');
    });
});
