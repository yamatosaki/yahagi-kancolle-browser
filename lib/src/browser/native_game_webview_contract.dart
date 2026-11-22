import 'safe_page_address.dart';

const nativeGameWebViewMethodChannelName =
    'app.yahagi.kancollebrowser/native_game_webview';
const nativeGameWebViewEventChannelName =
    'app.yahagi.kancollebrowser/native_game_webview_events';

final class NativeGameWebViewSchemaException implements Exception {
  const NativeGameWebViewSchemaException([
    this.message = 'Invalid native WebView schema.',
  ]);

  final String message;

  @override
  String toString() => 'NativeGameWebViewSchemaException: $message';
}

final class NativeGameWebViewBounds {
  NativeGameWebViewBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.devicePixelRatio,
    this.clipLeft,
    this.clipTop,
    this.clipWidth,
    this.clipHeight,
  }) {
    _requireFinite('left', left);
    _requireFinite('top', top);
    _requirePositive('width', width);
    _requirePositive('height', height);
    _requirePositive('devicePixelRatio', devicePixelRatio);
    final clipValues = [clipLeft, clipTop, clipWidth, clipHeight];
    if (clipValues.any((value) => value != null)) {
      if (clipValues.any((value) => value == null)) {
        throw ArgumentError('Clip bounds must contain all four coordinates.');
      }
      _requireFinite('clipLeft', clipLeft!);
      _requireFinite('clipTop', clipTop!);
      _requirePositive('clipWidth', clipWidth!);
      _requirePositive('clipHeight', clipHeight!);
    }
  }

  final double left;
  final double top;
  final double width;
  final double height;
  final double devicePixelRatio;
  final double? clipLeft;
  final double? clipTop;
  final double? clipWidth;
  final double? clipHeight;

  Map<String, double> toMap() => <String, double>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'devicePixelRatio': devicePixelRatio,
    if (clipLeft != null) ...{
      'clipLeft': clipLeft!,
      'clipTop': clipTop!,
      'clipWidth': clipWidth!,
      'clipHeight': clipHeight!,
    },
  };

  static void _requireFinite(String name, double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'must be finite');
    }
  }

  static void _requirePositive(String name, double value) {
    _requireFinite(name, value);
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be greater than zero');
    }
  }
}

enum NativeGameWebViewEventType {
  created,
  pageStarted,
  pageProgress,
  pageFinished,
  presentationChanged,
  mainFrameError,
  resourceError,
  navigationBlocked,
  renderProcessGone,
  destroyed,
}

enum NativeGamePresentationState { pending, web, game }

enum NativeGameWebViewResourceKind { gadget }

final class NativeGameWebViewEvent {
  const NativeGameWebViewEvent._({
    required this.type,
    required this.generationId,
    this.url,
    this.navigationUri,
    this.progress,
    this.errorCode,
    this.description,
    this.resourceKind,
    this.scheme,
    this.didCrash,
    this.isGame,
    this.presentationState,
  });

  final NativeGameWebViewEventType type;
  final int generationId;
  final String? url;
  final Uri? navigationUri;
  final int? progress;
  final int? errorCode;
  final String? description;
  final NativeGameWebViewResourceKind? resourceKind;
  final String? scheme;
  final bool? didCrash;
  final bool? isGame;
  final NativeGamePresentationState? presentationState;

