import 'dart:isolate';

import 'battle_prediction_engine.dart';

typedef BattlePredictionAppendResult = ({
  BattlePredictionEngine engine,
  BattlePrediction prediction,
});

abstract interface class BattlePredictionExecutor {
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  });
}

final class IsolateBattlePredictionExecutor
    implements BattlePredictionExecutor {
  const IsolateBattlePredictionExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) {
    return Isolate.run(() {
      final prediction = engine.append(path: path, data: data);
      return (engine: engine, prediction: prediction);
    });
  }
}
