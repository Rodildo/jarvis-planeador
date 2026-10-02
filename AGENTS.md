# Reglas de Compilación
- **NUNCA** compilar proyectos en segundo plano (ej. no ejecutar `flutter build apk` ni similares sin confirmación o mediante tareas en segundo plano que el usuario no pueda ver directamente).
- Dejar que el usuario realice las compilaciones desde la interfaz (ej. Android Studio) o pedir permiso explícito antes de cualquier construcción pesada.

# Reglas de flujo de trabajo (backend/frontend)
Ver [PROYECTO.md](PROYECTO.md) para la guía completa (links del repo, del APK, y el resumen de últimas actualizaciones). Resumen operativo:
- **Cambios en `backend/`**: verificar (`tsc --noEmit` + `jest`), y si pasa, hacer `git commit` + `git push origin main` automáticamente al terminar, sin que el usuario tenga que pedirlo. Después, desplegar con `bash backend/deploy_vps.sh` (sube el código al VPS de Hostinger y reinicia el contenedor; EasyPanel ya no existe desde el 2026-10-02).
- **Cambios en `frontend/`**: verificar (`flutter analyze` + `flutter test`). No hace falta push automático, pero sí recordarle al usuario que recompile el APK desde Android Studio para poder probar el cambio.
- **Actualizar el APK publicado** ("actualiza el apk en la web/GitHub"): nunca compilar nada — tomar el `.apk` que el usuario ya compiló (normalmente en `frontend/build/app/outputs/flutter-apk/app-release.apk`) y subirlo como asset al release de GitHub, reemplazando el existente con el mismo nombre exacto (`jarvis-planeador.apk`), para que el link de descarga (`releases/latest/download/jarvis-planeador.apk`) siga funcionando sin tocar nada más.
