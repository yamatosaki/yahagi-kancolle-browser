import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../fleet/game_mod_portraits.dart';
import 'game_mods_library.dart';
import 'game_mods_models.dart';
import 'game_mods_port.dart';

/// Owns persisted choices separately from the current game's resource telemetry.
class GameModsController extends ChangeNotifier with WidgetsBindingObserver {
  GameModsController({GameModsPort? port, GameModPortraitController? portraits})
    : _port = port ?? const MethodChannelGameModsPort(),
      portraits = portraits ?? GameModPortraitController(),
      _ownsPortraits = portraits == null {
    this.portraits.addListener(_notify);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _progressForeground = _resumed || lifecycle == AppLifecycleState.inactive;
  }
  final GameModsPort _port;
  final GameModPortraitController portraits;
  final bool _ownsPortraits;
  GameModsStatus _status = const GameModsStatus();
  GameModsStatus get status => _status;
  GameModsPreflight? preflight;
  GameModLibraryScan? libraryScan;
  bool get librarySupported => _port is GameModsLibraryPort;
  bool _archiveUpdateSupported = false;
  bool get archiveUpdateSupported =>
      supported == true && _archiveUpdateSupported;
  GameModsLibraryPort? get _libraryPort =>
      _port is GameModsLibraryPort ? _port as GameModsLibraryPort : null;
  GameModsApplyResult? lastApplyResult;
  bool? supported;
  String? errorCode;
  bool loading = false, busy = false;
  GameModsOperationProgress? operationProgress;
  final _progressClock = Stopwatch();
  int get operationElapsedMillis {
    final native = operationProgress?.elapsedMillis ?? 0;
    final local = _progressClock.elapsedMilliseconds;
    return native > local ? native : local;
  }

