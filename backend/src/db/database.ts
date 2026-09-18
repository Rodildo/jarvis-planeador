import sqlite3 from 'sqlite3';
import { promisify } from 'util';

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
                
                db.run(`
                    CREATE TABLE IF NOT EXISTS daily_logs (
                        user_id TEXT,
                        date TEXT,
                        energy_level INTEGER,
                        PRIMARY KEY (user_id, date)
                    )
                `, (err) => {
                    if (err) reject(err);
                    resolve();
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

export const saveEnergyLevel = async (userId: string, date: string, level: number): Promise<void> => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT OR REPLACE INTO daily_logs (user_id, date, energy_level) VALUES (?, ?, ?)`);
        stmt.run(userId, date, level, (err: Error | null) => {
            stmt.finalize();
            if (err) reject(err);
            else resolve();
        });
    });
};

export const getEnergyLevel = async (userId: string, date: string): Promise<number | null> => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT energy_level FROM daily_logs WHERE user_id = ? AND date = ?`, [userId, date], (err, row: any) => {
            if (err) reject(err);
            else resolve(row ? row.energy_level : null);
        });
    });
};
