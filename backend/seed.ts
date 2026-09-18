import { initDB, saveBlueprint } from './src/db/database';

async function run() {
  await initDB();
  const mockBlueprint = {
    routine: {
      morning: ["Revisión suave", "Desayuno ligero sin prisas"],
      evening: ["Apagar pantallas a las 9pm", "Meditar para bajar la actividad"]
    },
    goals: ["Proteger el ciclo de sueño", "Mantener estabilidad emocional (bipolaridad)"]
  };
  await saveBlueprint('default_user', JSON.stringify(mockBlueprint));
  console.log('Usuario default creado exitosamente.');
  process.exit(0);
}

run();
