# Gestor de tareas local (Flutter + SQLite con Drift)

Aplicación Flutter que administra tareas en una base **SQLite local**, sin servidor ni conexión a internet. Una sola base de código para Android, iOS, Windows, Linux, macOS y web.

Funciones: agregar (rechaza títulos vacíos o solo con espacios), listar, editar el título, marcar como completada o pendiente y eliminar. Todo se guarda en SQLite y se conserva al cerrar y volver a abrir la app.

## Tecnología de persistencia elegida

| Paquete | Para qué |
|---|---|
| [`drift`](https://pub.dev/packages/drift) | Capa tipada sobre SQLite: tablas en Dart, consultas `select/insert/update/delete` y consultas reactivas (`watch()` → `Stream`). |
| [`drift_flutter`](https://pub.dev/packages/drift_flutter) | `driftDatabase()` abre la base correcta por plataforma: archivo `.sqlite` en nativo, SQLite compilado a WebAssembly en web. |
| [`path_provider`](https://pub.dev/packages/path_provider) | Carpeta de soporte de la app donde vive el archivo en nativo. |
| `drift_dev` + `build_runner` (dev) | Generan `lib/data/app_database.g.dart` (clases de fila, *companions* y metadatos de la tabla). |

Se descartó `sqflite` porque no funciona en web ni en escritorio sin paquetes extra. Drift + drift_flutter cubre las seis plataformas con el mismo código.

## Diseño de la tabla

```sql
CREATE TABLE tareas (
  id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, -- identificador único
  titulo     TEXT    NOT NULL,                           -- 1 a 200 caracteres
  completada INTEGER NOT NULL DEFAULT 0,                 -- booleano 0/1
  creada_en  INTEGER NOT NULL                            -- fecha de alta
);
```

Cada registro se identifica con `id`, que asigna SQLite (autoincremental). Editar, cambiar estado y eliminar usan `WHERE id = ?`.

## Estructura

```
lib/
  main.dart                    # Crea/cierra la base y arranca la app
  models/tarea.dart            # Modelo usado por la interfaz
  data/app_database.dart       # Tabla Tareas + AppDatabase (drift) + consultas CRUD
  data/app_database.g.dart     # Generado por build_runner (se versiona)
  data/tareas_repository.dart  # Validación, conversión fila→modelo y manejo de errores
  screens/tareas_page.dart     # UI: StreamBuilder sobre la consulta reactiva
test/
  widget_test.dart             # Pruebas de interfaz con SQLite en memoria
  tareas_repository_test.dart  # Validación, CRUD, Stream y persistencia en archivo
web/
  sqlite3.wasm                 # SQLite para el navegador (drift 2.35.4)
  drift_worker.js              # Worker de drift (drift 2.35.4)
```

Decisiones:

- **Actualización de la UI con `Stream`**: `observarTareas()` usa `watch()`. Tras cada INSERT/UPDATE/DELETE drift vuelve a emitir la lista, así que no hace falta recargar a mano. El `Stream` se crea una sola vez en `initState()`, nunca dentro de `build()`.
- **Errores**: el repositorio lanza `TituloInvalidoException` (entrada inválida) o `AlmacenamientoException` (fallo de SQLite o id inexistente). La pantalla los muestra en un `SnackBar`.
- **Recursos**: `GestorTareasApp` cierra la conexión (`close()`) en `dispose()` si fue quien la abrió; los `TextEditingController` también se liberan.

## Dónde se guardan los datos

- **Android / iOS / Windows / Linux / macOS**: archivo `gestor_tareas.sqlite` en `getApplicationSupportDirectory()`. Por ejemplo, en Windows: `%APPDATA%\mx.edu.uaa\gestor_tareas_local\`. En Android: el almacenamiento privado de la app, que se borra al desinstalarla.
- **Web**: SQLite en WebAssembly. Los datos se guardan en OPFS o en IndexedDB, según lo que soporte el navegador, y quedan ligados al **origen** (`http://localhost:PUERTO`) y al **perfil** del navegador. En modo incógnito o tras "borrar datos del sitio" se pierden. Si el puerto cambia, el origen es otro y la base aparece vacía.

## Cómo ejecutar

Requisitos: Flutter estable con **Dart 3.10 o superior** (Flutter 3.38+), porque drift 2.35 lo exige. Compruébalo con `flutter --version`.

### Opción rápida (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File .\configurar.ps1
```

### Manual (cualquier sistema)

```bash
flutter create --project-name gestor_tareas_local --org mx.edu.uaa .   # solo si faltan android/, web/, etc.
flutter pub get
dart run build_runner build --delete-conflicting-outputs              # regenera app_database.g.dart
flutter analyze
flutter test
flutter run -d windows        # o: -d chrome, -d <id de flutter devices>
```

Para web conviene fijar el puerto, así el origen no cambia y los datos persisten entre ejecuciones:

```bash
flutter run -d chrome --web-port 8080
```

### Recursos web (`sqlite3.wasm` y `drift_worker.js`)

Vienen de la release de drift que coincide con la versión de `pubspec.lock`:
`https://github.com/simolus3/drift/releases/download/drift-<versión>/sqlite3.wasm` y `.../drift_worker.js`. Van en `web/` y se referencian en `DriftWebOptions` (`lib/data/app_database.dart`). `configurar.ps1` los vuelve a descargar si la versión instalada de drift es distinta de la incluida (2.35.4).

> Nota: el README de la base menciona `drift_worker.dart.js`, pero las releases actuales de drift publican el archivo como `drift_worker.js`. El nombre solo tiene que coincidir con el `Uri` de `DriftWebOptions`.

## Pruebas automatizadas

`flutter test` ejecuta:

| Archivo | Qué cubre |
|---|---|
| `tareas_repository_test.dart` | Validación de títulos (vacío, solo espacios, >200 caracteres, recorte); un título vacío no se inserta (P5); CRUD completo; error comprensible con id inexistente; el `Stream` reemite tras un INSERT; **persistencia real en un archivo `.sqlite`**: se cierra y se reabre la base tres veces y se comprueban P1–P4. |
| `widget_test.dart` | Pantalla inicial; agregar desde la UI guarda en SQLite; título vacío muestra aviso y no se registra; marcar completada y eliminar (con confirmación) desde la UI. |

Las pruebas usan `NativeDatabase` (SQLite real) en memoria o en un archivo temporal, no listas simuladas.

## Comprobación manual P1–P6

> Completar con los resultados obtenidos en cada plataforma.

| ID | Acción | Esperado | Windows | Web (Chrome) |
|---|---|---|---|---|
| P1 | Agregar tres tareas, cerrar la app por completo y abrirla | Permanecen las tres | ☐ | ☐ |
| P2 | Marcar una como completada y reiniciar | Se conserva el estado | ☐ | ☐ |
| P3 | Cambiar el título y reiniciar | Aparece el nuevo título | ☐ | ☐ |
| P4 | Eliminar una tarea y reiniciar | No reaparece | ☐ | ☐ |
| P5 | Intentar agregar título vacío | No se registra | ☐ | ☐ |
| P6 | Web: recargar y cerrar/abrir la pestaña (mismo origen y perfil) | Los datos permanecen | — | ☐ |

Hot reload/hot restart **no** comprueban la persistencia, porque el proceso sigue vivo. Hay que cerrar la app (o detener `flutter run`) y volver a lanzarla. Desinstalar borra los datos.

### Plataformas

| Plataforma | Estado |
|---|---|
| Windows | Por verificar |
| Web (Chrome) | Por verificar |
| Android | Prevista (mismo código; verificar si hay emulador/dispositivo) |
| Linux | Prevista (compilar desde Linux) |
| iOS / macOS | Previstas (requieren Mac con Xcode) |

## Referencias

- Drift: https://drift.simonbinder.eu/
- Drift en web: https://drift.simonbinder.eu/platforms/web/
- drift_flutter: https://pub.dev/packages/drift_flutter
- Flutter, persistencia con SQLite: https://docs.flutter.dev/cookbook/persistence/sqlite
- Pruebas en Flutter: https://docs.flutter.dev/testing/overview
