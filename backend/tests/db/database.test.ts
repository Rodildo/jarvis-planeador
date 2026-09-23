import { initDB, saveBlueprint, getBlueprint, closeDB, createNote, getNotes, updateNote, deleteNote, deleteUserAccount } from '../../src/db/database';
import fs from 'fs';

describe('Database Layer', () => {
    const testDbPath = './test-jarvis.sqlite';

    beforeAll(async () => {
        await initDB(testDbPath);
    });

    afterAll(async () => {
        await closeDB();
        if (fs.existsSync(testDbPath)) fs.unlinkSync(testDbPath);
    });

    it('should save and retrieve a life blueprint', async () => {
        const userId = 'user_1';
        const blueprint = JSON.stringify({ goals: ['Learn Node'] });
        await saveBlueprint(userId, blueprint);
        const retrieved = await getBlueprint(userId);
        expect(retrieved).toEqual(blueprint);
    });

    describe('notes', () => {
        it('should create and list notes for a user, most recently updated first', async () => {
            const userId = 'notes_user_1';
            await createNote('note_a', userId, 'Comprar leche');
            await createNote('note_b', userId, 'Llamar al dentista');

            const notes = await getNotes(userId);
            expect(notes).toHaveLength(2);
            expect(notes.map((n) => n.id)).toEqual(['note_b', 'note_a']);
            expect(notes[0].text).toBe('Llamar al dentista');
        });

        it('should not leak notes between accounts', async () => {
            await createNote('note_c', 'notes_user_2', 'Nota de otra cuenta');
            const notesForUser1 = await getNotes('notes_user_1');
            expect(notesForUser1.find((n) => n.id === 'note_c')).toBeUndefined();
        });

        it('should update a note only when it belongs to the requesting user', async () => {
            await updateNote('note_a', 'notes_user_1', 'Comprar leche y pan');
            const notes = await getNotes('notes_user_1');
            expect(notes.find((n) => n.id === 'note_a')?.text).toBe('Comprar leche y pan');

            // Un intento de editar la nota de otra cuenta no debe tocar nada.
            await updateNote('note_c', 'notes_user_1', 'intento ajeno');
            const otherUsersNotes = await getNotes('notes_user_2');
            expect(otherUsersNotes.find((n) => n.id === 'note_c')?.text).toBe('Nota de otra cuenta');
        });

        it('should delete a note', async () => {
            await deleteNote('note_a', 'notes_user_1');
            const notes = await getNotes('notes_user_1');
            expect(notes.find((n) => n.id === 'note_a')).toBeUndefined();
        });

        it('should delete all notes when the account is deleted', async () => {
            const userId = 'notes_user_delete_me';
            await createNote('note_d', userId, 'Nota que debe desaparecer');
            await deleteUserAccount(userId);
            const notes = await getNotes(userId);
            expect(notes).toHaveLength(0);
        });
    });
});
