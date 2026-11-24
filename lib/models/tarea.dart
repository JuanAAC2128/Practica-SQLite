/// Modelo de tarea usado por la interfaz.
///
/// Se persiste en la tabla `tareas` (ver `lib/data/app_database.dart`):
/// - `id`: INTEGER PRIMARY KEY AUTOINCREMENT, lo asigna SQLite.
/// - `titulo`: TEXT NOT NULL.
/// - `completada`: INTEGER 0/1 (SQLite no tiene tipo booleano nativo).
class Tarea {
  final int id;
  final String titulo;
  final bool completada;

  const Tarea({
    required this.id,
    required this.titulo,
    required this.completada,
  });

  @override
  bool operator ==(Object other) =>
      other is Tarea &&
      other.id == id &&
      other.titulo == titulo &&
      other.completada == completada;

  @override
  int get hashCode => Object.hash(id, titulo, completada);

  @override
  String toString() => 'Tarea($id, $titulo, completada: $completada)';
}
