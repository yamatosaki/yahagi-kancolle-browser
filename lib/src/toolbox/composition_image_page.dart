import '../theme/app_palette.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../game_state/game_state.dart';
import '../backup/record_backup.dart';
import '../layout/adaptive_layout.dart';
import '../fleet/ship_portrait.dart';
import '../fleet/ship_portrait_cache.dart';
import '../widgets/app_segmented_style.dart';
import '../widgets/top_notice.dart';
import 'composition_image_card.dart';
import 'composition_image_port.dart';
import 'composition_image_strings.dart';
import 'composition_record_store.dart';
import 'composition_record_snapshot.dart';
import 'sortie_map_query/sortie_map_catalog.dart';
import 'sortie_map_query/sortie_map_catalog_controller.dart';
import 'sortie_map_query/sortie_map_models.dart';

typedef CompositionPngCapture =
    Future<Uint8List> Function(RenderRepaintBoundary boundary);

bool _canCropLegacyPng(Uint8List png) {
  if (png.length < 24) return false;
  final header = ByteData.sublistView(png);
  return header.getUint32(16, Endian.big) >= 1200 &&
      header.getUint32(20, Endian.big) >= 240;
}

/// Keeps an unfinished composition while the toolbox workspace is unmounted.
class CompositionImageDraftController {
  final Map<int, _CompositionImageDraft> _drafts = {};
}

final class _CompositionImageDraft {
  const _CompositionImageDraft({
    required this.showSaved,
    required this.selectedRecordId,
    required this.fleetFormIndex,
    required this.targetKind,
    required this.normalMap,
    required this.difficulty,
    required this.fleetIds,
    required this.landBaseIds,
    required this.areaId,
    required this.planeCounts,
    required this.eventMap,
    required this.name,
    required this.search,
    this.recordMapFilter = 'all',
  });

  final bool showSaved;
  final String? selectedRecordId;
  final int fleetFormIndex;
  final int targetKind;
  final String? normalMap;
  final String? difficulty;
  final Set<int> fleetIds;
  final Set<int> landBaseIds;
  final int? areaId;
  final CompositionPlaneCountMode planeCounts;
  final String eventMap;
  final String name;
  final String search;
  final String recordMapFilter;
}

class CompositionImagePage extends StatefulWidget {
  const CompositionImagePage({
    super.key,
    required this.state,
    this.port = const MethodChannelCompositionImagePort(),
    this.capturePng = captureCompositionPng,
    this.now = DateTime.now,
    this.visible = true,
    this.recordStore,
    this.initiallyShowSaved = true,
    this.sortieMapCatalogController,
    this.draftController,
  });

  final GameState state;
  final CompositionImagePort port;
  final CompositionPngCapture capturePng;
  final DateTime Function() now;
  final bool visible;
  final CompositionRecordStore? recordStore;
  final bool initiallyShowSaved;
  final SortieMapCatalogController? sortieMapCatalogController;
  final CompositionImageDraftController? draftController;

  @override
  State<CompositionImagePage> createState() => _CompositionImagePageState();
}

