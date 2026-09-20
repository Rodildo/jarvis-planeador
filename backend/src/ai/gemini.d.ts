export declare const generateBlueprint: (answers: any) => Promise<any>;
export declare const generateMorningOptions: (blueprint: any, energyLevel: number) => Promise<any>;
export declare const generateMidDayAdjustment: (blueprint: any, morningEnergy: number, middayEnergy: number, chosenActions: any) => Promise<string>;
export declare const generateNextOnboardingQuestion: (previousQA: any[]) => Promise<string>;
export declare const transcribeAudio: (base64Audio: string, mimeType: string) => Promise<string>;
//# sourceMappingURL=gemini.d.ts.map