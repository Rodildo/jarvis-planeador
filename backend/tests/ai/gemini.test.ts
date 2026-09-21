import { generateBlueprint } from '../../src/ai/gemini';

describe('Gemini AI Layer (OpenRouter)', () => {
    beforeEach(() => {
        jest.restoreAllMocks();
        process.env.OPENROUTER_API_KEY = 'mocked_test_key';
    });

    it('should generate a structured life blueprint based on answers', async () => {
        const mockAnswers = { goals: 'To be more organized', energy_pattern: 'varies day to day' };

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

    it('sends an explicit max_tokens so the model does not truncate long JSON output', async () => {
        const fetchMock = jest.fn().mockResolvedValue({
            ok: true,
            json: async () => ({ choices: [{ message: { content: '{"goals": [], "daily_routine": "x"}' } }] })
        });
        global.fetch = fetchMock as unknown as typeof fetch;

        await generateBlueprint({ q: 'a' });

        const requestBody = JSON.parse(fetchMock.mock.calls[0][1].body);
        expect(requestBody.max_tokens).toBeGreaterThan(0);
    });

    it('retries with a fresh generation when the model truncates the JSON mid-response', async () => {
        // Primera respuesta: JSON cortado a mitad de un string, como pasa
        // cuando el modelo se queda sin tokens antes de terminar.
        const truncated = '{"goals": ["Unfinished go';
        const complete = '{"goals": ["Recovered Goal"], "daily_routine": "Wake up at 6am"}';

        const fetchMock = jest.fn()
            .mockResolvedValueOnce({ ok: true, json: async () => ({ choices: [{ message: { content: truncated } }] }) })
            .mockResolvedValueOnce({ ok: true, json: async () => ({ choices: [{ message: { content: complete } }] }) });
        global.fetch = fetchMock as unknown as typeof fetch;

        const result = await generateBlueprint({ q: 'a' });

        expect(fetchMock).toHaveBeenCalledTimes(2);
        expect(result.goals).toContain('Recovered Goal');
    });
});
