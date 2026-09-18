# Jarvis Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Inicializar el subsistema Backend VPS de Jarvis, configurando la base de datos persistente (SQLite) y la integración de IA (Google Gemini API) para procesar el test de 100 preguntas y generar el Life Blueprint.

**Architecture:** Servidor Node.js con TypeScript, Express para endpoints REST, SQLite3 (modo WAL) para persistencia ultrarrápida y local, y el SDK `@google/genai` para el razonamiento estructurado.

**Tech Stack:** Node.js, TypeScript, Express, SQLite3, Jest (para TDD), `@google/genai`.

**Spec:** `docs/superpowers/specs/2026-09-17-jarvis-life-planner-design.md`

## Global Constraints

- Plataforma de ejecución: Linux (VPS Hostinger).
- Base de datos: `sqlite3` corriendo en modo WAL (`PRAGMA journal_mode=WAL;`).
- SDK Inteligencia Artificial: Uso estricto de `@google/genai` (versión oficial actual).
- Manejo de Errores: Todas las llamadas a Gemini deben tener un *fallback* manejado si hay error de red o de parseo JSON.

---

### Task 1: Project Setup and SQLite Database Layer

**Files:**
- Create: `backend/package.json`
- Create: `backend/tsconfig.json`
- Create: `backend/src/db/database.ts`
- Create: `backend/tests/db/database.test.ts`

**Interfaces:**
- Produces: `initDB()` (promesa que resuelve a una instancia de base de datos sqlite), `saveBlueprint(userId: string, data: string)`

- [ ] **Step 1: Scaffolding de Node.js y dependencias**

```bash
mkdir -p backend/src/db backend/tests/db
cd backend
npm init -y
npm install express sqlite3 @google/genai dotenv
npm install --save-dev typescript @types/node @types/express @types/sqlite3 jest ts-jest @types/jest
npx tsc --init
```

- [ ] **Step 2: Write the failing test**

```typescript
// backend/tests/db/database.test.ts
import { initDB, saveBlueprint, getBlueprint } from '../../src/db/database';
import fs from 'fs';

describe('Database Layer', () => {
    const testDbPath = './test-jarvis.sqlite';

    beforeAll(async () => {
        await initDB(testDbPath);
    });

    afterAll(() => {
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd backend && npx jest tests/db/database.test.ts`
Expected: FAIL with "Cannot find module" or "initDB is not defined"

- [ ] **Step 4: Write minimal implementation**

```typescript
// backend/src/db/database.ts
import sqlite3 from 'sqlite3';
import { promisify } from 'util';

let db: sqlite3.Database;

export const initDB = async (dbPath: string = './jarvis.sqlite'): Promise<void> => {
    return new Promise((resolve, reject) => {
        db = new sqlite3.Database(dbPath, (err) => {
            if (err) reject(err);
            db.run(`PRAGMA journal_mode=WAL;`);
            db.run(`
                CREATE TABLE IF NOT EXISTS blueprints (
                    user_id TEXT PRIMARY KEY,
                    blueprint_data TEXT NOT NULL,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            `, (err) => {
                if (err) reject(err);
                resolve();
            });
        });
    });
};

export const saveBlueprint = async (userId: string, data: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT OR REPLACE INTO blueprints (user_id, blueprint_data) VALUES (?, ?)`);
        stmt.run(userId, data, (err: Error | null) => {
            if (err) reject(err);
            resolve();
        });
    });
};

export const getBlueprint = async (userId: string): Promise<string | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT blueprint_data FROM blueprints WHERE user_id = ?`, [userId], (err, row: any) => {
            if (err) reject(err);
            resolve(row ? row.blueprint_data : null);
        });
    });
};
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && npx jest tests/db/database.test.ts`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/
git commit -m "feat: initialize backend project and SQLite layer with WAL mode"
```

---

### Task 2: Gemini API Integration for Life Blueprint Generation

**Files:**
- Create: `backend/src/ai/gemini.ts`
- Create: `backend/tests/ai/gemini.test.ts`

**Interfaces:**
- Consumes: Google Gemini API Key via `process.env.GEMINI_API_KEY`
- Produces: `generateLifeBlueprint(answers: string[])` -> Returns parsed JSON object.

- [ ] **Step 1: Write the failing test**

```typescript
// backend/tests/ai/gemini.test.ts
import { generateLifeBlueprint } from '../../src/ai/gemini';

