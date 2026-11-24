import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Código generado por drift_dev al ejecutar:
//   dart run build_runner build --delete-conflicting-outputs
part 'app_database.g.dart';

/// Tabla `tareas` en SQLite.
///
/// Esquema resultante (aprox.):
/// ```sql
/// CREATE TABLE tareas (
///   id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
///   titulo      TEXT    NOT NULL CHECK(length(titulo) BETWEEN 1 AND 200),
///   completada  INTEGER NOT NULL DEFAULT 0 CHECK (completada IN (0, 1)),
///   creada_en   INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
/// );
/// ```
/// SQLite no tiene tipo booleano: drift guarda `completada` como 0/1.
@DataClassName('TareaFila')
class Tareas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text().withLength(min: 1, max: 200)();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
  DateTimeColumn get creadaEn => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Tareas])
class AppDatabase extends _$AppDatabase {
  /// Permite inyectar otro ejecutor (por ejemplo, una base en memoria o un
  /// archivo temporal en las pruebas).
  AppDatabase(super.e);

  /// Base persistente real de la aplicación.
  AppDatabase.defaults() : super(_abrirConexion());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _abrirConexion() {
    return driftDatabase(
      name: 'gestor_tareas',
      // Android, iOS, Windows, Linux y macOS: archivo gestor_tareas.sqlite en
      // la carpeta de soporte de la aplicación.
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      // Web: sqlite3 compilado a WebAssembly + worker de drift, ambos en web/.
      // Los datos se guardan en OPFS o IndexedDB según el navegador.
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (resultado) {
          debugPrint(
            'Drift web: implementación ${resultado.chosenImplementation}; '
            'funciones faltantes: ${resultado.missingFeatures}',
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- Consultas

  /// SELECT reactivo: emite una nueva lista cada vez que cambia la tabla.
  Stream<List<TareaFila>> observarTareas() {
    return (select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  /// SELECT puntual.
  Future<List<TareaFila>> obtenerTareas() {
    return (select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  /// INSERT. Devuelve el id generado por SQLite.
  Future<int> insertarTarea(String titulo) {
    return into(tareas).insert(TareasCompanion.insert(titulo: titulo));
  }

  /// UPDATE del título. Devuelve el número de filas modificadas.
  Future<int> actualizarTitulo(int id, String titulo) {
    return (update(tareas)..where((t) => t.id.equals(id)))
        .write(TareasCompanion(titulo: Value(titulo)));
  }

  /// UPDATE del estado. Devuelve el número de filas modificadas.
  Future<int> actualizarCompletada(int id, bool completada) {
    return (update(tareas)..where((t) => t.id.equals(id)))
        .write(TareasCompanion(completada: Value(completada)));
  }

  /// DELETE por identificador. Devuelve el número de filas eliminadas.
  Future<int> eliminarTarea(int id) {
    return (delete(tareas)..where((t) => t.id.equals(id))).go();
  }
}
