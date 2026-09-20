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
                        resolve();
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

export const saveDailyActions = async (userId: string, date: string, actions: string[]): Promise<void> => {
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