  Timer? _progressPoll;
  int? _progressRequestEpoch;
  String? _progressKind;
  final _retiredProgressIds = <String>{};
  bool get saving => _saves > 0;
  bool get saveFailed => _saveFailed;
  bool get canEdit => supported == true && !busy && !loading;
  bool _disposed = false,
      _visible = false,
      _resumed = true,
      _progressForeground = true,
      _refreshing = false;
  bool _saveFailed = false;
  int _revision = 0, _saves = 0, _operationEpoch = 0;
  Future<void> _saveTail = Future<void>.value();
  Future<void>? _initialization;
  Timer? _poll;

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    loading = true;
    _notify();
    final portraitInitialization = _initializePortraits();
    try {
      final capability = await _port.capabilities();
      if (_disposed) return;
      supported = capability.supported;
      _archiveUpdateSupported =
          capability.archiveUpdateSupported &&
          _port is GameModsArchiveUpdatePort;
      errorCode = capability.supported
          ? null
          : capability.reason ?? 'unsupported';
      if (supported == true) _status = await _port.status();
    } catch (error) {
      _error(error);
    } finally {
      await portraitInitialization;
      loading = false;
      _updatePolling();
      _notify();
    }
  }

  // The independent interface setting must never disable game mod management
  // when a platform does not implement the optional portrait API.
  Future<void> _initializePortraits() async {
    try {
      await portraits.initialize();
    } catch (_) {}
  }

  Future<void> _refreshPortraits() async {
    if (_disposed) return;
    try {
      await portraits.refresh();
    } catch (_) {}
  }

  void setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _updatePolling();
    _updateProgressPolling();
  }

  void setAppResumed(bool value) {
    if (_resumed == value && _progressForeground == value) return;
    _resumed = value;
    _progressForeground = value;
    _updatePolling();
    _updateProgressPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    final progressForeground = resumed || state == AppLifecycleState.inactive;
    if (_resumed != resumed) {
      _resumed = resumed;
      _updatePolling();
    }
    if (_progressForeground != progressForeground) {
      _progressForeground = progressForeground;
      _updateProgressPolling();
    }
  }

  void _updatePolling() {
    _poll?.cancel();
    _poll = null;
    if (!_disposed && _visible && _resumed && supported == true) {
      _poll = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(refresh());
      });
    }
  }

  Future<void> refresh() async {
    if (_disposed || supported != true || _refreshing || busy) return;
    _refreshing = true;
    final revision = _revision,
        epoch = _operationEpoch,
        canAcceptDraft = !saving && !_saveFailed;
    try {
      final remote = await _port.status();
      if (!_disposed &&
          epoch == _operationEpoch &&
          remote.sessionId >= _status.sessionId) {
        _status =
            revision == _revision &&
                canAcceptDraft &&
                !saving &&
                !_saveFailed &&
                !busy
            ? remote
            : _status.withRuntimeFrom(remote);
        _notify();
      }
    } catch (error) {
      if (!_disposed && epoch == _operationEpoch) {
        _error(error);
        _notify();
      }
    } finally {
      _refreshing = false;
    }
  }

  void setMaster(bool value) {
    if (canEdit) _edit(_status.draft.copyWith(master: value));
  }

  void setPackageEnabled(String id, bool value) {
    if (!canEdit ||
        !_status.packages.any((p) => p.id == id && !p.pendingRemoval)) {
      return;
    }
    final ids = {..._status.draft.enabledPackages};
    value ? ids.add(id) : ids.remove(id);
    _edit(_status.draft.copyWith(enabledPackages: ids));
  }

  void setResourceEnabled(String id, bool value) {
    if (!canEdit) return;
    final package = _status.packageForResource(id);
    if (package == null || package.pendingRemoval) return;
    final resource = package.resources.firstWhere((r) => r.id == id);
    final group = resource.groupId;
    final grouped = group == null || group.isEmpty
        ? <GameModResource>[]
        : package.resources
              .where((r) => r.groupId == group && !r.isCoordinates)
              .toList();
    final members =
        !resource.isCoordinates && grouped.any((r) => r.path.endsWith('.json'))
        ? grouped
        : [resource];
    if (members.any((r) => !r.supported)) return;
    final ids = {..._status.draft.enabledResources};
    for (final r in members) {
      value ? ids.add(r.id) : ids.remove(r.id);
    }
    _edit(_status.draft.copyWith(enabledResources: ids));
  }

  void setResourcesEnabled(Iterable<GameModResource> resources, bool value) {
    if (!canEdit) return;
    final owners = <String, GameModPackage>{};
    final groups = <(String, String), List<GameModResource>>{};
    final linked = <(String, String)>{}, unsupported = <(String, String)>{};
    for (final package in _status.packages) {
      for (final resource in package.resources) {
        owners[resource.id] = package;
        final groupId = resource.groupId;
        if (groupId == null || groupId.isEmpty || resource.isCoordinates) {
          continue;
        }
        final key = (package.id, groupId);
        groups.putIfAbsent(key, () => []).add(resource);
        if (resource.path.endsWith('.json')) {
          linked.add(key);
        }
        if (!resource.supported) unsupported.add(key);
      }
    }
    final ids = {..._status.draft.enabledResources};
    final changedGroups = <(String, String)>{};
    for (final r in resources.where((r) => r.supported)) {
      final p = owners[r.id];
      if (p == null || p.pendingRemoval) continue;
      final key = (p.id, r.groupId ?? '');
      if (!r.isCoordinates && linked.contains(key)) {
        if (unsupported.contains(key) || !changedGroups.add(key)) continue;
        for (final member in groups[key]!) {
          value ? ids.add(member.id) : ids.remove(member.id);
        }
      } else {
        value ? ids.add(r.id) : ids.remove(r.id);
      }
    }
    _edit(_status.draft.copyWith(enabledResources: ids));
  }

  void movePackage(String id, int direction) {
    if (!canEdit) return;
    final order = [..._status.draft.order];
    final index = order.indexOf(id), target = order.indexOf(id) + direction;
    if (index < 0 || target < 0 || target >= order.length) return;
    final other = order[target];
    order[target] = id;
    order[index] = other;
    _edit(_status.draft.copyWith(order: order));
  }

  void _edit(GameModsConfig config) {
    if (config.sameAs(_status.draft)) return;
    _status = _status.withDraft(config);
    _revision++;
    _saves++;
    errorCode = null;
    lastApplyResult = null;
    _notify();
    _saveTail = _saveTail.then((_) async {
      if (_disposed) return;
      try {
        await _port.saveDraft(config);
        _saveFailed = false;
        errorCode = null;
      } catch (error) {
        _saveFailed = true;
        _error(error);
      } finally {
        _saves--;
        _notify();
      }
    });
  }

  Future<void> flushDraft() => _saveTail;
  Future<void> pickArchive({String? updatePackageId}) async {
    if (!canEdit || preflight != null || libraryScan != null) return;
    if (updatePackageId != null &&
        (!archiveUpdateSupported ||
            !_status.packages.any(
              (p) => p.id == updatePackageId && !p.pendingRemoval,
            ))) {
      return;
    }
    await _run(() async {
      if (!await _ensureLibrary()) return;
      final candidate = updatePackageId == null
          ? await _port.pickAndPreflightArchive()
          : await (_port as GameModsArchiveUpdatePort).pickAndPreflightUpdate(
              updatePackageId,
            );
      if (_disposed) {
        if (candidate != null) {
          try {
            await _port.discardImport(candidate.token);
          } catch (_) {}
        }
        return;
      }
      preflight = candidate;
    }, operation: 'import');
  }

  Future<bool> _ensureLibrary() async {
    final library = _libraryPort;
    if (library == null || _status.library.available) return true;
    await flushDraft();
    if (!_saved()) return false;
    final selected = await _libraryCall(library.chooseLibraryDirectory);
    if (!selected) return false;
    _status = await _port.status();
    _revision++;
    if (!_status.library.available) {
      throw PlatformException(
        code: _status.library.error ?? 'library_unavailable',
      );
    }
    return true;
  }

  Future<bool> chooseLibraryDirectory() async {
    final library = _libraryPort;
    if (!canEdit ||
        library == null ||
        preflight != null ||
        libraryScan != null) {
      return false;
    }
    var selected = false;
    await _run(() async {
      await flushDraft();
      if (!_saved()) return;
      selected = await _libraryCall(library.chooseLibraryDirectory);
      if (!selected) return;
      _status = await _port.status();
      _revision++;
    }, operation: 'directory');
    return selected && errorCode == null && _status.library.available;
  }

  Future<void> openLibraryDirectory() async {
    final library = _libraryPort;
    if (!canEdit || library == null) return;
    await _run(() => _libraryCall(library.openLibraryDirectory));
  }

  Future<void> scanLibrary() async {
    final library = _libraryPort;
    if (!canEdit ||
        library == null ||
        preflight != null ||
        libraryScan != null) {
      return;
    }
    await _run(() async {
      if (!await _ensureLibrary()) return;
      await flushDraft();
      if (!_saved()) return;
      final candidate = await _libraryCall(library.scanLibrary);
      if (_disposed) {
        await _libraryCall(() => library.discardLibraryScan(candidate.token));
        return;
      }
      if (candidate.token.isEmpty) {
        throw PlatformException(code: 'library_scan_failed');
      }
      libraryScan = candidate;
      lastApplyResult = null;
    }, operation: 'scan');
  }

  Future<void> cancelLibraryScan() async {
    final library = _libraryPort, candidate = libraryScan;
    if (busy || library == null || candidate == null) return;
    await _run(() async {
      await _libraryCall(() => library.discardLibraryScan(candidate.token));
      libraryScan = null;
    });
  }

  Future<void> confirmLibraryScan() async {
    final library = _libraryPort, candidate = libraryScan;
    if (!canEdit ||
        library == null ||
        candidate == null ||
        !candidate.hasChanges) {
      return;
    }
    await _run(() async {
      await flushDraft();
      if (!_saved()) return;
      var committed = false;
      try {
        await _libraryCall(() => library.commitLibraryScan(candidate.token));
        committed = true;
      } finally {
        libraryScan = null;
        lastApplyResult = null;
        if (!committed) {
          // Native failures usually consume the preview. Also release it when
          // synchronization failed before native code could consume its token.
          try {
            await _libraryCall(
              () => library.discardLibraryScan(candidate.token),
            );
          } catch (_) {}
        }
        try {
          // A batch can persist part of its draft before an IO failure. Show
          // that final state while preserving the original commit error.
          _status = await _port.status();
          _revision++;
        } catch (_) {
          if (committed) rethrow;
        }
      }
    }, operation: 'import');
  }

  // A missing optional library API must not disable already working game mods.
  Future<T> _libraryCall<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MissingPluginException {
      throw PlatformException(code: 'library_unavailable');
    } on PlatformException catch (error) {
      final code = switch (error.code) {
        'invalid_token' => 'library_scan_expired',
        'storage_error' => 'library_storage_error',
        _ => error.code,
      };
      throw PlatformException(
        code: code,
        message: error.message,
        details: error.details,
      );
    }
  }

  Future<void> cancelImport() async {
    if (busy || preflight == null) return;
    await _run(() async {
      await _port.discardImport(preflight!.token);
      preflight = null;
    });
  }

  Future<void> confirmImport() async {
    final candidate = preflight;
    if (!canEdit || candidate == null || candidate.supportedCount == 0) return;
    await _run(() async {
      var committed = false;
      try {
        await flushDraft();
        if (!_saved()) return;
        await _port.commitImport(candidate.token);
        committed = true;
        lastApplyResult = null;
      } finally {
        preflight = null;
        if (!committed) {
          try {
            await _port.discardImport(candidate.token);
          } catch (_) {}
        }
      }
      _status = await _port.status();
      _revision++;
    }, operation: 'import');
  }

  Future<void> removePackage(String id) async {
    if (!canEdit) return;
    await _run(() async {
      await flushDraft();
      if (!_saved()) return;
      await _port.removePackage(id);
      _status = await _port.status();
      _revision++;
    });
  }

  Future<void> apply() async {
    if (!canEdit) return;
    await _run(_apply);
  }

  Future<void> cancelChanges() async {
    if (!canEdit || (!_status.pending && !_saveFailed)) return;
    await _run(() async {
      // Let queued writes finish before restoring the native draft. A failed
      // draft save must still allow the user to discard those local choices.
      await flushDraft();
      await _port.cancelChanges();
      _status = await _port.status();
      _revision++;
      _saveFailed = false;
      errorCode = null;
      lastApplyResult = null;
    });
  }

  Future<void> _apply() async {
    await flushDraft();
    if (!_saved()) return;
    try {
      lastApplyResult = await _port.applyAndReload();
      if (lastApplyResult == GameModsApplyResult.failed) {
        errorCode = 'apply_failed';
      }
      if (lastApplyResult == GameModsApplyResult.unsupported) {
        errorCode = 'unsupported';
      }
    } finally {
      // Failed reloads can roll native state back. Observe that final state
      // before publishing a new interface portrait snapshot.
      try {
        _status = await _port.status();
        _revision++;
      } finally {
        await _refreshPortraits();
      }
    }
  }

  Future<void> resetAll() async {
    if (!canEdit) return;
    await _run(() async {
      await flushDraft();
      if (!_saved()) return;
      await _port.resetAll();
      _status = await _port.status();
      _revision++;
      lastApplyResult = null;
    });
  }

  Future<void> retrySave() async {
    if (!canEdit) return;
    final config = _status.draft;
    errorCode = null;
    await _run(() async {
      await flushDraft();
      await _port.saveDraft(config);
      _saveFailed = false;
    });
  }

  Future<void> _run(Future<void> Function() action, {String? operation}) async {
    if (_disposed || busy) return;
    final epoch = ++_operationEpoch;
    busy = true;
    if (operation != null) _beginProgress(operation);
    errorCode = null;
    _notify();
    try {
      final task = action();
      if (operation != null) unawaited(_readProgress(epoch));
      await task;
    } catch (error) {
      _error(error);
    } finally {
      _endProgress();
      busy = false;
      _notify();
    }
  }

  void _beginProgress(String operation) {
    _progressKind = operation;
    operationProgress = GameModsOperationProgress(
      operationId: '',
      operation: operation,
      phase: operation == 'scan' ? 'discover' : 'read',
      active: true,
    );
    _progressClock.reset();
    _progressClock.start();
    _updateProgressPolling(catchUp: false);
  }

  void _updateProgressPolling({bool catchUp = true}) {
    if (_disposed ||
        !_visible ||
        !_progressForeground ||
        !busy ||
        _progressKind == null) {
      _progressPoll?.cancel();
      _progressPoll = null;
      return;
    }
    if (_progressPoll != null) return;
    final epoch = _operationEpoch;
    final poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _notify();
      unawaited(_readProgress(epoch));
    });
    _progressPoll = poll;
    if (catchUp) {
      // Visibility may change during a page build while its progress modal is
      // mounted elsewhere in the root overlay. Notify after that build ends.
      scheduleMicrotask(() {
        if (_disposed ||
            !_visible ||
            !_progressForeground ||
            !busy ||
            epoch != _operationEpoch ||
            !identical(_progressPoll, poll)) {
          return;
        }
        // Only the UI timer pauses. The task and elapsed clock keep running.
        _notify();
        unawaited(_readProgress(epoch));
      });
    }
  }

  Future<void> _readProgress(int epoch) async {
    if (_disposed ||
        !busy ||
        epoch != _operationEpoch ||
        _progressRequestEpoch == epoch ||
        _port is! GameModsProgressPort) {
      return;
    }
    _progressRequestEpoch = epoch;
    try {
      final snapshot = await (_port as GameModsProgressPort)
          .operationProgress();
      if (_disposed ||
          !busy ||
          epoch != _operationEpoch ||
          snapshot == null ||
          !snapshot.active ||
          snapshot.operationId.isEmpty ||
          _retiredProgressIds.contains(snapshot.operationId)) {
        return;
      }
      final current = operationProgress;
      if (snapshot.operation != _progressKind &&
          snapshot.operation != 'directory') {
        return;
      }
      if (current != null &&
          current.operationId.isNotEmpty &&
          current.operationId != snapshot.operationId) {
        // Choosing a missing library may precede the requested scan/import.
        if (current.operation != 'directory' ||
            snapshot.operation != _progressKind) {
          return;
        }
        _retiredProgressIds.add(current.operationId);
      }
      if (current?.operationId == snapshot.operationId &&
          snapshot.elapsedMillis < current!.elapsedMillis) {
        return;
      }
      operationProgress = snapshot;
      _notify();
    } on MissingPluginException {
      // Older platforms retain the modal phase indicator and local elapsed time.
    } on PlatformException {
      // Progress telemetry must never change the result of the actual operation.
    } catch (_) {
      // Treat malformed optional telemetry in the same way as an unavailable API.
    } finally {
      if (_progressRequestEpoch == epoch) _progressRequestEpoch = null;
    }
  }

  void _endProgress() {
    final id = operationProgress?.operationId;
    if (id != null && id.isNotEmpty) _retiredProgressIds.add(id);
    _progressPoll?.cancel();
    _progressPoll = null;
    _progressClock.stop();
    operationProgress = null;
    _progressKind = null;
  }

  bool _saved() {
    if (_saveFailed) {
      errorCode ??= 'save_failed';
      return false;
    }
    return errorCode == null;
  }

  void _error(Object error) {
    if (error is MissingPluginException ||
        error is PlatformException &&
            const {
              'unsupported',
              'unsupported_platform',
              'platform_unsupported',
            }.contains(error.code)) {
      supported = false;
      errorCode = 'unsupported';
      _updatePolling();
    } else {
      errorCode = error is PlatformException ? error.code : 'operation_failed';
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _endProgress();
    portraits.removeListener(_notify);
    if (_ownsPortraits) portraits.dispose();
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final candidate = preflight;
    if (candidate != null) {
      unawaited(_port.discardImport(candidate.token).catchError((Object _) {}));
    }
    final scan = libraryScan, library = _libraryPort;
    if (scan != null && library != null) {
      unawaited(
        library.discardLibraryScan(scan.token).catchError((Object _) {}),
      );
    }
    super.dispose();
  }
}
