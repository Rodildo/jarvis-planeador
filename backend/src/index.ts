import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { apiRouter } from './api/routes';
import { initDB } from './db/database';

dotenv.config();

const app = express();
const port = process.env.PORT || 80;

// EasyPanel sirve la app detrás de un proxy reverso (Traefik). Sin esto,
// Express ve la IP interna del proxy en vez de la del cliente real, y el
// rate limiting por IP terminaría compartiendo un solo balde entre TODOS
// los usuarios en vez de uno por persona. '1' confía en exactamente un
// salto de proxy, que es la topología real acá.
app.set('trust proxy', 1);

app.use(cors());
app.use(express.json());
app.use('/api', apiRouter);

const startServer = async () => {
    try {
        await initDB(process.env.DB_PATH || './data/jarvis.sqlite');
        app.listen(port, () => {
            console.log(`Jarvis Backend running on port ${port}`);
        });
    } catch (err) {
        console.error('Failed to start server:', err);
        process.exit(1);
    }
};

startServer();
