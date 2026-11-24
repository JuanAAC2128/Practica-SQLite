import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea.dart';

/// Pantalla principal: alta, consulta, edición, cambio de estado y eliminación.
///
/// La lista se alimenta de un Stream de drift creado una sola vez en
/// initState(); build() nunca consulta la base de datos.
class TareasPage extends StatefulWidget {
  const TareasPage({super.key, required this.repositorio});

  final TareasRepository repositorio;

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _tituloController = TextEditingController();

  late final Stream<List<Tarea>> _tareas;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tareas = widget.repositorio.observarTareas();
  }

  Future<void> _agregarTarea() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await widget.repositorio.agregar(_tituloController.text);
      _tituloController.clear();
    } on TituloInvalidoException catch (e) {
      _mostrarMensaje(e.mensaje);
    } on AlmacenamientoException catch (e) {
      _mostrarMensaje(e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _alternarCompletada(Tarea tarea, bool completada) async {
    try {
      await widget.repositorio.cambiarEstado(tarea.id, completada);
    } on AlmacenamientoException catch (e) {
      _mostrarMensaje(e.mensaje);
    }
  }

  Future<void> _editarTarea(Tarea tarea) async {
    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoEditar(tituloInicial: tarea.titulo),
    );
    if (nuevoTitulo == null || nuevoTitulo == tarea.titulo) return;
    try {
      await widget.repositorio.editarTitulo(tarea.id, nuevoTitulo);
    } on TituloInvalidoException catch (e) {
      _mostrarMensaje(e.mensaje);
    } on AlmacenamientoException catch (e) {
      _mostrarMensaje(e.mensaje);
    }
  }

  Future<void> _eliminarTarea(Tarea tarea) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Eliminar "${tarea.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await widget.repositorio.eliminar(tarea.id);
    } on AlmacenamientoException catch (e) {
      _mostrarMensaje(e.mensaje);
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de tareas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              maxLength: TareasRepository.longitudMaxima,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_agregarTarea()),
              decoration: const InputDecoration(
                labelText: 'Nueva tarea',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _guardando ? null : _agregarTarea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarea'),
            ),
            const SizedBox(height: 12),
            const Text('Mis tareas', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Tarea>>(
                stream: _tareas,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'No se pudo leer la base de datos:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final tareas = snapshot.data!;
                  if (tareas.isEmpty) {
                    return const Center(
                      child: Text('Todavía no hay tareas guardadas'),
                    );
                  }
                  return ListView.builder(
                    itemCount: tareas.length,
                    itemBuilder: (context, index) =>
                        _filaTarea(tareas[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaTarea(Tarea tarea) {
    return Card(
      key: ValueKey('tarea-${tarea.id}'),
      child: ListTile(
        leading: Checkbox(
          value: tarea.completada,
          onChanged: (valor) {
            if (valor != null) _alternarCompletada(tarea, valor);
          },
        ),
        title: Text(
          tarea.titulo,
          style: tarea.completada
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Text(
          'ID: ${tarea.id} · ${tarea.completada ? 'Completada' : 'Pendiente'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () => _editarTarea(tarea),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _eliminarTarea(tarea),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para editar el título; valida antes de cerrar.
class _DialogoEditar extends StatefulWidget {
  const _DialogoEditar({required this.tituloInicial});

  final String tituloInicial;

  @override
  State<_DialogoEditar> createState() => _DialogoEditarState();
}

class _DialogoEditarState extends State<_DialogoEditar> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.tituloInicial);
  String? _error;

  void _guardar() {
    try {
      Navigator.pop(context, TareasRepository.validarTitulo(_controller.text));
    } on TituloInvalidoException catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar título'),
      content: TextField(
        key: const Key('campo-editar'),
        controller: _controller,
        autofocus: true,
        maxLength: TareasRepository.longitudMaxima,
        onSubmitted: (_) => _guardar(),
        decoration: InputDecoration(
          labelText: 'Título',
          errorText: _error,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
