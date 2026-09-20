"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDailyLog = exports.saveDailyActions = exports.saveMiddayLog = exports.saveMorningLog = exports.getBlueprint = exports.saveBlueprint = exports.initDB = exports.closeDB = void 0;
const sqlite3_1 = __importDefault(require("sqlite3"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
let db;
const closeDB = async () => {
    return new Promise((resolve, reject) => {
        if (!db)
            return resolve();
        db.close((err) => {
            if (err)
                reject(err);
            resolve();
        });
    });
};
exports.closeDB = closeDB;
const initDB = async (dbPath = './data/jarvis.sqlite') => {
    return new Promise((resolve, reject) => {
        try {
            fs_1.default.mkdirSync(path_1.default.dirname(dbPath), { recursive: true });
        }
        catch (err) {
            console.error('Failed to create db directory', err);
        }
        db = new sqlite3_1.default.Database(dbPath, (err) => {
            if (err)
                reject(err);
            db.run(`PRAGMA journal_mode=WAL;`);
            db.run(`
                CREATE TABLE IF NOT EXISTS blueprints (
                    user_id TEXT PRIMARY KEY,
                    blueprint_data TEXT NOT NULL,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            `, (err) => {
                if (err)
                    reject(err);
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
                    if (err)
                        reject(err);
                    resolve();
                });
            });
        });
    });
};
exports.initDB = initDB;
const saveBlueprint = async (userId, data) => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT OR REPLACE INTO blueprints (user_id, blueprint_data) VALUES (?, ?)`);
        stmt.run(userId, data, (err) => {
            stmt.finalize();
            if (err)
                reject(err);
            else
                resolve();
        });
    });
};
exports.saveBlueprint = saveBlueprint;
const getBlueprint = async (userId) => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT blueprint_data FROM blueprints WHERE user_id = ?`, [userId], (err, row) => {
            if (err)
                reject(err);
            else
                resolve(row ? row.blueprint_data : null);
        });
    });
};
exports.getBlueprint = getBlueprint;
const saveMorningLog = async (userId, date, level) => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`INSERT INTO daily_logs (user_id, date, energy_morning, morning_time) VALUES (?, ?, ?, CURRENT_TIMESTAMP) ON CONFLICT(user_id, date) DO UPDATE SET energy_morning = excluded.energy_morning, morning_time = excluded.morning_time`);
        stmt.run(userId, date, level, (err) => {
            stmt.finalize();
            if (err)
                reject(err);
            else
                resolve();
        });
    });
};
exports.saveMorningLog = saveMorningLog;
const saveMiddayLog = async (userId, date, level) => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE daily_logs SET energy_midday = ? WHERE user_id = ? AND date = ?`);
        stmt.run(level, userId, date, (err) => {
            stmt.finalize();
            if (err)
                reject(err);
            else
                resolve();
        });
    });
};
exports.saveMiddayLog = saveMiddayLog;
const saveDailyActions = async (userId, date, actions) => {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`UPDATE daily_logs SET actions_chosen = ? WHERE user_id = ? AND date = ?`);
        stmt.run(JSON.stringify(actions), userId, date, (err) => {
            stmt.finalize();
            if (err)
                reject(err);
            else
                resolve();
        });
    });
};
exports.saveDailyActions = saveDailyActions;
const getDailyLog = async (userId, date) => {
    return new Promise((resolve, reject) => {
        db.get(`SELECT * FROM daily_logs WHERE user_id = ? AND date = ?`, [userId, date], (err, row) => {
            if (err)
                reject(err);
            else
                resolve(row || null);
        });
    });
};
exports.getDailyLog = getDailyLog;
//# sourceMappingURL=database.js.map