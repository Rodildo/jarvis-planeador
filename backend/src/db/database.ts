import sqlite3 from 'sqlite3';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';

let db: sqlite3.Database;

export const closeDB = async (): Promise<void> => {
    return new Promise((resolve, reject) => {
        if (!db) return resolve();
        db.close((err) => {
            if (err) reject(err);
            resolve();
        });
    });
};

export const initDB = async (dbPath: string = './data/jarvis.sqlite'): Promise<void> => {
    return new Promise((resolve, reject) => {
        try {
            fs.mkdirSync(path.dirname(dbPath), { recursive: true });
        } catch (err) {
            console.error('Failed to create db directory', err);
        }
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

                db.run(`
                    CREATE TABLE IF NOT EXISTS onboarding_progress (
                        user_id TEXT PRIMARY KEY,
                        messages TEXT NOT NULL,
                        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    )
                `, (err) => {
                    if (err) reject(err);

                    db.run(`
                        CREATE TABLE IF NOT EXISTS daily_logs (
                            user_id TEXT,
                            date TEXT,
                            energy_morning INTEGER,
                            energy_midday INTEGER,
                            morning_time DATETIME,
                            actions_chosen TEXT,
                            PRIMARY KEY (user_id, date)
                        )
                    `, (err) => {
                        if (err) reject(err);

                        db.run(`
                            CREATE TABLE IF NOT EXISTS notes (
                                id TEXT PRIMARY KEY,
                                user_id TEXT NOT NULL,
                                text TEXT NOT NULL,
                                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                            )
                        `, (err) => {
                            if (err) reject(err);

                            db.run(`
                                CREATE TABLE IF NOT EXISTS users (
                                    id TEXT PRIMARY KEY,
                                    email TEXT UNIQUE NOT NULL,
                                    password_hash TEXT NOT NULL,
                                    first_name TEXT NOT NULL DEFAULT '',
                                    last_name TEXT NOT NULL DEFAULT '',
                                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                                )
                            `, (err) => {
                                if (err) reject(err);
                                // Migraciones ligeras para bases de datos creadas antes de
                                // agregar estas columnas; fallan en silencio si ya existen.
                                db.run(`ALTER TABLE users ADD COLUMN first_name TEXT NOT NULL DEFAULT ''`, () => {
                                    db.run(`ALTER TABLE users ADD COLUMN last_name TEXT NOT NULL DEFAULT ''`, () => {
                                        db.run(`ALTER TABLE users ADD COLUMN avatar TEXT`, () => {
                                            resolve();
                                        });
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    });
};

export const saveBlueprint = async (userId: string, data: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT OR REPLACE INTO blueprints (user_id, blueprint_data) VALUES (?, ?)`);
        stmt.run(userId, data, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const getBlueprint = async (userId: string): Promise<string | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT blueprint_data FROM blueprints WHERE user_id = ?`, [userId], (err, row: any) => {
            if (err) reject(err);
            else resolve(row ? row.blueprint_data : null);
        });
    });
};

export const getBlueprintUpdatedAt = async (userId: string): Promise<string | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT updated_at FROM blueprints WHERE user_id = ?`, [userId], (err, row: any) => {
            if (err) reject(err);
            else resolve(row ? row.updated_at : null);
        });
    });
};

export const hasBlueprint = async (userId: string): Promise<boolean> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT 1 FROM blueprints WHERE user_id = ?`, [userId], (err, row: any) => {
            if (err) reject(err);
            else resolve(!!row);
        });
    });
};

export const saveOnboardingProgress = async (userId: string, messages: any[]): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT OR REPLACE INTO onboarding_progress (user_id, messages) VALUES (?, ?)`);
        stmt.run(userId, JSON.stringify(messages), (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const getOnboardingProgress = async (userId: string): Promise<any[] | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT messages FROM onboarding_progress WHERE user_id = ?`, [userId], (err, row: any) => {
            if (err) reject(err);
            else {
                if (row && row.messages) {
                    try {
                        resolve(JSON.parse(row.messages));
                    } catch (e) {
                        resolve(null);
                    }
                } else {
                    resolve(null);
                }
            }
        });
    });
};

export const clearOnboardingProgress = async (userId: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        db.run(`DELETE FROM onboarding_progress WHERE user_id = ?`, [userId], (err: Error | null) => {
            if (err) reject(err);
            else resolve();
        });
    });
};