class _CompositionImagePageState extends State<CompositionImagePage> {
  final _imageKey = GlobalKey();
  final _savedImageKey = GlobalKey();
  late CompositionRecordStore _recordStore;
  StreamSubscription<CompositionRecordChange>? _recordChanges;
  final _nameController = TextEditingController();
  final _eventMapController = TextEditingController();
  final _searchController = TextEditingController();
  String _recordMapFilter = 'all';
  List<CompositionRecord> _records = [];
  bool _recordsLoadError = false;
  String? _selectedRecordId;
  Uint8List? _selectedPng;
  bool _selectedPngError = false;
  late bool _showSaved;
  int _loadGeneration = 0;
  int _fleetFormIndex = 0;
  int _targetKind = 0;
  String? _normalMap;
  List<SortieMapInfo> _normalMaps = const [];
  String? _difficulty;
  Set<int> _fleetIds = {1, 2, 3, 4};
  Set<int> _landBaseIds = {};
  int? _areaId;
  CompositionPlaneCountMode _planeCounts = CompositionPlaneCountMode.maximum;
  bool _saving = false;
  GameState? _frozenState;
  // Nullable lazy state also supports an already mounted page after hot reload.
  DateTime? _previewGeneratedAt;
  DateTime? _frozenGeneratedAt;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final draft = widget.draftController?._drafts[widget.state.memberId];
    if (draft == null) {
      _showSaved = widget.initiallyShowSaved;
    } else {
      _restoreDraft(draft);
    }
    _recordStore = widget.recordStore ?? FileCompositionRecordStore();
    if (widget.recordStore == null) {
      _recordChanges = FileCompositionRecordStore.changes.listen((change) {
        if (change.refreshOnly &&
            change.memberId == widget.state.memberId &&
            mounted) {
          _loadRecords();
        }
      });
    }
    widget.sortieMapCatalogController?.addListener(_updateMaps);
    _updateMaps();
    _loadRecords();
  }

  @override
  void reassemble() {
    super.reassemble();
    _updateMaps();
    final selectedId = _selectedRecordId;
    if (selectedId != null && _showSaved) _readSelected(selectedId);
  }

  @override
  void dispose() {
    _persistDraft(widget.state.memberId);
    _loadGeneration++;
    _recordChanges?.cancel();
    widget.sortieMapCatalogController?.removeListener(_updateMaps);
    _nameController.dispose();
    _eventMapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _persistDraft(int memberId) {
    widget.draftController?._drafts[memberId] = _CompositionImageDraft(
      showSaved: _showSaved,
      selectedRecordId: _selectedRecordId,
      fleetFormIndex: _fleetFormIndex,
      targetKind: _targetKind,
      normalMap: _normalMap,
      difficulty: _difficulty,
      fleetIds: Set.of(_fleetIds),
      landBaseIds: Set.of(_landBaseIds),
      areaId: _areaId,
      planeCounts: _planeCounts,
      eventMap: _eventMapController.text,
      name: _nameController.text,
      search: _searchController.text,
      recordMapFilter: _recordMapFilter,
    );
  }

  void _restoreDraft(_CompositionImageDraft draft) {
    _showSaved = draft.showSaved;
    _selectedRecordId = draft.selectedRecordId;
    _fleetFormIndex = draft.fleetFormIndex;
    _targetKind = draft.targetKind;
    _normalMap = draft.normalMap;
    _difficulty = draft.difficulty;
    _fleetIds = Set.of(draft.fleetIds);
    _landBaseIds = Set.of(draft.landBaseIds);
    _areaId = draft.areaId;
    _planeCounts = draft.planeCounts;
    _eventMapController.text = draft.eventMap;
    _nameController.text = draft.name;
    _searchController.text = draft.search;
    _recordMapFilter = draft.recordMapFilter;
  }

  Future<void> _loadRecords({String? selectId}) async {
    final generation = ++_loadGeneration;
    final memberId = widget.state.memberId;
    try {
      final records = await _recordStore.load(memberId);
      if (!mounted ||
          generation != _loadGeneration ||
          memberId != widget.state.memberId) {
        return;
      }
      if (_recordMapFilter != 'all' &&
          _recordMapFilter != 'none' &&
          _recordMapFilter != 'event') {
        final id = _recordMapFilter.startsWith('normal:')
            ? _recordMapFilter.substring(7)
            : '';
        final available =
            RegExp(r'^[1-7]-\d+$').hasMatch(id) &&
            (_normalMaps.any((map) => map.id == id) ||
                records.any(
                  (record) => record.effectiveMapTag == _recordMapFilter,
                ));
        if (!available) _recordMapFilter = 'all';
      }
      final matches = _matchingRecords(
        records,
        CompositionImageStrings.of(context),
      );
      final selected = selectId ?? _selectedRecordId;
      final id = matches.any((record) => record.id == selected)
          ? selected
          : matches.firstOrNull?.id;
      setState(() {
        _records = records;
        _recordsLoadError = false;
        _selectedRecordId = id;
        _selectedPng = null;
        _selectedPngError = false;
      });
      if (id != null) await _readSelected(id);
    } catch (_) {
      if (mounted &&
          generation == _loadGeneration &&
          memberId == widget.state.memberId) {
        setState(() {
          _records = [];
          _recordsLoadError = true;
          _selectedRecordId = null;
          _selectedPng = null;
          _selectedPngError = false;
        });
      }
    }
  }

  Future<void> _readSelected(String id) async {
    final memberId = widget.state.memberId;
    final hasSnapshot = _records.any(
      (record) => record.id == id && record.snapshotJson != null,
    );
    setState(() {
      _selectedRecordId = id;
      _selectedPng = null;
      _selectedPngError = false;
    });
    if (hasSnapshot) return;
    try {
      final png = await _recordStore.readPng(memberId, id);
      if (mounted &&
          memberId == widget.state.memberId &&
          _selectedRecordId == id) {
        setState(() {
          _selectedPng = png;
        });
      }
    } catch (_) {
      if (mounted &&
          memberId == widget.state.memberId &&
          _selectedRecordId == id) {
        if (hasSnapshot) return;
        setState(() => _selectedPngError = true);
        TopNotice.show(
          context,
          message: CompositionImageStrings.of(context).operationFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  GameState get _state => _frozenState ?? widget.state;
  DateTime get _generatedAt =>
      _frozenGeneratedAt ?? (_previewGeneratedAt ??= widget.now().toLocal());
  List<int> get _areas =>
      _state.landBases.map((b) => b.areaId).toSet().toList()..sort();
  int? get _effectiveArea => _areas.contains(_areaId) ? _areaId : null;

  Set<int> get _allowedFleetIds => switch (_fleetFormIndex) {
    1 => {2, 3, 4},
    2 || 3 || 4 => {1, 2},
    5 => {3},
    _ => {1, 2, 3, 4},
  };
  Set<int> get _activeFleetIds => _fleetIds.intersection(_allowedFleetIds);

  void _selectFleetForm(int index) => setState(() {
    _fleetFormIndex = index;
    _fleetIds = _allowedFleetIds;
    _refreshPreviewTime();
  });

  bool get _hasSelection =>
      _state.fleets.any(
        (f) =>
            _activeFleetIds.contains(f.id) &&
            f.shipIds.any(_state.ships.containsKey),
      ) ||
      _state.landBases.any(
        (b) => b.areaId == _effectiveArea && _landBaseIds.contains(b.baseId),
      );

  @override
  void didUpdateWidget(covariant CompositionImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortieMapCatalogController !=
        widget.sortieMapCatalogController) {
      oldWidget.sortieMapCatalogController?.removeListener(_updateMaps);
      widget.sortieMapCatalogController?.addListener(_updateMaps);
      _updateMaps();
    }
    final accountChanged = oldWidget.state.memberId != widget.state.memberId;
    if (accountChanged ||
        (oldWidget.state.canExportFleet && !widget.state.canExportFleet) ||
        (oldWidget.visible && !widget.visible)) {
      _generation++;
      _frozenState = null;
      _frozenGeneratedAt = null;
    }
    if (accountChanged) {
      _persistDraft(oldWidget.state.memberId);
      _fleetIds = {1, 2, 3, 4};
      _landBaseIds = {};
      _areaId = null;
      _records = [];
      _recordsLoadError = false;
      _selectedRecordId = null;
      _selectedPng = null;
      _selectedPngError = false;
      _nameController.clear();
      _eventMapController.clear();
      _searchController.clear();
      _recordMapFilter = 'all';
      _normalMap = null;
      _difficulty = null;
      _fleetFormIndex = 0;
      _targetKind = 0;
      _planeCounts = CompositionPlaneCountMode.maximum;
      final draft = widget.draftController?._drafts[widget.state.memberId];
      if (draft == null) {
        _showSaved = widget.initiallyShowSaved;
      } else {
        _restoreDraft(draft);
      }
      _loadRecords();
    }
    if (_compositionDataChanged(oldWidget.state, widget.state) ||
        (!oldWidget.visible && widget.visible)) {
      _refreshPreviewTime();
    }
  }

  void _refreshPreviewTime() => _previewGeneratedAt = widget.now().toLocal();

  bool _compositionDataChanged(GameState previous, GameState next) =>
      previous.memberId != next.memberId ||
      previous.admiralLevel != next.admiralLevel ||
      previous.canExportFleet != next.canExportFleet ||
      !listEquals(previous.fleets, next.fleets) ||
      !listEquals(previous.landBases, next.landBases) ||
      !mapEquals(previous.ships, next.ships) ||
      !mapEquals(previous.slotItems, next.slotItems) ||
      !mapEquals(previous.masterShips, next.masterShips) ||
      !mapEquals(previous.masterShipTypes, next.masterShipTypes) ||
      !mapEquals(previous.masterSlotItems, next.masterSlotItems) ||
      !mapEquals(previous.masterMapAreas, next.masterMapAreas);

  void _updateMaps() {
    final controller = widget.sortieMapCatalogController;
    if (controller != null) {
      _setMaps(controller.data.maps);
    } else {
      SortieMapCatalog.loadAsset().then((data) {
        if (mounted) _setMaps(data.maps);
      });
    }
  }

  void _setMaps(List<SortieMapInfo> maps) {
    final normal = maps
        .where((map) => RegExp(r'^[1-7]-\d+$').hasMatch(map.id))
        .toList();
    if (mounted) setState(() => _normalMaps = normal);
  }

  String get _targetMap => _targetKind == 0
      ? ''
      : _targetKind == 2
      ? [
          _eventMapController.text.trim(),
          ?_difficulty,
        ].where((value) => value.isNotEmpty).join(' · ')
      : _normalMap == null
      ? ''
      : _normalMaps
                .where((map) => map.id == _normalMap)
                .map((map) => '${map.id} ${map.nameJa}')
                .firstOrNull ??
            _normalMap!;

  String get _namePrefix => switch (_targetKind) {
    1 => _normalMap ?? '',
    2 => _targetMap,
    _ => '',
  };

  String get _composedName => [
    _namePrefix,
    _nameController.text.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  String _recordName(CompositionImageStrings strings) =>
      _composedName.isEmpty ? strings.noTargetMap : _composedName;

  Future<void> _save({bool asRecord = false}) async {
    if (_saving || !widget.state.canExportFleet || !_hasSelection) return;
    final strings = CompositionImageStrings.of(context);
    if (asRecord && _records.length >= maxCompositionRecordsPerAccount) {
      TopNotice.show(
        context,
        message: strings.recordLimitReached,
        tone: TopNoticeTone.error,
      );
      return;
    }
    if (asRecord &&
        ((_targetKind == 1 &&
                !_normalMaps.any((map) => map.id == _normalMap)) ||
            (_targetKind == 2 && _eventMapController.text.trim().isEmpty))) {
      TopNotice.show(
        context,
        message: strings.mapRequired,
        tone: TopNoticeTone.error,
      );
      return;
    }
    final recordName = _recordName(strings);
    final recordMapTag = switch (_targetKind) {
      1 => 'normal:${_normalMap ?? ''}',
      2 => 'event',
      _ => 'none',
    };
    final selectedFleetIds = Set<int>.of(_activeFleetIds);
    final selectedAreaId = _effectiveArea;
    final selectedBaseIds = Set<int>.of(_landBaseIds);
    final planeCountMode = _planeCounts;
    final fleetForm = strings.fleetForms[_fleetFormIndex];
    final targetMap = _targetMap;
    final landBaseCount = widget.state.landBases
        .where(
          (base) =>
              base.areaId == selectedAreaId &&
              selectedBaseIds.contains(base.baseId),
        )
        .length;
    final snapshotJson = asRecord
        ? serializeCompositionSnapshot(
            widget.state,
            fleetIds: selectedFleetIds,
            landBaseAreaId: selectedAreaId,
            landBaseIds: selectedBaseIds,
          )
        : null;
    final generation = ++_generation;
    final memberId = widget.state.memberId;
    final generatedAt = widget.now().toLocal();
    setState(() {
      _saving = true;
      _frozenState = widget.state;
      _previewGeneratedAt = generatedAt;
      _frozenGeneratedAt = generatedAt;
    });
    try {
      final portraits = <Future<Object?>>[];
      for (final fleet in widget.state.fleets.where(
        (fleet) => selectedFleetIds.contains(fleet.id),
      )) {
        for (final shipId in fleet.shipIds) {
          final ship = widget.state.ships[shipId];
          final master = ship == null ? null : widget.state.masterForShip(ship);
          if (master == null) continue;
          final uri = ShipPortraitUriBuilder.build(
            ship: master,
            serverOrigin: widget.state.serverOrigin,
            resourceType: ShipPortraitResourceType.remodel,
          );
          if (uri != null) {
            portraits.add(
              ShipPortraitCache.shared.resolve(
                cacheKey: '${master.id}_remodel',
                uri: uri,
              ),
            );
          }
        }
      }
      await Future.wait(portraits);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _generation) return;
      final imageContext = _imageKey.currentContext;
      if (imageContext == null) {
        throw StateError('Composition preview is unavailable');
      }
      // Wait for every local equipment icon, including images below the viewport.
      final providers = <ImageProvider>{};
      void collect(Element element) {
        if (element.widget case Image(image: final provider)) {
          providers.add(provider);
        }
        element.visitChildElements(collect);
      }

      (imageContext as Element).visitChildElements(collect);
      await Future.wait(
        providers.map(
          (provider) =>
              precacheImage(provider, imageContext, onError: (_, _) {}),
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _generation) return;
      final boundary = _imageKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Composition preview is unavailable');
      }
      final bytes = await widget.capturePng(boundary);
      if (!mounted || generation != _generation) return;
      if (asRecord) {
        final record = await _recordStore.create(
          memberId: memberId,
          png: bytes,
          note: '',
          name: recordName,
          fleetForm: fleetForm,
          targetMap: targetMap,
          fleetIds: selectedFleetIds.toList()..sort(),
          landBaseCount: landBaseCount,
          createdAt: generatedAt,
          snapshotJson: snapshotJson,
          landBaseAreaId: selectedAreaId,
          landBaseIds: selectedBaseIds.toList()..sort(),
          planeCountMode: planeCountMode.name,
          mapTag: recordMapTag,
        );
        if (!mounted ||
            generation != _generation ||
            memberId != widget.state.memberId) {
          return;
        }
        _nameController.clear();
        _recordMapFilter = 'all';
        _searchController.clear();
        _showSaved = true;
        await _loadRecords(selectId: record.id);
      } else {
        await widget.port.savePng(bytes);
      }
      if (!mounted || generation != _generation) return;
      TopNotice.show(
        context,
        message: asRecord ? strings.recordSaved : strings.saved,
        tone: TopNoticeTone.success,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      TopNotice.show(
        context,
        message: error is PlatformException && error.code.contains('permission')
            ? strings.permissionDenied
            : error is CompositionRecordLimitReachedException
            ? strings.recordLimitReached
            : asRecord
            ? strings.operationFailed
            : strings.saveFailed,
        tone: TopNoticeTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _frozenState = null;
          _frozenGeneratedAt = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final strings = CompositionImageStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
          child: SizedBox(
            height: _modeBarHeight(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final phonePortrait =
                    compact &&
                    MediaQuery.orientationOf(context) == Orientation.portrait;
                final selectedRecord = _records
                    .where((record) => record.id == _selectedRecordId)
                    .firstOrNull;
                return Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 224),
                          child: _modeTabs(strings),
                        ),
                      ),
                    ),
                    if (_showSaved) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 32,
                        child: Tooltip(
                          message: strings.newRecord,
                          child: phonePortrait
                              ? FilledButton(
                                  key: const Key('composition-new-record'),
                                  onPressed: () =>
                                      setState(() => _showSaved = false),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: appColor(
                                      context,
                                      Color(0xffe8c67c),
                                    ),
                                    foregroundColor: appOnAccentColor(
                                      context,
                                      const Color(0xff10222d),
                                    ),
                                    fixedSize: const Size(32, 32),
                                    minimumSize: const Size(32, 32),
                                    maximumSize: const Size(32, 32),
                                    shape: const CircleBorder(),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Icon(Icons.add, size: 20),
                                )
                              : FilledButton.icon(
                                  key: const Key('composition-new-record'),
                                  onPressed: () =>
                                      setState(() => _showSaved = false),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(strings.newRecord),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: appColor(
                                      context,
                                      Color(0xffe8c67c),
                                    ),
                                    foregroundColor: appOnAccentColor(
                                      context,
                                      const Color(0xff10222d),
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 8 : 13,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: strings.exportImage,
                        child: OutlinedButton(
                          key: const Key('composition-export-record'),
                          onPressed:
                              selectedRecord == null ||
                                  (_selectedPng == null &&
                                      selectedRecord.snapshotJson == null)
                              ? null
                              : () => _exportRecord(selectedRecord, strings),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size.fromHeight(32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 7 : 10,
                            ),
                          ),
                          child: _headerActionLabel(
                            Icons.download_rounded,
                            strings.exportImage,
                            compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: strings.deleteRecord,
                        child: TextButton(
                          key: const Key('composition-delete-record'),
                          onPressed: selectedRecord == null
                              ? null
                              : () => _deleteRecord(selectedRecord, strings),
                          style: TextButton.styleFrom(
                            foregroundColor: appColor(
                              context,
                              Color(0xffeaa5a0),
                            ),
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size.fromHeight(32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 7 : 10,
                            ),
                          ),
                          child: _headerActionLabel(
                            Icons.delete_outline,
                            strings.deleteRecord,
                            compact,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        Divider(height: 1, color: appColor(context, Color(0xff315064))),
        Expanded(
          child: _showSaved
              ? _library(strings)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final controls = _controls(strings);
                    final preview = _preview(strings);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          controls,
                          const SizedBox(height: 16),
                          preview,
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _headerActionLabel(IconData icon, String label, bool compact) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17),
      if (!compact) ...[
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ],
  );

  // Keep the record switch as one compact control on every composition layout.
  double _modeBarHeight(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en'
      ? 44 * math.max(1.0, MediaQuery.textScalerOf(context).scale(12) / 12)
      : 38;

  Widget _modeTabs(CompositionImageStrings strings) => SizedBox(
    key: const Key('composition-mode-bar'),
    height: _modeBarHeight(context),
    child: LayoutBuilder(
      builder: (context, constraints) => Container(
        padding: AppSegmentedStyle.padding(),
        decoration: AppSegmentedStyle.decoration(context),
        child: ClipRRect(
          borderRadius: AppSegmentedStyle.itemRadius(),
          child: Stack(
            children: [
              AnimatedPositioned(
                left: _showSaved ? 0 : (constraints.maxWidth - 6) / 2,
                top: 0,
                bottom: 0,
                width: (constraints.maxWidth - 6) / 2,
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppSegmentedStyle.selectedBackground(context),
                    borderRadius: AppSegmentedStyle.itemRadius(),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var index = 0; index < 2; index++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _showSaved == (index == 0),
                        child: InkWell(
                          key: Key(
                            index == 0
                                ? 'composition-saved-tab'
                                : 'composition-current-tab',
                          ),
                          borderRadius: AppSegmentedStyle.itemRadius(),
                          onTap: () => setState(() => _showSaved = index == 0),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Tooltip(
                                    message: index == 0
                                        ? strings.savedTab
                                        : strings.currentTab,
                                    child: Text(
                                      index == 0
                                          ? strings.savedTab
                                          : strings.currentTab,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: AppSegmentedStyle.textStyle(
                                        context,
                                        selected: _showSaved == (index == 0),
                                      ),
                                    ),
                                  ),
                                ),
                                if (index == 0) ...[
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_records.length}',
                                    style: appTextStyle(
                                      context,
                                      TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: appColor(
                                          context,
                                          Color(0xfff2cc7d),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _library(CompositionImageStrings strings) {
    final matches = _matchingRecords(_records, strings);
    final selected = matches
        .where((record) => record.id == _selectedRecordId)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = _usesWideCompositionLayout(
          context,
          constraints.maxWidth,
          800,
        );
        final phonePortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait &&
            MediaQuery.sizeOf(context).shortestSide < 600;
        final search = SizedBox(
          height: 36,
          child: TextField(
            key: const Key('composition-search'),
            controller: _searchController,
            onChanged: (_) => _updateRecordSelection(strings),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 34,
              ),
              hintText: strings.searchShort,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
        final filter = _recordFilterDropdown(strings);
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (phonePortrait)
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 6),
                  Expanded(child: filter),
                ],
              )
            else ...[
              search,
              const SizedBox(height: 6),
              filter,
            ],
            const SizedBox(height: 6),
            if (_recordsLoadError)
              _emptyLibrary(strings.recordLoadFailed, '', onRetry: _loadRecords)
            else if (_records.isEmpty)
              _emptyLibrary(strings.noRecords, strings.selectRecord)
            else if (matches.isEmpty)
              _emptyLibrary(strings.noMatches, '')
            else
              for (final record in matches) _recordTile(record, strings),
          ],
        );
        final detail = selected == null
            ? _emptyLibrary(strings.selectRecord, '')
            : _recordDetail(selected);
        if (phonePortrait) {
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(0, (constraints.maxHeight - 30) / 2),
                  ),
                  child: SingleChildScrollView(
                    key: const Key('composition-record-list-scroll'),
                    child: list,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('composition-record-detail-scroll'),
                    child: detail,
                  ),
                ),
              ],
            ),
          );
        }
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    key: const Key('composition-record-list-scroll'),
                    child: list,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 8,
                  child: SingleChildScrollView(
                    key: const Key('composition-record-detail-scroll'),
                    child: detail,
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [list, const SizedBox(height: 10), detail],
          ),
        );
      },
    );
  }

  List<CompositionRecord> _matchingRecords(
    List<CompositionRecord> records,
    CompositionImageStrings strings,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return records.where((record) {
      if (_recordMapFilter != 'all' &&
          record.effectiveMapTag != _recordMapFilter) {
        return false;
      }
      return _recordSearchText(record, strings).toLowerCase().contains(query);
    }).toList();
  }

  void _updateRecordSelection(CompositionImageStrings strings) {
    final matches = _matchingRecords(_records, strings);
    if (matches.any((record) => record.id == _selectedRecordId)) {
      setState(() {});
    } else if (matches.isNotEmpty) {
      _readSelected(matches.first.id);
    } else {
      setState(() {
        _selectedRecordId = null;
        _selectedPng = null;
      });
    }
  }

  List<String> get _filterMapIds {
    final normalIdPattern = RegExp(r'^[1-7]-\d+$');
    final ids = <String>{
      for (final map in _normalMaps) map.id,
      for (final record in _records)
        if (record.effectiveMapTag.startsWith('normal:'))
          if (normalIdPattern.hasMatch(record.effectiveMapTag.substring(7)))
            record.effectiveMapTag.substring(7),
    }.toList();
    ids.sort((a, b) {
      final area = a.codeUnitAt(0).compareTo(b.codeUnitAt(0));
      if (area != 0) return area;
      final left = int.tryParse(a.substring(2));
      final right = int.tryParse(b.substring(2));
      if (left != null && right != null) return left.compareTo(right);
      if (left != null) return -1;
      if (right != null) return 1;
      return a.compareTo(b);
    });
    return ids;
  }

  String _filterMapLabel(String id) {
    final map = _normalMaps.where((map) => map.id == id).firstOrNull;
    if (map != null) return '$id ${map.nameJa}';
    return _records
            .where((record) => record.effectiveMapTag == 'normal:$id')
            .map((record) => record.targetMap.trim())
            .where((target) => target.isNotEmpty)
            .firstOrNull ??
        id;
  }

  Widget _recordFilterDropdown(CompositionImageStrings strings) {
    final mapIds = _filterMapIds;
    final options = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'all',
        child: Text(
          strings.allRecords,
          key: const Key('composition-filter-all'),
        ),
      ),
      DropdownMenuItem(
        value: 'none',
        child: Text(
          strings.noTargetMap,
          key: const Key('composition-filter-none'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      DropdownMenuItem(
        value: 'event',
        child: Text(
          strings.eventMap,
          key: const Key('composition-filter-event'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      for (final id in mapIds)
        DropdownMenuItem(
          value: 'normal:$id',
          child: Text(
            _filterMapLabel(id),
            key: Key('composition-filter-map-$id'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    final selectedTag =
        options.any((option) => option.value == _recordMapFilter)
        ? _recordMapFilter
        : 'all';
    return Container(
      key: const Key('composition-filter'),
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: appColor(context, Color(0xff526a76))),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          barrierDismissible: false,
          value: selectedTag,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: appColor(context, Color(0xfff4eee4)),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          alignment: Alignment.centerLeft,
          icon: const SizedBox.shrink(),
          menuWidth: math.min(440, MediaQuery.sizeOf(context).width - 24),
          menuMaxHeight: 430,
          dropdownColor: appColor(context, Color(0xff183541)),
          items: options,
          selectedItemBuilder: (context) => [
            for (final label in [
              strings.filterRecords,
              strings.noTargetMap,
              strings.eventMap,
              ...mapIds,
            ])
              Row(
                children: [
                  const SizedBox(
                    width: 39,
                    child: Icon(Icons.arrow_drop_down, size: 18),
                  ),
                  Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
          ],
          onChanged: (tag) {
            if (tag == null) return;
            _recordMapFilter = tag;
            _updateRecordSelection(strings);
          },
        ),
      ),
    );
  }

  String _recordTagLabel(
    CompositionRecord record,
    CompositionImageStrings strings,
  ) => switch (record.effectiveMapTag) {
    'none' => strings.noTargetMap,
    'event' => strings.eventMap,
    final tag when tag.startsWith('normal:') => tag.substring(7),
    _ => strings.noTargetMap,
  };

  Widget _emptyLibrary(String title, String detail, {VoidCallback? onRetry}) =>
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: appColor(context, Color(0xff102732)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: appColor(context, Color(0xff284553))),
        ),
        child: Column(
          children: [
            Icon(
              Icons.bookmark_border,
              color: appColor(context, Color(0xff809baa)),
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: appTextStyle(
                    context,
                    TextStyle(color: appColor(context, Color(0xff9aafb9))),
                  ),
                ),
              ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                key: const Key('composition-record-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(CompositionImageStrings.of(context).retry),
              ),
            ],
          ],
        ),
      );

  String _recordTitle(
    CompositionRecord record,
    CompositionImageStrings strings,
  ) {
    final name = record.name.trim();
    final target = record.targetMap.trim();
    if (target.isEmpty) return name.isEmpty ? strings.unnamed : name;
    final prefix =
        RegExp(r'^[1-7]-\d+(?=\s|$)').firstMatch(target)?.group(0) ?? target;
    if (name.isEmpty) return '$prefix ${strings.unnamed}';
    if (name == prefix || name.startsWith('$prefix ')) return name;
    return '$prefix $name';
  }

  String _recordSearchText(
    CompositionRecord record,
    CompositionImageStrings strings,
  ) =>
      '${_recordTitle(record, strings)} ${record.targetMap} ${_recordTagLabel(record, strings)} ${record.fleetForm} ${record.fleetIds.map(strings.fleet).join(' ')}';

  Widget _recordTile(
    CompositionRecord record,
    CompositionImageStrings strings,
  ) {
    final selected = record.id == _selectedRecordId;
    return Material(
      color: appColor(
        context,
        selected ? const Color(0xff203b49) : const Color(0xff142d39),
      ),
      child: InkWell(
        key: Key('composition-record-${record.id}'),
        onTap: () => _readSelected(record.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: appColor(
                  context,
                  selected ? const Color(0xffcaa566) : Colors.transparent,
                ),
                width: 3,
              ),
              bottom: BorderSide(color: appColor(context, Color(0xff355260))),
            ),
          ),
          child: Text(
            _recordTitle(record, strings),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  GameState? _recordSnapshot(CompositionRecord record) {
    final json = record.snapshotJson;
    if (json == null) return null;
    try {
      return deserializeCompositionSnapshot(json);
    } catch (_) {
      return null;
    }
  }

  Widget _legacyRecordTable(Uint8List png) {
    if (!_canCropLegacyPng(png)) {
      return Image.memory(
        png,
        key: const Key('composition-saved-preview'),
        fit: BoxFit.fitWidth,
      );
    }
    final header = ByteData.sublistView(png);
    final pixelWidth = header.getUint32(16, Endian.big);
    final pixelHeight = header.getUint32(20, Endian.big);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fullHeight = width * pixelHeight / pixelWidth;
        final top = width * 90 / 1200;
        final bottom = width * 65 / 1200;
        return SizedBox(
          key: const Key('composition-saved-preview'),
          height: fullHeight - top - bottom,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: -top,
                  child: Image.memory(png, width: width, fit: BoxFit.fitWidth),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recordDetail(CompositionRecord record) {
    final snapshot = _recordSnapshot(record);
    return Container(
      key: const Key('composition-record-detail'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff112a37)),
        border: Border.all(color: appColor(context, Color(0xff315064))),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (snapshot != null)
            FittedBox(
              key: const Key('composition-saved-table'),
              fit: BoxFit.fitWidth,
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: _savedImageKey,
                child: CompositionImageCard(
                  state: snapshot,
                  fleetIds: record.fleetIds.toSet(),
                  landBaseAreaId: record.landBaseAreaId,
                  landBaseIds: record.landBaseIds.toSet(),
                  planeCountMode:
                      CompositionPlaneCountMode.values
                          .where((mode) => mode.name == record.planeCountMode)
                          .firstOrNull ??
                      CompositionPlaneCountMode.maximum,
                  generatedAt: record.createdAt,
                  recordMode: true,
                ),
              ),
            )
          else if (_selectedPng != null)
            _legacyRecordTable(_selectedPng!)
          else if (_selectedPngError)
            _emptyLibrary(
              CompositionImageStrings.of(context).recordImageUnavailable,
              '',
              onRetry: () => _readSelected(record.id),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportRecord(
    CompositionRecord record,
    CompositionImageStrings strings,
  ) async {
    try {
      Uint8List? png = record.snapshotJson == null ? _selectedPng : null;
      if (record.snapshotJson != null) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || _selectedRecordId != record.id) return;
        final boundary = _savedImageKey.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary) {
          throw StateError('Composition image is unavailable');
        }
        png = await widget.capturePng(boundary);
      }
      if (png == null) return;
      await widget.port.savePng(png);
      if (mounted) {
        TopNotice.show(
          context,
          message: strings.saved,
          tone: TopNoticeTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        TopNotice.show(
          context,
          message: strings.saveFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Future<void> _deleteRecord(
    CompositionRecord record,
    CompositionImageStrings strings,
  ) async {
    final memberId = widget.state.memberId;
    final confirmed = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteQuestion),
        content: Text(strings.deleteHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.deleteRecord),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.state.memberId != memberId) {
      return;
    }
    try {
      final backup = RecordBackupService.shared;
      if (backup != null && widget.recordStore == null) {
        await backup.removeCompositionRecord(memberId, record.id);
      } else {
        await _recordStore.delete(memberId, record.id);
      }
      if (!mounted || widget.state.memberId != memberId) return;
      await _loadRecords();
      if (mounted && widget.state.memberId == memberId) {
        TopNotice.show(
          context,
          message: strings.recordDeleted,
          tone: TopNoticeTone.success,
        );
      }
    } catch (_) {
      if (mounted && widget.state.memberId == memberId) {
        TopNotice.show(
          context,
          message: strings.operationFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Widget _controls(CompositionImageStrings strings) {
    final fleets = _state.fleets.where((f) => f.id >= 1 && f.id <= 4).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final bases = _state.landBases
        .where((b) => b.areaId == _effectiveArea)
        .toList();
    return Container(
      key: const Key('composition-controls'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff102732)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appColor(context, const Color(0xff284553))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              _usesWideCompositionLayout(context, constraints.maxWidth, 700)
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
          Widget group(List<Widget> children) => SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(strings.selection),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  group([
                    Text(
                      strings.fleets,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: appColor(context, Color(0xffa6bdc8)),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _selectionGrid(
                      key: const Key('composition-fleet-grid'),
                      labels: [
                        for (final fleet in fleets) strings.fleet(fleet.id),
                      ],
                      columns: 2,
                      selected: (index) =>
                          _activeFleetIds.contains(fleets[index].id),
                      enabled: (index) =>
                          _allowedFleetIds.contains(fleets[index].id),
                      segmentKey: (index) =>
                          Key('composition-fleet-${fleets[index].id}'),
                      onSelected: (index) => setState(() {
                        final id = fleets[index].id;
                        if (!_allowedFleetIds.contains(id)) return;
                        _fleetIds = {..._fleetIds};
                        _fleetIds.contains(id)
                            ? _fleetIds.remove(id)
                            : _fleetIds.add(id);
                        _refreshPreviewTime();
                      }),
                    ),
                  ]),
                  group([
                    Text(
                      strings.airBaseTitle,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: appColor(context, Color(0xffa6bdc8)),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_areas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          strings.noAirBases,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(context, Color(0xff7893a2)),
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      barrierDismissible: false,
                      key: ValueKey('composition-area-${_effectiveArea ?? 0}'),
                      initialValue: _effectiveArea,
                      hint: Text(strings.noAirBase),
                      isExpanded: true,
                      dropdownColor: appColor(context, Color(0xff183541)),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appColor(context, const Color(0xffd5e4eb)),
                        fontSize: 12,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: Text(strings.noAirBase),
                        ),
                        for (final area in _areas)
                          DropdownMenuItem(
                            value: area,
                            child: Text(
                              _state.masterMapAreas[area] ?? strings.area(area),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (area) => setState(() {
                              _areaId = area;
                              _landBaseIds = {};
                              _refreshPreviewTime();
                            }),
                    ),
                    const SizedBox(height: 6),
                    _selectionGrid(
                      key: const Key('composition-base-grid'),
                      labels: [
                        for (var id = 1; id <= 3; id++) strings.landBase(id),
                      ],
                      columns: 3,
                      selected: (index) =>
                          _effectiveArea != null &&
                          _landBaseIds.contains(index + 1),
                      enabled: (index) =>
                          _effectiveArea != null &&
                          bases.any((base) => base.baseId == index + 1),
                      segmentKey: (index) => Key(
                        'composition-select-base-${_effectiveArea ?? 0}-${index + 1}',
                      ),
                      onSelected: (index) => setState(() {
                        final id = index + 1;
                        _landBaseIds = {..._landBaseIds};
                        _landBaseIds.contains(id)
                            ? _landBaseIds.remove(id)
                            : _landBaseIds.add(id);
                        _refreshPreviewTime();
                      }),
                    ),
                  ]),
                  group([
                    Text(
                      strings.fleetForm,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: appColor(context, Color(0xffa6bdc8)),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _fleetFormChoices(strings),
                  ]),
                  group([
                    Text(
                      strings.planeCounts,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: appColor(context, Color(0xffa6bdc8)),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _planeCountTabs(strings),
                  ]),
                  group([
                    Text(
                      strings.targetMap,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: appColor(context, Color(0xffa6bdc8)),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _selectionGrid(
                      key: const Key('composition-target-segmented'),
                      labels: [
                        strings.noTargetMap,
                        strings.normalMap,
                        strings.eventMap,
                      ],
                      columns: 3,
                      selected: (index) => _targetKind == index,
                      segmentKey: (index) => switch (index) {
                        0 => const Key('composition-target-none'),
                        1 => const Key('composition-target-normal'),
                        _ => const Key('composition-target-event'),
                      },
                      onSelected: (index) =>
                          setState(() => _targetKind = index),
                    ),
                    if (_targetKind != 0) const SizedBox(height: 8),
                    if (_targetKind == 1)
                      DropdownButtonFormField<String>(
                        barrierDismissible: false,
                        key: const Key('composition-target-map'),
                        initialValue:
                            _normalMaps.any((map) => map.id == _normalMap)
                            ? _normalMap
                            : null,
                        hint: Text(strings.chooseMap),
                        isExpanded: true,
                        dropdownColor: appColor(context, Color(0xff183541)),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final map in _normalMaps)
                            DropdownMenuItem(
                              value: map.id,
                              child: Text(
                                '${map.id} ${map.nameJa}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _normalMap = value),
                      ),
                    if (_targetKind == 2) ...[
                      TextField(
                        key: const Key('composition-event-map'),
                        controller: _eventMapController,
                        maxLength: 40,
                        enabled: !_saving,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: strings.eventMapHint,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          counterStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        strings.difficulty,
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: appColor(context, Color(0xffa6bdc8)),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _selectionGrid(
                        key: const Key('composition-difficulty-segmented'),
                        labels: compositionDifficultyCodes,
                        columns: 4,
                        selected: (index) =>
                            _difficulty == compositionDifficultyCodes[index],
                        segmentKey: (index) => Key(
                          'composition-difficulty-${compositionDifficultyCodes[index]}',
                        ),
                        onSelected: (index) => setState(() {
                          final value = compositionDifficultyCodes[index];
                          _difficulty = _difficulty == value ? null : value;
                          _refreshPreviewTime();
                        }),
                      ),
                    ],
                  ]),
                  group([
                    Text(
                      strings.recordName,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: appColor(context, Color(0xffa6bdc8)),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('composition-name'),
                      controller: _nameController,
                      maxLength: 40,
                      enabled: !_saving,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: switch (_targetKind) {
                          1 => strings.normalNameHint,
                          2 => strings.eventNameHint,
                          _ => strings.recordNameHint,
                        },
                        isDense: true,
                        border: const OutlineInputBorder(),
                        counterStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_targetKind == 0 || _composedName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${strings.finalRecordName}：${_recordName(strings)}',
                        key: const Key('composition-name-preview'),
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: appColor(context, Color(0xffe8c67c)),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  bool _usesWideCompositionLayout(
    BuildContext context,
    double availableWidth,
    double regularBreakpoint,
  ) =>
      availableWidth >= regularBreakpoint ||
      (availableWidth >= 600 &&
          classifyAdaptiveWindow(MediaQuery.sizeOf(context)) ==
              AdaptiveWindowClass.nearSquareLarge);

  Widget _preview(CompositionImageStrings strings) => Column(
    key: const Key('composition-preview'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        key: const Key('composition-preview-header'),
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            strings.preview,
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffecf3f5)),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _saveButton(strings),
              FilledButton.icon(
                key: const Key('composition-save-record'),
                onPressed: !_saving && _state.canExportFleet && _hasSelection
                    ? () => _save(asRecord: true)
                    : null,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(strings.recordSave),
                style: FilledButton.styleFrom(
                  backgroundColor: appColor(context, Color(0xffd7b56d)),
                  foregroundColor: appOnAccentColor(
                    context,
                    const Color(0xff10222d),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (!_state.canExportFleet || !_hasSelection)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 55),
          decoration: BoxDecoration(
            color: appColor(context, Color(0xff102732)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 34,
                color: appColor(context, Color(0xff5b7a89)),
              ),
              const SizedBox(height: 14),
              Text(
                !_state.hasPortData
                    ? strings.waitingForPort
                    : !_state.hasEquipmentInventory
                    ? strings.waitingForEquipment
                    : !_state.canExportFleet
                    ? strings.refreshingShips
                    : strings.emptySelection,
                textAlign: TextAlign.center,
                style: appTextStyle(
                  context,
                  TextStyle(color: appColor(context, Color(0xffa6bdc8))),
                ),
              ),
            ],
          ),
        )
      else
        FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _imageKey,
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: 1,
              maxScaleFactor: 1,
              child: CompositionImageCard(
                state: _state,
                generatedAt: _generatedAt,
                fleetIds: _activeFleetIds,
                landBaseAreaId: _effectiveArea,
                landBaseIds: _landBaseIds,
                planeCountMode: _planeCounts,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _fleetFormChoices(CompositionImageStrings strings) => _selectionGrid(
    key: const Key('composition-form-segmented'),
    labels: strings.fleetForms,
    columns: 2,
    selected: (index) => _fleetFormIndex == index,
    segmentKey: (index) => Key('composition-form-$index'),
    onSelected: _selectFleetForm,
  );

  Widget _selectionGrid({
    required Key key,
    required List<String> labels,
    required int columns,
    required bool Function(int) selected,
    bool Function(int)? enabled,
    required Key Function(int) segmentKey,
    required ValueChanged<int> onSelected,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = (labels.length / columns).ceil();
      return Container(
        key: key,
        width: constraints.maxWidth,
        clipBehavior: Clip.antiAlias,
        decoration: AppSegmentedStyle.decoration(context),
        padding: AppSegmentedStyle.padding(),
        child: Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: 3),
              Row(
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: 3),
                    Expanded(
                      child: row * columns + col < labels.length
                          ? _selectionCell(
                              label: labels[row * columns + col],
                              selected: selected(row * columns + col),
                              enabled:
                                  enabled?.call(row * columns + col) ?? true,
                              key: segmentKey(row * columns + col),
                              onTap: () => onSelected(row * columns + col),
                            )
                          : const SizedBox(height: 34),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _selectionCell({
    required String label,
    required bool selected,
    required bool enabled,
    required Key key,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    enabled: enabled && !_saving,
    child: InkWell(
      key: key,
      borderRadius: AppSegmentedStyle.itemRadius(),
      onTap: _saving || !enabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? appColor(context, const Color(0xff1b2e38))
              : AppSegmentedStyle.selection(context, selected),
          borderRadius: AppSegmentedStyle.itemRadius(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!enabled) ...[
                  Icon(
                    Icons.lock_outline,
                    size: 11,
                    color: appColor(context, Color(0xff718896)),
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppSegmentedStyle.textStyle(
                        context,
                        selected: selected,
                      ).copyWith(
                        color: !enabled
                            ? appColor(context, const Color(0xff718896))
                            : AppSegmentedStyle.foreground(context, selected),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _planeCountTabs(CompositionImageStrings strings) => Container(
    key: const Key('composition-plane-count-tabs'),
    height: 40,
    padding: AppSegmentedStyle.padding(),
    decoration: AppSegmentedStyle.decoration(context),
    child: Row(
      children: [
        for (final mode in const [
          CompositionPlaneCountMode.hidden,
          CompositionPlaneCountMode.maximum,
        ])
          Expanded(
            child: Semantics(
              button: true,
              selected: _planeCounts == mode,
              child: Material(
                key: Key('composition-planes-${mode.name}'),
                color: AppSegmentedStyle.selection(
                  context,
                  _planeCounts == mode,
                ),
                borderRadius: AppSegmentedStyle.itemRadius(),
                child: InkWell(
                  borderRadius: AppSegmentedStyle.itemRadius(),
                  onTap: _saving
                      ? null
                      : () => setState(() {
                          _planeCounts = mode;
                          _refreshPreviewTime();
                        }),
                  child: Center(
                    child: Text(
                      switch (mode) {
                        CompositionPlaneCountMode.hidden => strings.hidden,
                        CompositionPlaneCountMode.current => strings.current,
                        CompositionPlaneCountMode.maximum => strings.maximum,
                      },
                      style: AppSegmentedStyle.textStyle(
                        context,
                        selected: _planeCounts == mode,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _saveButton(CompositionImageStrings strings) => FilledButton.icon(
    key: const Key('composition-save'),
    onPressed: !_saving && _state.canExportFleet && _hasSelection
        ? () => _save()
        : null,
    icon: _saving
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.save_alt_rounded, size: 18),
    label: Text(_saving ? strings.saving : strings.exportImage),
    style: FilledButton.styleFrom(
      backgroundColor: appColor(context, Color(0xff234352)),
      foregroundColor: appColor(context, Color(0xffd7e8eb)),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: appTextStyle(
      context,
      TextStyle(
        color: appColor(context, Color(0xffd8e6ec)),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Capture the entire non-lazy card, including content below the scroll viewport.
Future<Uint8List> captureCompositionPng(RenderRepaintBoundary boundary) async {
  final area = boundary.size.width * boundary.size.height;
  if (!area.isFinite || area <= 0 || area > 16000000) {
    throw StateError('Composition image is too large');
  }
  final ratio = math.min(2.0, math.sqrt(12000000 / area));
  final image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Composition PNG encoding failed');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
