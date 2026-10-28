import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../widgets/top_notice.dart';
import 'settings_ui_helpers.dart';

/// Opens the existing controls in a full page, preserving their settings style.
Future<void> openSettingsDetail(
  BuildContext context, {
  required String title,
  required Widget child,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => _SettingsDetailPage(title: title, child: child),
  ),
);

class _SettingsDetailPage extends StatelessWidget with SettingsUIHelpers {
  const _SettingsDetailPage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => TopNoticeHost(
    child: Scaffold(
      backgroundColor: appColor(context, const Color(0xff0d1a26)),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appColor(context, const Color(0xff0d1a26)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: buildCard(child: child),
      ),
    ),
  );
}
