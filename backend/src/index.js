"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const dotenv_1 = __importDefault(require("dotenv"));
const routes_1 = require("./api/routes");
const database_1 = require("./db/database");
dotenv_1.default.config();
const app = (0, express_1.default)();
const port = process.env.PORT || 80;
app.use((0, cors_1.default)());
app.use(express_1.default.json());
app.use('/api', routes_1.apiRouter);
const startServer = async () => {
    try {
        await (0, database_1.initDB)(process.env.DB_PATH || './data/jarvis.sqlite');
        app.listen(port, () => {
            console.log(`Jarvis Backend running on port ${port}`);
        });
    }
    catch (err) {
        console.error('Failed to start server:', err);
        process.exit(1);
    }
};
startServer();
//# sourceMappingURL=index.js.map