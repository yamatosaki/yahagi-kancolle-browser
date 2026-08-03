import 'dart:async';

import 'package:flutter/material.dart';

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
class OperationCountdownText extends StatefulWidget {
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
  State<OperationCountdownText> createState() => _OperationCountdownTextState();
}

class _OperationCountdownTextState extends State<OperationCountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.completionTime != null) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(OperationCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completionTime != widget.completionTime) {
      _timer?.cancel();
      _timer = null;
      if (widget.completionTime != null) {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final completed = operationIsCompleted(widget.completionTime);
      if (completed) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completionTime = widget.completionTime;
    if (completionTime == null) {
      return const SizedBox.shrink();
    }
    final remaining = completionTime.difference(DateTime.now().toUtc());
    final isCompleted = operationIsCompleted(completionTime);
    final baseStyle =
        widget.style ??
        const TextStyle(
          color: Color(0xffffc940),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        );
    final color = isCompleted
        ? (widget.completedColor ?? const Color(0xff64c894))
        : (widget.countingColor ?? baseStyle.color);
    return Text(
      isCompleted ? widget.completedText : formatOperationDuration(remaining),
      maxLines: widget.maxLines,
      textAlign: widget.textAlign,
      style: baseStyle.copyWith(
        color: color,
        fontFeatures: widget.fontFeatures,
      ),
    );
  }
}
