"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const database_1 = require("./src/db/database");
async function run() {
    await (0, database_1.initDB)();
    const mockBlueprint = {
        routine: {
            morning: ["Revisión suave", "Desayuno ligero sin prisas"],
            evening: ["Apagar pantallas a las 9pm", "Meditar para bajar la actividad"]
        },
        goals: ["Proteger el ciclo de sueño", "Mantener estabilidad emocional (bipolaridad)"]
    };
    await (0, database_1.saveBlueprint)('default_user', JSON.stringify(mockBlueprint));
    console.log('Usuario default creado exitosamente.');
    process.exit(0);
}
run();
//# sourceMappingURL=seed.js.map