import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';
import 'package:gestor_tareas_local/models/tarea.dart';

AppDatabase _baseEnMemoria() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  setUpAll(() {
    // En las pruebas de persistencia se abren varias instancias a propósito.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Validación de títulos (P5)', () {
    test('rechaza títulos vacíos o solo con espacios', () {
      for (final titulo in ['', '   ', '\t\n', null]) {
        expect(
          () => TareasRepository.validarTitulo(titulo),
          throwsA(isA<TituloInvalidoException>()),
          reason: 'Debería rechazar ${titulo == null ? 'null' : '"$titulo"'}',
        );
      }
    });

    test('recorta espacios y acepta títulos válidos', () {
      expect(TareasRepository.validarTitulo('  Estudiar  '), 'Estudiar');
    });

    test('rechaza títulos demasiado largos', () {
      expect(
        () => TareasRepository.validarTitulo('a' * 201),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect(TareasRepository.validarTitulo('a' * 200), hasLength(200));
    });
  });

  group('Operaciones CRUD en SQLite', () {
    late AppDatabase db;
    late TareasRepository repo;

    setUp(() {
      db = _baseEnMemoria();
      repo = TareasRepository(db);
    });

    tearDown(() => db.close());

    test('un título vacío no se registra en la base', () async {
      await expectLater(
        repo.agregar('   '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect(await repo.obtenerTareas(), isEmpty);
    });

    test('agregar, editar, cambiar estado y eliminar', () async {
      final id1 = await repo.agregar('Comprar leche');
      final id2 = await repo.agregar('  Hacer la práctica ');
      expect(id2, greaterThan(id1));

      expect(await repo.obtenerTareas(), [
        Tarea(id: id1, titulo: 'Comprar leche', completada: false),
        Tarea(id: id2, titulo: 'Hacer la práctica', completada: false),
      ]);

      await repo.editarTitulo(id1, 'Comprar pan');
      await repo.cambiarEstado(id2, true);
      expect(await repo.obtenerTareas(), [
        Tarea(id: id1, titulo: 'Comprar pan', completada: false),
        Tarea(id: id2, titulo: 'Hacer la práctica', completada: true),
      ]);

      await repo.eliminar(id1);
      final restantes = await repo.obtenerTareas();
      expect(restantes.map((t) => t.id), [id2]);
    });

    test('operar sobre un id inexistente produce un error comprensible',
        () async {
      await expectLater(
        repo.eliminar(999),
        throwsA(isA<AlmacenamientoException>()),
      );
      await expectLater(
        repo.cambiarEstado(999, true),
        throwsA(isA<AlmacenamientoException>()),
      );
    });

    test('el Stream emite la lista actualizada tras cada escritura', () async {
      final titulos = repo
          .observarTareas()
          .map((tareas) => tareas.map((t) => t.titulo).toList())
          .asBroadcastStream();

      // Primera emisión: la tabla está vacía.
      expect(await titulos.first, isEmpty);

      // Tras el INSERT el Stream vuelve a emitir sin consultar manualmente.
      final siguiente = titulos.firstWhere((lista) => lista.isNotEmpty);
      await repo.agregar('Uno');
      expect(await siguiente, ['Uno']);
    });
  });

  group('Persistencia en archivo (simula cerrar y abrir la app, P1-P4)', () {
    late Directory carpeta;
    late File archivo;

    setUp(() {
      carpeta = Directory.systemTemp.createTempSync('gestor_tareas_test_');
      archivo = File('${carpeta.path}${Platform.pathSeparator}tareas.sqlite');
    });

    tearDown(() {
      if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
    });

    test('los cambios sobreviven al cierre y reapertura de la base', () async {
      // Primera "ejecución": tres tareas, una completada, una editada y una
      // eliminada.
      var db = AppDatabase(NativeDatabase(archivo));
      var repo = TareasRepository(db);
      final a = await repo.agregar('Tarea A');
      final b = await repo.agregar('Tarea B');
      final c = await repo.agregar('Tarea C');
      await db.close();

      // Segunda "ejecución": P1 siguen las tres.
      db = AppDatabase(NativeDatabase(archivo));
      repo = TareasRepository(db);
      expect((await repo.obtenerTareas()).length, 3);
      await repo.cambiarEstado(a, true); // P2
      await repo.editarTitulo(b, 'Tarea B editada'); // P3
      await repo.eliminar(c); // P4
      await db.close();

      // Tercera "ejecución": se conservan estado, título y eliminación.
      db = AppDatabase(NativeDatabase(archivo));
      repo = TareasRepository(db);
      expect(await repo.obtenerTareas(), [
        Tarea(id: a, titulo: 'Tarea A', completada: true),
        Tarea(id: b, titulo: 'Tarea B editada', completada: false),
      ]);
      await db.close();
    });
  });
}