  factory NativeGameWebViewEvent.decode(Object? raw) {
    if (raw is! Map) {
      throw const NativeGameWebViewSchemaException('Event must be a map.');
    }
    final map = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw const NativeGameWebViewSchemaException(
          'Event keys must be strings.',
        );
      }
      map[entry.key as String] = entry.value;
    }

    final typeName = _string(map, 'type');
    final type = _eventTypes[typeName];
    if (type == null) {
      throw const NativeGameWebViewSchemaException('Unknown event type.');
    }
    _requireKeys(
      map,
      _keysForType[type]!,
      optional: switch (type) {
        NativeGameWebViewEventType.presentationChanged => const {'state'},
        NativeGameWebViewEventType.pageProgress => const {'url'},
        NativeGameWebViewEventType.resourceError => const {'resourceKind'},
        _ => const <String>{},
      },
    );
    final generationId = _int(map, 'generationId');
    if (generationId < 0) {
      throw const NativeGameWebViewSchemaException(
        'generationId must be non-negative.',
      );
    }

    switch (type) {
      case NativeGameWebViewEventType.created:
      case NativeGameWebViewEventType.destroyed:
        return NativeGameWebViewEvent._(type: type, generationId: generationId);
      case NativeGameWebViewEventType.pageStarted:
      case NativeGameWebViewEventType.pageFinished:
        final uri = _pageUri(map);
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          url: SafePageAddress.fromRaw(uri.toString()).displayText,
          navigationUri: uri,
        );
      case NativeGameWebViewEventType.pageProgress:
        final progress = _int(map, 'progress');
        if (progress < 0 || progress > 100) {
          throw const NativeGameWebViewSchemaException(
            'progress must be between 0 and 100.',
          );
        }
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          progress: progress,
          url: map.containsKey('url')
              ? SafePageAddress.fromRaw(_pageUri(map).toString()).displayText
              : null,
        );
      case NativeGameWebViewEventType.mainFrameError:
      case NativeGameWebViewEventType.resourceError:
        final resourceKind = switch (map['resourceKind']) {
          'gadget' => NativeGameWebViewResourceKind.gadget,
          _ when !map.containsKey('resourceKind') => null,
          _ => throw const NativeGameWebViewSchemaException(
            'Unknown resourceKind.',
          ),
        };
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          errorCode: _int(map, 'errorCode'),
          description: _string(map, 'description', maxLength: 256),
          resourceKind: resourceKind,
        );
      case NativeGameWebViewEventType.presentationChanged:
        final isGame = map['isGame'];
        if (isGame is! bool) {
          throw const NativeGameWebViewSchemaException(
            'isGame must be a bool.',
          );
        }
        final rawState = map['state'];
        NativeGamePresentationState? state;
        if (map.containsKey('state')) {
          for (final candidate in NativeGamePresentationState.values) {
            if (candidate.name == rawState) state = candidate;
          }
          if (state == null ||
              (state == NativeGamePresentationState.game) != isGame) {
            throw const NativeGameWebViewSchemaException(
              'Invalid presentation state.',
            );
          }
        }
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          isGame: isGame,
          presentationState:
              state ??
              (isGame
                  ? NativeGamePresentationState.game
                  : NativeGamePresentationState.web),
        );
      case NativeGameWebViewEventType.navigationBlocked:
        final scheme = _string(map, 'scheme', maxLength: 32);
        if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]{0,31}$').hasMatch(scheme)) {
          throw const NativeGameWebViewSchemaException(
            'Invalid navigation scheme.',
          );
        }
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          scheme: scheme,
        );
      case NativeGameWebViewEventType.renderProcessGone:
        final didCrash = map['didCrash'];
        if (didCrash is! bool) {
          throw const NativeGameWebViewSchemaException(
            'didCrash must be a bool.',
          );
        }
        return NativeGameWebViewEvent._(
          type: type,
          generationId: generationId,
          didCrash: didCrash,
        );
    }
  }

  static const Map<String, NativeGameWebViewEventType> _eventTypes =
      <String, NativeGameWebViewEventType>{
        'created': NativeGameWebViewEventType.created,
        'pageStarted': NativeGameWebViewEventType.pageStarted,
        'pageProgress': NativeGameWebViewEventType.pageProgress,
        'pageFinished': NativeGameWebViewEventType.pageFinished,
        'presentationChanged': NativeGameWebViewEventType.presentationChanged,
        'mainFrameError': NativeGameWebViewEventType.mainFrameError,
        'resourceError': NativeGameWebViewEventType.resourceError,
        'navigationBlocked': NativeGameWebViewEventType.navigationBlocked,
        'renderProcessGone': NativeGameWebViewEventType.renderProcessGone,
        'destroyed': NativeGameWebViewEventType.destroyed,
      };

  static const Map<NativeGameWebViewEventType, Set<String>> _keysForType =
      <NativeGameWebViewEventType, Set<String>>{
        NativeGameWebViewEventType.created: <String>{'type', 'generationId'},
        NativeGameWebViewEventType.destroyed: <String>{'type', 'generationId'},
        NativeGameWebViewEventType.pageStarted: <String>{
          'type',
          'generationId',
          'url',
        },
        NativeGameWebViewEventType.pageProgress: <String>{
          'type',
          'generationId',
          'progress',
        },
        NativeGameWebViewEventType.pageFinished: <String>{
          'type',
          'generationId',
          'url',
        },
        NativeGameWebViewEventType.presentationChanged: <String>{
          'type',
          'generationId',
          'isGame',
        },
        NativeGameWebViewEventType.mainFrameError: <String>{
          'type',
          'generationId',
          'errorCode',
          'description',
        },
        NativeGameWebViewEventType.resourceError: <String>{
          'type',
          'generationId',
          'errorCode',
          'description',
        },
        NativeGameWebViewEventType.navigationBlocked: <String>{
          'type',
          'generationId',
          'scheme',
        },
        NativeGameWebViewEventType.renderProcessGone: <String>{
          'type',
          'generationId',
          'didCrash',
        },
      };

  static void _requireKeys(
    Map<String, Object?> map,
    Set<String> allowed, {
    Set<String> optional = const <String>{},
  }) {
    if (!allowed.every(map.containsKey) ||
        !map.keys.every(
          (key) => allowed.contains(key) || optional.contains(key),
        )) {
      throw const NativeGameWebViewSchemaException(
        'Event keys do not match schema.',
      );
    }
  }

  static String _string(
    Map<String, Object?> map,
    String key, {
    int maxLength = 2048,
  }) {
    final value = map[key];
    if (value is! String || value.length > maxLength) {
      throw NativeGameWebViewSchemaException('$key must be a short string.');
    }
    return value;
  }

  static Uri _pageUri(Map<String, Object?> map) {
    final uri = Uri.tryParse(_string(map, 'url'));
    if (uri == null || !SafePageAddress.canNavigate(uri)) {
      throw const NativeGameWebViewSchemaException('Event URL is unsafe.');
    }
    return uri;
  }

  static int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw NativeGameWebViewSchemaException('$key must be an int.');
    }
    return value;
  }
}