export const saveMorningLog = async (userId: string, date: string, level: number): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT INTO daily_logs (user_id, date, energy_morning, morning_time) VALUES (?, ?, ?, CURRENT_TIMESTAMP) ON CONFLICT(user_id, date) DO UPDATE SET energy_morning = excluded.energy_morning, morning_time = excluded.morning_time`);
        stmt.run(userId, date, level, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const saveMiddayLog = async (userId: string, date: string, level: number): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE daily_logs SET energy_midday = ? WHERE user_id = ? AND date = ?`);
        stmt.run(level, userId, date, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const saveDailyActions = async (userId: string, date: string, actions: any): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE daily_logs SET actions_chosen = ? WHERE user_id = ? AND date = ?`);
        stmt.run(JSON.stringify(actions), userId, date, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const getDailyLog = async (userId: string, date: string): Promise<any | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT * FROM daily_logs WHERE user_id = ? AND date = ?`, [userId, date], (err, row: any) => {
            if (err) reject(err);
            else resolve(row || null);
        });
    });
};

export const getRecentDailyLogs = async (userId: string, days: number): Promise<any[]> => {
    return new Promise((resolve, reject) => {
        db.all(
            `SELECT * FROM daily_logs WHERE user_id = ? ORDER BY date DESC LIMIT ?`,
            [userId, days],
            (err, rows: any[]) => {
                if (err) reject(err);
                else resolve(rows || []);
            }
        );
    });
};

export interface NoteRecord {
    id: string;
    text: string;
    created_at: string;
    updated_at: string;
}

export const createNote = async (id: string, userId: string, text: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT INTO notes (id, user_id, text) VALUES (?, ?, ?)`);
        stmt.run(id, userId, text, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const getNotes = async (userId: string): Promise<NoteRecord[]> => {
    return new Promise((resolve, reject) => {
        // `updated_at` solo tiene resolución de 1 segundo (CURRENT_TIMESTAMP
        // de sqlite), así que dos notas tocadas en el mismo segundo
        // quedarían en orden indefinido sin el desempate por `rowid`
        // (createNote y updateNote usan solo `UPDATE`/`INSERT`, nunca
        // reinsertan, así que `rowid` sigue reflejando cuál se tocó último).
        db.all(
            `SELECT id, text, created_at, updated_at FROM notes WHERE user_id = ? ORDER BY updated_at DESC, rowid DESC`,
            [userId],
            (err, rows: any[]) => {
                if (err) reject(err);
                else resolve(rows || []);
            }
        );
    });
};

export const updateNote = async (id: string, userId: string, text: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE notes SET text = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?`);
        stmt.run(text, id, userId, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const deleteNote = async (id: string, userId: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        db.run(`DELETE FROM notes WHERE id = ? AND user_id = ?`, [id, userId], (err: Error | null) => {
            if (err) reject(err);
            else resolve();
        });
    });
};

export const createUser = async (id: string, email: string, passwordHash: string, firstName: string, lastName: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT INTO users (id, email, password_hash, first_name, last_name) VALUES (?, ?, ?, ?, ?)`);
        stmt.run(id, email, passwordHash, firstName, lastName, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export interface UserRecord {
    id: string;
    email: string;
    password_hash: string;
    first_name: string;
    last_name: string;
    avatar: string | null;
}

export const getUserByEmail = async (email: string): Promise<UserRecord | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT id, email, password_hash, first_name, last_name, avatar FROM users WHERE email = ?`, [email], (err, row: any) => {
            if (err) reject(err);
            else resolve(row || null);
        });
    });
};

export const getUserById = async (id: string): Promise<UserRecord | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT id, email, password_hash, first_name, last_name, avatar FROM users WHERE id = ?`, [id], (err, row: any) => {
            if (err) reject(err);
            else resolve(row || null);
        });
    });
};

// `avatar` es un data URI (ej: "data:image/jpeg;base64,...") o null para
// quitar la foto. El cliente ya la redimensiona/comprime antes de subirla.
export const updateUserAvatar = async (id: string, avatar: string | null): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE users SET avatar = ? WHERE id = ?`);
        stmt.run(avatar, id, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const updateUserName = async (id: string, firstName: string, lastName: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE users SET first_name = ?, last_name = ? WHERE id = ?`);
        stmt.run(firstName, lastName, id, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const updateUserPassword = async (id: string, passwordHash: string): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE users SET password_hash = ? WHERE id = ?`);
        stmt.run(passwordHash, id, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

// Borra todo lo asociado al usuario (blueprint, brief, historial diario y
// la cuenta misma). No hay claves foráneas con cascade configurado, así
// que se borra explícitamente de cada tabla, en orden.
export const deleteUserAccount = async (id: string): Promise<void> => {
    const run = (sql: string): Promise<void> => new Promise((resolve, reject) => {
        db.run(sql, [id], (err: Error | null) => {
            if (err) reject(err);
            else resolve();
        });
    });

    await run(`DELETE FROM blueprints WHERE user_id = ?`);
    await run(`DELETE FROM onboarding_progress WHERE user_id = ?`);
    await run(`DELETE FROM daily_logs WHERE user_id = ?`);
    await run(`DELETE FROM notes WHERE user_id = ?`);
    await run(`DELETE FROM users WHERE id = ?`);
};
