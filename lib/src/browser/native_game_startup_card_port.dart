import 'package:flutter/foundation.dart';

abstract interface class NativeGameStartupCardPort {
  Future<void> setStartupCard(NativeGameStartupCardData? card);
}

@immutable
final class NativeGameStartupCardData {
  const NativeGameStartupCardData({
    required this.title,
    this.stage,
    this.requests,
    this.pageProgress,
    this.stalled = false,
  }) : assert(
         pageProgress == null || (pageProgress >= 0 && pageProgress <= 100),
       );

  final String title;
  final String? stage;
  final String? requests;
  final int? pageProgress;
  final bool stalled;

  Map<String, Object> toMap() => <String, Object>{
    'title': title,
    'stage': ?stage,
    'requests': ?requests,
    'pageProgress': ?pageProgress,
    'stalled': stalled,
  };

  @override
  bool operator ==(Object other) =>
      other is NativeGameStartupCardData &&
      title == other.title &&
      stage == other.stage &&
      requests == other.requests &&
      pageProgress == other.pageProgress &&
      stalled == other.stalled;

  @override
  int get hashCode =>
      Object.hash(title, stage, requests, pageProgress, stalled);
}
