import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/browser_url.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/maia_theme_helpers.dart';
import '../../models/models.dart';

const _maxSheets = 5;

class ConnectorsPanel extends ConsumerStatefulWidget {
  const ConnectorsPanel({
    required this.projectId,
    required this.isAdmin,
    super.key,
  });

  final String projectId;
  final bool isAdmin;

  @override
  ConsumerState<ConnectorsPanel> createState() => _ConnectorsPanelState();
}

class _ConnectorsPanelState extends ConsumerState<ConnectorsPanel> {
  final _sheetIdController = TextEditingController();
  final _labelController = TextEditingController();
  final _hintController = TextEditingController();

  List<ProjectSheet> _sheets = const <ProjectSheet>[];
  bool? _connected;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant ConnectorsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      setState(() {
        _sheets = const <ProjectSheet>[];
        _connected = null;
        _loading = true;
        _error = null;
      });
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _sheetIdController.dispose();
    _labelController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait<Object?>([
        ref.read(projectServiceProvider).listSheets(widget.projectId),
        ref.read(authServiceProvider).googleSheetsStatus(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _sheets = results[0] as List<ProjectSheet>;
        _connected = (results[1] as GoogleSheetsStatus?)?.connected ?? false;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ref.read(authServiceProvider).connectGoogleSheetsUrl();
      if (url.isEmpty) {
        throw const ApiException(null, 'Google Sheets connect URL missing.');
      }
      navigateBrowserTo(url);
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Sheets?'),
        content: const Text(
          'Maia will lose access to attached sheets until an admin reconnects.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).disconnectGoogleSheets();
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _attach() async {
    final sheetId = _sheetIdController.text.trim();
    final hint = _hintController.text.trim();
    final label = _labelController.text.trim();
    if (sheetId.isEmpty) {
      setState(() => _error = 'Google Sheet ID is required.');
      return;
    }
    if (hint.isEmpty) {
      setState(() => _error = 'Add a schema hint before attaching.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(projectServiceProvider)
          .attachSheet(
            widget.projectId,
            googleSheetId: sheetId,
            label: label.isEmpty ? 'Google Sheet' : label,
            schemaHint: hint,
          );
      _sheetIdController.clear();
      _labelController.clear();
      _hintController.clear();
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _detach(ProjectSheet sheet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detach sheet?'),
        content: Text('Maia will stop reading "${sheet.label}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Detach'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(projectServiceProvider)
          .detachSheet(widget.projectId, sheet.id);
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    if (!widget.isAdmin && _loading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!widget.isAdmin && _sheets.isEmpty) {
      return Text(
        'No Google Sheets attached.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.faint),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Google Sheets · ${_sheets.length}/$_maxSheets',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_sheets.isEmpty)
          _EmptyConnectorState(isAdmin: widget.isAdmin)
        else
          ..._sheets.map(
            (sheet) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SheetTile(
                sheet: sheet,
                canDetach: widget.isAdmin,
                busy: _busy,
                onDetach: () => _detach(sheet),
              ),
            ),
          ),
        if (widget.isAdmin) ...[
          const SizedBox(height: 8),
          if (_connected == false)
            FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Connect Google Sheets'),
            )
          else ...[
            _AttachSheetForm(
              sheetIdController: _sheetIdController,
              labelController: _labelController,
              hintController: _hintController,
              enabled: !_busy && _sheets.length < _maxSheets,
              onAttach: _attach,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
                TextButton(
                  onPressed: _busy ? null : _disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.danger),
          ),
        ],
      ],
    );
  }
}

class _AttachSheetForm extends StatelessWidget {
  const _AttachSheetForm({
    required this.sheetIdController,
    required this.labelController,
    required this.hintController,
    required this.enabled,
    required this.onAttach,
  });

  final TextEditingController sheetIdController;
  final TextEditingController labelController;
  final TextEditingController hintController;
  final bool enabled;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: sheetIdController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Google Sheet ID',
            hintText: '1abc... from the sheet URL',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: labelController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'Launch tracker',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: hintController,
          enabled: enabled,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Schema hint',
            hintText: 'Owner | Task | Status | Due',
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: enabled ? onAttach : null,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Attach sheet'),
          ),
        ),
      ],
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.sheet,
    required this.canDetach,
    required this.busy,
    required this.onDetach,
  });

  final ProjectSheet sheet;
  final bool canDetach;
  final bool busy;
  final VoidCallback onDetach;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.table_chart_outlined, color: tokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheet.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sheet.schemaHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.dim),
                ),
              ],
            ),
          ),
          if (canDetach)
            IconButton(
              tooltip: 'Detach',
              onPressed: busy ? null : onDetach,
              icon: const Icon(Icons.link_off_rounded),
            ),
        ],
      ),
    );
  }
}

class _EmptyConnectorState extends StatelessWidget {
  const _EmptyConnectorState({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        isAdmin
            ? 'Connect Google Sheets, then attach individual sheets Maia can read.'
            : 'No Google Sheets attached.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.dim, height: 1.35),
      ),
    );
  }
}

String _messageFor(Object error) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Request failed.';
}
