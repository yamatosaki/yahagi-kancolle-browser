import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../widgets/top_notice.dart';
import 'release_check_service.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

class AboutContentWidget extends StatelessWidget {
  const AboutContentWidget({
    super.key,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
    this.externalUrlLauncher,
    this.supportSection,
  });

  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ExternalUrlLauncher? externalUrlLauncher;
  final Widget? supportSection;
  static const String repoOwner = 'yamatosaki';
  static const String repoName = 'yahagi-kancolle-browser';
  static const String githubUrl = 'https://github.com/$repoOwner/$repoName';
  static const String websiteUrl = 'https://yahagi.xyz/';

  Future<void> _openExternalUrl(BuildContext context, Uri uri) async {
    var launched = false;
    try {
      launched =
          await (externalUrlLauncher?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      launched = false;
    }
    if (launched || !context.mounted) return;

    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    TopNotice.show(
      context,
      message: l10n.externalLinkOpenFailed,
      tone: TopNoticeTone.error,
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final result = await (releaseChecker ?? GitHubReleaseChecker()).check(
      currentVersion: currentVersion,
    );
    if (!context.mounted) return;
    switch (result) {
      case UpdateAvailable():
        _showUpdateDialog(
          context,
          result.releaseName,
          result.releaseNotes.isEmpty ? l10n.noUpdateLog : result.releaseNotes,
          result.releaseUrl,
        );
      case AlreadyLatest():
        _showInfoDialog(context, l10n.alreadyLatest, l10n.alreadyLatestDesc);
      case ReleaseCheckFailed():
        _showInfoDialog(context, l10n.checkFailed, l10n.networkErrorDesc);
    }
  }

  void _showUpdateDialog(
    BuildContext context,
    String newVersionName,
    String releaseNotes,
    String htmlUrl,
  ) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Text(
              l10n.newVersionFound,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.currentVersionLabel}: $currentVersion',
                style: TextStyle(color: appColor(context, Color(0xff8197a5))),
              ),
              Text(
                '${l10n.latestVersionLabel}: $newVersionName',
                style: TextStyle(
                  color: appColor(context, Color(0xffd4a85f)),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.updateContent,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: appColor(context, Color(0xff081521)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  releaseNotes,
                  style: TextStyle(
                    fontSize: 13,
                    color: appColor(context, Color(0xffa0b6c4)),
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: appColor(context, Color(0xff142735)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.later,
              style: TextStyle(color: appColor(context, Color(0xff8197a5))),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _openExternalUrl(context, Uri.parse(htmlUrl));
            },
            child: Text(
              l10n.goDownload,
              style: TextStyle(
                color: appColor(context, Color(0xffd4a85f)),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: Text(
          content,
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
        backgroundColor: appColor(context, Color(0xff142735)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.confirm,
              style: TextStyle(color: appColor(context, Color(0xffd4a85f))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff122431)),
        border: Border.all(color: appColor(context, const Color(0xff294052))),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                Widget buildIdentity() => Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appColor(context, const Color(0xff3c586b)),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: appColor(context, Colors.black38),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ヤハギ',
                            style: appTextStyle(
                              context,
                              TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: appColor(
                                context,
                                const Color(0xffd4a85f).withValues(alpha: 0.1),
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: appColor(
                                  context,
                                  const Color(
                                    0xffd4a85f,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            child: Text(
                              l10n.version.replaceFirst(
                                RegExp(r'\d+(?:\.\d+){1,2}'),
                                currentVersion,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: appColor(context, Color(0xffd4a85f)),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                Widget buildWebsiteButton({double? width}) => SizedBox(
                  width: width,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColor(
                        context,
                        const Color(0xff142735),
                      ),
                      foregroundColor: appColor(
                        context,
                        const Color(0xffd4a85f),
                      ),
                      side: BorderSide(
                        color: appColor(context, Color(0xff294052)),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.language, size: 18),
                    label: Text(l10n.officialWebsite),
                    onPressed: () async {
                      await _openExternalUrl(context, Uri.parse(websiteUrl));
                    },
                  ),
                );

                Widget buildGitHubButton({double? width}) => SizedBox(
                  width: width,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColor(context, Color(0xffd4a85f)),
                      foregroundColor: appOnAccentColor(
                        context,
                        const Color(0xff081521),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.code, size: 18),
                    label: Text(
                      l10n.viewOnGitHub,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      await _openExternalUrl(context, Uri.parse(githubUrl));
                    },
                  ),
                );

                Widget buildUpdateButton({double? width}) => SizedBox(
                  width: width,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColor(context, Color(0xff142735)),
                      foregroundColor: appColor(context, Color(0xff8197a5)),
                      side: BorderSide(
                        color: appColor(context, Color(0xff294052)),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.system_update_alt, size: 18),
                    label: Text(l10n.checkForUpdates),
                    onPressed: () => _checkForUpdates(context),
                  ),
                );

                final isCompact = constraints.maxWidth < 520;
                final actionWidth = constraints.maxWidth < 360
                    ? constraints.maxWidth
                    : null;
                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: isCompact
                      ? WrapAlignment.start
                      : WrapAlignment.end,
                  children: [
                    buildWebsiteButton(width: actionWidth),
                    buildGitHubButton(width: actionWidth),
                    buildUpdateButton(width: actionWidth),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildIdentity(),
                      const SizedBox(height: 16),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: buildIdentity()),
                    const SizedBox(width: 16),
                    Flexible(child: actions),
                  ],
                );
              },
            ),
          ),

          ?supportSection,
          // Disclaimer
          Container(
            key: const Key('about-disclaimer-scroll'),
            padding: const EdgeInsets.all(20),
            color: appColor(context, Color(0xff0a131c)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: appColor(context, Color(0xff8197a5)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.disclaimerTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: appColor(context, Color(0xff8197a5)),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${l10n.disclaimerP1}\n\n${l10n.disclaimerP2}\n\n'
                  '${l10n.disclaimerP3}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: appColor(context, Color(0xffa0b6c4)),
                  ),
                ),
                const SizedBox(key: Key('about-disclaimer-end')),
              ],
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: appColor(context, Color(0xff294052))),
              ),
              color: appColor(context, Color(0xff0d1a26)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            alignment: Alignment.center,
            child: Text(
              l10n.openSourceLicense,
              style: TextStyle(
                fontSize: 12,
                color: appColor(context, Color(0xff567080)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
