import 'package:shared_preferences/shared_preferences.dart';

import 'capture_mode.dart';

abstract interface class CaptureModeStore {
  Future<CaptureMode?> read();

  Future<void> write(CaptureMode mode);
}

final class SharedPreferencesCaptureModeStore implements CaptureModeStore {
  static const _key = 'capture_mode';

  @override
  Future<CaptureMode?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return CaptureMode.fromStorageValue(preferences.getString(_key));
  }

  @override
  Future<void> write(CaptureMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, mode.storageValue);
    if (!saved) {
      throw StateError('capture mode was not saved');
    }
  }
}
