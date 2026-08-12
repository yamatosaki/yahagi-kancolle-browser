import 'package:flutter/material.dart';

import '../performance/second_tick_scope.dart';

double operationProgress({
  required DateTime now,
  required DateTime start,
  required DateTime end,
}) {
  final totalMilliseconds = end.difference(start).inMilliseconds;
  if (totalMilliseconds <= 0) {
    return 0;
  }
  final elapsedMilliseconds = now.difference(start).inMilliseconds;
  return (elapsedMilliseconds / totalMilliseconds).clamp(0, 1);
}

bool operationIsCompleted(DateTime? completionTime, {DateTime? now}) {
  if (completionTime == null) {
    return false;
  }
  return !(now ?? DateTime.now().toUtc()).isBefore(completionTime);
}

String formatOperationDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// 自驱动倒计时文本，每秒刷新一次，只重建自身。
class OperationCountdownText extends StatelessWidget {
  const OperationCountdownText({
    super.key,
    this.completionTime,
    this.completedText = '00:00:00',
    this.completedColor,
    this.countingColor,
    this.style,
    this.textAlign,
    this.maxLines,
    this.fontFeatures,
  });

  final DateTime? completionTime;

  /// 倒计时归零后显示的文本（如“已归还”“已完成”）。
  final String completedText;

  final Color? completedColor;
  final Color? countingColor;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final List<FontFeature>? fontFeatures;

  @override
  Widget build(BuildContext context) {
    final completionTime = this.completionTime;
    if (completionTime == null) {
      return const SizedBox.shrink();
    }
    return SecondTickBuilder(
      enabled: !operationIsCompleted(completionTime),
      stopAt: completionTime,
      builder: (context, now, _) => _buildText(completionTime, now),
    );
  }

  Widget _buildText(DateTime completionTime, DateTime now) {
    final remaining = completionTime.difference(now);
    final isCompleted = operationIsCompleted(completionTime, now: now);
    final baseStyle =
        style ??
        const TextStyle(
          color: Color(0xffffc940),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        );
    final color = isCompleted
        ? (completedColor ?? const Color(0xff64c894))
        : (countingColor ?? baseStyle.color);
    return Text(
      isCompleted ? completedText : formatOperationDuration(remaining),
      maxLines: maxLines,
      textAlign: textAlign,
      style: baseStyle.copyWith(color: color, fontFeatures: fontFeatures),
    );
  }
}