// Mock the Gemini API globally for unit testing
jest.mock('@google/genai', () => {
    return {
        GoogleGenAI: jest.fn().mockImplementation(() => ({
            models: {
                generateContent: jest.fn().mockResolvedValue({
                    text: '{"goals": ["Test Goal"]}'
                })
            }
        }))
    };
});

describe('Gemini Integration', () => {
    it('should generate a structured life blueprint from answers', async () => {
        const answers = ["I want to learn to code.", "I want a new job."];
        const blueprint = await generateLifeBlueprint(answers);
        expect(blueprint.goals).toContain("Test Goal");
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest tests/ai/gemini.test.ts`
Expected: FAIL with "generateLifeBlueprint is not defined"

- [ ] **Step 3: Write minimal implementation**

```typescript
// backend/src/ai/gemini.ts
import { GoogleGenAI } from '@google/genai';

export const generateLifeBlueprint = async (answers: string[]): Promise<any> => {
    const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || 'test_key' });
    
    const prompt = `
    Eres Jarvis, un estratega de vida. El usuario ha respondido un test.
    Respuestas: ${JSON.stringify(answers)}
    
    Analiza y devuelve un plan estructurado en JSON con esta estructura exacta:
    { "goals": ["lista de metas clave a corto, mediano y largo plazo"] }
    `;

    try {
        const response = await ai.models.generateContent({
            model: 'gemini-2.5-flash',
            contents: prompt,
            config: {
                responseMimeType: 'application/json',
                temperature: 0.2
            }
        });
        
        return JSON.parse(response.text);
    } catch (error) {
        throw new Error(`Failed to generate blueprint: ${error}`);
    }
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest tests/ai/gemini.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/ai/gemini.ts backend/tests/ai/gemini.test.ts
git commit -m "feat: implement Gemini integration for life blueprint generation"
```

---

### Task 3: Express API Endpoint for 100-Questions Assessment

**Files:**
- Create: `backend/src/server.ts`
- Create: `backend/tests/api/server.test.ts`

**Interfaces:**
- Consumes: `initDB`, `saveBlueprint` from Task 1, `generateLifeBlueprint` from Task 2.
- Produces: REST Endpoint `POST /api/assessment` listening on port 3000.

- [ ] **Step 1: Write the failing test**

```typescript
// backend/tests/api/server.test.ts
import request from 'supertest';
import { app, server } from '../../src/server';
import { initDB } from '../../src/db/database';
import fs from 'fs';

// Mock Gemini generator
jest.mock('../../src/ai/gemini', () => ({
    generateLifeBlueprint: jest.fn().mockResolvedValue({ goals: ["API Test Goal"] })
}));

describe('API Server', () => {
    const dbPath = './test-api.sqlite';
    
    beforeAll(async () => {
        await initDB(dbPath);
    });
    
    afterAll((done) => {
        if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);
        server.close(done);
    });

    it('should process 100-questions submission via POST /api/assessment', async () => {
        const response = await request(app)
            .post('/api/assessment')
            .send({
                userId: "user_api",
                answers: ["Amo la paz", "Quiero ahorrar"]
            });
            
        expect(response.status).toBe(200);
        expect(response.body.message).toBe("Blueprint generated and saved");
        expect(response.body.blueprint.goals).toContain("API Test Goal");
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npm install --save-dev supertest @types/supertest && npx jest tests/api/server.test.ts`
Expected: FAIL with "app not found"

- [ ] **Step 3: Write minimal implementation**

```typescript
// backend/src/server.ts
import express from 'express';
import { saveBlueprint, initDB } from './db/database';
import { generateLifeBlueprint } from './ai/gemini';

export const app = express();
app.use(express.json());

app.post('/api/assessment', async (req, res) => {
    const { userId, answers } = req.body;
    try {
        const blueprint = await generateLifeBlueprint(answers);
        await saveBlueprint(userId, JSON.stringify(blueprint));
        res.status(200).json({ message: "Blueprint generated and saved", blueprint });
    } catch (error) {
        res.status(500).json({ error: "Failed to process assessment" });
    }
});

export const server = app.listen(3000, () => {
    console.log('Jarvis backend running on port 3000');
});

// Avoid executing initDB directly when imported in tests
if (require.main === module) {
    initDB('./jarvis.sqlite').catch(console.error);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest tests/api/server.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/server.ts backend/tests/api/server.test.ts package.json package-lock.json
git commit -m "feat: add Express REST API for processing life assessment"
```
