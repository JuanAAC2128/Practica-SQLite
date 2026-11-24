import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';
import 'package:gestor_tareas_local/main.dart';

/// Base SQLite en memoria: misma tabla y consultas que la app, sin tocar
/// el disco del equipo que ejecuta las pruebas.
AppDatabase _baseEnMemoria() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

/// Deja que drift termine sus futuros y el Stream reconstruya la lista.
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;

  setUp(() => db = _baseEnMemoria());
  tearDown(() => db.close());

  Future<void> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(GestorTareasApp(baseDatos: db));
    await _asentar(tester);
  }

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await abrirApp(tester);
    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
  });

  testWidgets('Agregar una tarea desde la interfaz la guarda en SQLite',
      (tester) async {
    await abrirApp(tester);

    await tester.enterText(find.byType(TextField), 'Estudiar Drift');
    await tester.tap(find.text('Agregar tarea'));
    await _asentar(tester);

    expect(find.text('Estudiar Drift'), findsOneWidget);
    final guardadas = await TareasRepository(db).obtenerTareas();
    expect(guardadas.single.titulo, 'Estudiar Drift');
  });

  testWidgets('Un título vacío muestra un aviso y no se registra (P5)',
      (tester) async {
    await abrirApp(tester);

    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(find.text('Agregar tarea'));
    await _asentar(tester);

    expect(find.text('El título no puede estar vacío.'), findsOneWidget);
    expect(await TareasRepository(db).obtenerTareas(), isEmpty);
  });

  testWidgets('Marcar como completada y eliminar desde la interfaz',
      (tester) async {
    final repo = TareasRepository(db);
    final id = await repo.agregar('Entregar práctica');
    await abrirApp(tester);

    await tester.tap(find.byType(Checkbox));
    await _asentar(tester);
    expect((await repo.obtenerTareas()).single.completada, isTrue);
    expect(find.textContaining('Completada'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar'));
    await _asentar(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await _asentar(tester);

    expect(find.byKey(ValueKey('tarea-$id')), findsNothing);
    expect(await repo.obtenerTareas(), isEmpty);
  });
}
