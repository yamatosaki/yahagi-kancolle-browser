import 'package:flutter/material.dart';

import 'game_dialog_presentation_scope.dart';

double gameDialogPaddingScale(BuildContext context) =>
    1 -
    ((MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0) - 1) *
        2 /
        3;

/// Captures the Flutter dialog theme before an independent native window opens.
/// Font sizes and line heights are already scaled logical pixels, not Android sp.
Map<String, Object?> resolveGameDialogPresentation(BuildContext context) {
  final theme = Theme.of(context);
  final dialog = DialogTheme.of(context);
  final colors = theme.colorScheme;
  final media = MediaQuery.of(context);
  final direction = Directionality.of(context);
  final material3 = theme.useMaterial3;
  final title =
      dialog.titleTextStyle ??
      (material3
          ? theme.textTheme.headlineSmall
          : theme.textTheme.titleLarge) ??
      const TextStyle(fontSize: 24);
  final body =
      dialog.contentTextStyle ??
      (material3 ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium) ??
      const TextStyle(fontSize: 14);
  final action = theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
  final checkbox = theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
  final paddingScale = gameDialogPaddingScale(context);

  Map<String, Object?> text(TextStyle style, double defaultHeight) {
    final size = media.textScaler.scale(style.fontSize ?? 14);
    return {
      'fontSize': size,
      'fontWeight': media.boldText ? 700 : (style.fontWeight?.value ?? 400),
      'lineHeight': size * (style.height ?? defaultHeight),
      'fontFamily': ?style.fontFamily,
    };
  }

  List<double> padding(EdgeInsetsGeometry value) {
    final resolved = value.resolve(direction);
    return [resolved.left, resolved.top, resolved.right, resolved.bottom];
  }

  final shape = dialog.shape;
  final radius = shape is RoundedRectangleBorder
      ? shape.borderRadius.resolve(direction).topLeft.x
      : material3
      ? 28.0
      : 4.0;
  final customFontPath = GameDialogPresentationScope.maybeOf(
    context,
  )?.customFontPath;
  final fontFamily = body.fontFamily ?? title.fontFamily;
  final fontAsset = switch (fontFamily) {
    'HarmonyOS_Sans_SC' => 'assets/fonts/HarmonyOS_Sans_SC.ttf',
    'HarmonyOS_Sans_TC' => 'assets/fonts/HarmonyOS_Sans_TC.ttf',
    'HarmonyOS_Sans' => 'assets/fonts/HarmonyOS_Sans.ttf',
    _ => null,
  };
  return {
    'colors': {
      'surface':
          (dialog.backgroundColor ??
                  (material3 ? colors.surfaceContainerHigh : colors.surface))
              .toARGB32(),
      'onSurface': (dialog.titleTextStyle?.color ?? colors.onSurface)
          .toARGB32(),
      'body': (dialog.contentTextStyle?.color ?? colors.onSurfaceVariant)
          .toARGB32(),
      'primary': colors.primary.toARGB32(),
      'onPrimary': colors.onPrimary.toARGB32(),
      'checkbox': colors.primary.toARGB32(),
      'checkboxCheck': colors.onPrimary.toARGB32(),
      'outline': colors.outline.toARGB32(),
      'error': colors.error.toARGB32(),
      'barrier': (dialog.barrierColor ?? Colors.black54).toARGB32(),
    },
    'text': {
      'title': text(title, 1.33),
      'body': text(body, 1.43),
      'action': text(action, 1.43),
      'checkbox': text(checkbox, 1.5),
    },
    'layout': {
      'insetPadding': padding(
        dialog.insetPadding ??
            const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      ),
      'titlePadding': [
        24.0 * paddingScale,
        24.0 * paddingScale,
        24.0 * paddingScale,
        0.0,
      ],
      'contentPadding': [
        24.0 * paddingScale,
        material3 ? 16.0 : 20.0,
        24.0 * paddingScale,
        24.0,
      ],
      'actionsPadding': padding(
        dialog.actionsPadding ?? const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
      'radius': radius,
      'minWidth': dialog.constraints?.minWidth ?? 280.0,
      'actionMinHeight': 40.0,
      'actionSpacing': 8.0,
      'buttonRadius': 20.0,
    },
    'textDirection': direction.name,
    'customFontPath': ?customFontPath,
    if (customFontPath == null && fontAsset != null) 'fontAsset': fontAsset,
  };
}
