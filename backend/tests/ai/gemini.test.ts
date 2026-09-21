import { generateBlueprint, generateDailyPlan, generateMidDayReplan, energyModeChanged } from '../../src/ai/gemini';

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

describe('energyModeChanged', () => {
    it('is false when both levels fall in the same bucket (refugio/estable/expansion)', () => {
        expect(energyModeChanged(1, 2)).toBe(false);
        expect(energyModeChanged(3, 3)).toBe(false);
        expect(energyModeChanged(4, 5)).toBe(false);
    });

    it('is true when the levels cross into a different bucket', () => {
        expect(energyModeChanged(5, 1)).toBe(true);
        expect(energyModeChanged(2, 3)).toBe(true);
        expect(energyModeChanged(3, 4)).toBe(true);
    });
});

describe('generateMidDayReplan', () => {
    beforeEach(() => {
        jest.restoreAllMocks();
        process.env.OPENROUTER_API_KEY = 'mocked_test_key';
    });

    it('asks for updated midday/night tasks plus a message, with an explicit max_tokens', async () => {
        const fetchMock = jest.fn().mockResolvedValue({
            ok: true,
            json: async () => ({
                choices: [{ message: { content: '{"message": "Bajemos el ritmo.", "midday": [], "night": []}' } }]
            })
        });
        global.fetch = fetchMock as unknown as typeof fetch;

        const result = await generateMidDayReplan({ areas: {} }, 1, { midday: [], night: [] });

        expect(result.message).toBe('Bajemos el ritmo.');
        expect(result).toHaveProperty('midday');
        expect(result).toHaveProperty('night');

        const requestBody = JSON.parse(fetchMock.mock.calls[0][1].body);
        expect(requestBody.max_tokens).toBeGreaterThan(0);
        expect(requestBody.response_format).toEqual({ type: 'json_object' });
    });

    it('retries with a fresh generation when the model truncates the JSON mid-response', async () => {
        const truncated = '{"message": "Bajemos el rit';
        const complete = '{"message": "Bajemos el ritmo.", "midday": [{"task": "Descansa", "reason": "r"}], "night": []}';

        const fetchMock = jest.fn()
            .mockResolvedValueOnce({ ok: true, json: async () => ({ choices: [{ message: { content: truncated } }] }) })
            .mockResolvedValueOnce({ ok: true, json: async () => ({ choices: [{ message: { content: complete } }] }) });
        global.fetch = fetchMock as unknown as typeof fetch;

        const result = await generateMidDayReplan({ areas: {} }, 1, { midday: [], night: [] });

        expect(fetchMock).toHaveBeenCalledTimes(2);
        expect(result.midday[0].task).toBe('Descansa');
    });
});

describe('language directive', () => {
    beforeEach(() => {
        jest.restoreAllMocks();
        process.env.OPENROUTER_API_KEY = 'mocked_test_key';
    });

    it('instructs the model to answer in English when language is "en"', async () => {
        const fetchMock = jest.fn().mockResolvedValue({
            ok: true,
            json: async () => ({ choices: [{ message: { content: '{"greeting": "hi", "morning": [], "midday": [], "night": []}' } }] })
        });
        global.fetch = fetchMock as unknown as typeof fetch;

        await generateDailyPlan({ areas: {} }, 3, 'Jorge', 'en');

        const requestBody = JSON.parse(fetchMock.mock.calls[0][1].body);
        expect(requestBody.messages[0].content).toContain('Respond only in English');
    });

    it('defaults to Spanish when no language is given', async () => {
        const fetchMock = jest.fn().mockResolvedValue({
            ok: true,
            json: async () => ({ choices: [{ message: { content: '{"greeting": "hi", "morning": [], "midday": [], "night": []}' } }] })
        });
        global.fetch = fetchMock as unknown as typeof fetch;

        await generateDailyPlan({ areas: {} }, 3, 'Jorge');

        const requestBody = JSON.parse(fetchMock.mock.calls[0][1].body);
        expect(requestBody.messages[0].content).toContain('Responde solo en español');
    });
});
