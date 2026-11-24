import '../models/tarea.dart';
import 'app_database.dart';

/// Título vacío, solo espacios o demasiado largo.
class TituloInvalidoException implements Exception {
  const TituloInvalidoException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Error al leer o escribir en SQLite (o tarea inexistente).
class AlmacenamientoException implements Exception {
  const AlmacenamientoException(this.mensaje, [this.causa]);
  final String mensaje;
  final Object? causa;

  @override
  String toString() => mensaje;
}

/// Capa entre la interfaz y la base de datos: valida entradas, convierte las
/// filas de drift al modelo [Tarea] y traduce errores a mensajes comprensibles.
class TareasRepository {
  TareasRepository(this._db);

  final AppDatabase _db;

  static const int longitudMaxima = 200;

  /// Devuelve el título sin espacios sobrantes o lanza
  /// [TituloInvalidoException].
  static String validarTitulo(String? titulo) {
    final limpio = (titulo ?? '').trim();
    if (limpio.isEmpty) {
      throw const TituloInvalidoException('El título no puede estar vacío.');
    }
    if (limpio.length > longitudMaxima) {
      throw const TituloInvalidoException(
        'El título no puede superar $longitudMaxima caracteres.',
      );
    }
    return limpio;
  }

  /// Lista reactiva de tareas (se actualiza sola tras cada escritura).
  Stream<List<Tarea>> observarTareas() {
    return _db.observarTareas().map((filas) => filas.map(_aModelo).toList());
  }

  Future<List<Tarea>> obtenerTareas() {
    return _ejecutar('consultar las tareas', () async {
      final filas = await _db.obtenerTareas();
      return filas.map(_aModelo).toList();
    });
  }

  /// Guarda una tarea nueva y devuelve su id.
  Future<int> agregar(String titulo) async {
    final limpio = validarTitulo(titulo);
    return _ejecutar('guardar la tarea', () => _db.insertarTarea(limpio));
  }

  Future<void> editarTitulo(int id, String nuevoTitulo) async {
    final limpio = validarTitulo(nuevoTitulo);
    return _ejecutar('editar la tarea', () async {
      final filas = await _db.actualizarTitulo(id, limpio);
      _comprobarExiste(filas, id);
    });
  }

  Future<void> cambiarEstado(int id, bool completada) {
    return _ejecutar('actualizar el estado', () async {
      final filas = await _db.actualizarCompletada(id, completada);
      _comprobarExiste(filas, id);
    });
  }

  Future<void> eliminar(int id) {
    return _ejecutar('eliminar la tarea', () async {
      final filas = await _db.eliminarTarea(id);
      _comprobarExiste(filas, id);
    });
  }

  void _comprobarExiste(int filasAfectadas, int id) {
    if (filasAfectadas == 0) {
      throw AlmacenamientoException('La tarea con ID $id ya no existe.');
    }
  }

  Future<T> _ejecutar<T>(String accion, Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on TituloInvalidoException {
      rethrow;
    } on AlmacenamientoException {
      rethrow;
    } catch (e) {
      throw AlmacenamientoException('No se pudo $accion. Detalle: $e', e);
    }
  }

  static Tarea _aModelo(TareaFila fila) {
    return Tarea(id: fila.id, titulo: fila.titulo, completada: fila.completada);
  }
}
