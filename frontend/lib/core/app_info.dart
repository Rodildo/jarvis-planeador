/// Build number de esta compilación. Debe subirse a mano junto con el
/// "+N" del campo `version` en pubspec.yaml en cada release.
///
/// Se compara contra `minBuildNumber` que devuelve GET /version del
/// backend (ver docs/reference/06-decisions.md) para decidir si esta
/// versión instalada ya quedó obsoleta y hay que bloquear el uso pidiendo
/// actualizar. Subir minBuildNumber en el backend sin subir este valor en
/// una nueva build es lo que "fuerza" la actualización.
const int kAppBuildNumber = 1;

/// Link estable de descarga: siempre resuelve al asset del release más
/// reciente en GitHub (ver PROYECTO.md).
const String kApkDownloadUrl = 'https://github.com/Rodildo/jarvis-planeador/releases/latest/download/jarvis-planeador.apk';
