import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { apiRouter } from './api/routes';
import { initDB } from './db/database';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use('/api', apiRouter);

const startServer = async () => {
    try {
        await initDB();
        app.listen(port, () => {
            console.log(`Jarvis Backend running on port ${port}`);
        });
    } catch (err) {
        console.error('Failed to start server:', err);
        process.exit(1);
    }
};

startServer();
