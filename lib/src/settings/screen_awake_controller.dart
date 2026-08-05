import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ScreenAwakeStore {
  Future<bool?> readEnabled();

  Future<void> writeEnabled(bool enabled);
}

final class SharedPreferencesScreenAwakeStore implements ScreenAwakeStore {
  static const _key = 'screen_awake_enabled';

  @override
  Future<bool?> readEnabled() async {
    return (await SharedPreferences.getInstance()).getBool(_key);
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _key,
      enabled,
    );
    if (!saved) {
      throw StateError('screen awake preference was not saved');
    }
  }
}

abstract interface class ScreenAwakePort {
  Future<void> setEnabled(bool enabled);

  Future<bool> isEnabled();
}

final class MethodChannelScreenAwakePort implements ScreenAwakePort {
  const MethodChannelScreenAwakePort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/screen_awake',
    ),
  ]);

  final MethodChannel channel;

  @override
  Future<bool> isEnabled() async {
    return await channel.invokeMethod<bool>('isEnabled') ?? false;
  }

  @override
  Future<void> setEnabled(bool enabled) {
    return channel.invokeMethod<void>('setEnabled', <String, Object?>{
      'enabled': enabled,
    });
  }
}

final class ScreenAwakeController extends ChangeNotifier {
  ScreenAwakeController._(this._store, this._enabled);

  static Future<ScreenAwakeController> load(ScreenAwakeStore store) async {
    return ScreenAwakeController._(store, await store.readEnabled() ?? false);
  }

  final ScreenAwakeStore _store;
  ScreenAwakePort? _port;
  bool _enabled;
  bool _foreground = true;
  bool? _lastApplied;
  String? _errorMessage;

  bool get enabled => _enabled;
  String? get errorMessage => _errorMessage;
  bool get _effectiveEnabled => _enabled && _foreground;

  Future<void> attachPort(ScreenAwakePort port) async {
    _port = port;
    _lastApplied = null;
    try {
      await _apply();
    } catch (error) {
      _errorMessage = '屏幕常亮不可用：$error';
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) {
      return;
    }
    final previous = _enabled;
    _enabled = enabled;
    _errorMessage = null;
    notifyListeners();
    try {
      await _store.writeEnabled(enabled);
      await _apply();
    } catch (error) {
      _enabled = previous;
      _errorMessage = '屏幕常亮设置失败：$error';
      await _store.writeEnabled(previous);
      try {
        _lastApplied = null;
        await _apply();
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) {
      return;
    }
    _foreground = foreground;
    try {
      await _apply();
    } catch (error) {
      _errorMessage = '屏幕常亮同步失败：$error';
      notifyListeners();
    }
  }

  Future<void> _apply() async {
    final port = _port;
    final target = _effectiveEnabled;
    if (port == null || _lastApplied == target) {
      return;
    }
    await port.setEnabled(target);
    final actual = await port.isEnabled();
    if (actual != target) {
      throw StateError('native window flag did not match requested state');
    }
    _lastApplied = actual;
    _errorMessage = null;
    notifyListeners();
  }
}
