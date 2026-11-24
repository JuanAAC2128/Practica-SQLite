import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/tareas_repository.dart';
import 'screens/tareas_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestorTareasApp());
}

/// Punto de entrada de la aplicación.
///
/// Si no se recibe [baseDatos], abre la base SQLite persistente de la
/// plataforma actual. Las pruebas inyectan una base en memoria.
class GestorTareasApp extends StatefulWidget {
  const GestorTareasApp({super.key, this.baseDatos});

  final AppDatabase? baseDatos;

  @override
  State<GestorTareasApp> createState() => _GestorTareasAppState();
}

class _GestorTareasAppState extends State<GestorTareasApp> {
  late final AppDatabase _db;
  late final TareasRepository _repositorio;
  late final bool _esPropia;

  @override
  void initState() {
    super.initState();
    _esPropia = widget.baseDatos == null;
    _db = widget.baseDatos ?? AppDatabase.defaults();
    _repositorio = TareasRepository(_db);
  }

  @override
  void dispose() {
    // Libera la conexión solo si esta app la creó.
    if (_esPropia) {
      _db.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de tareas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TareasPage(repositorio: _repositorio),
    );
  }
}
