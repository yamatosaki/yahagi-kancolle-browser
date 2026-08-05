import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'release_check_service.dart';

class AboutDialogWidget extends StatelessWidget {
  const AboutDialogWidget({
    super.key,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
  });

  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  static const String repoOwner = 'yamatosaki';
  static const String repoName = 'yahagi-kancolle-browser';
  static const String githubUrl = 'https://github.com/$repoOwner/$repoName';

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
      builder: (context) => AlertDialog(
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
                style: const TextStyle(color: Color(0xff8197a5)),
              ),
              Text(
                '${l10n.latestVersionLabel}: $newVersionName',
                style: const TextStyle(
                  color: Color(0xffd4a85f),
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
                  color: const Color(0xff081521),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  releaseNotes,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xffa0b6c4),
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xff142735),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.later,
              style: const TextStyle(color: Color(0xff8197a5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.parse(htmlUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              l10n.goDownload,
              style: const TextStyle(
                color: Color(0xffd4a85f),
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
        backgroundColor: const Color(0xff142735),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.confirm,
              style: const TextStyle(color: Color(0xffd4a85f)),
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
    return Dialog(
      backgroundColor: const Color(0xff0d1a26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff294052)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: MediaQuery.sizeOf(context).height - 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const Key('about-content-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xff3c586b),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'ヤハギ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xffd4a85f,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xffd4a85f,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              l10n.version.replaceFirst(
                                RegExp(r'\d+(?:\.\d+){1,2}'),
                                currentVersion,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xffd4a85f),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xffd4a85f),
                                  foregroundColor: const Color(0xff081521),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(Icons.code, size: 18),
                                label: Text(
                                  l10n.viewOnGitHub,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () async {
                                  final uri = Uri.parse(githubUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff142735),
                                  foregroundColor: const Color(0xff8197a5),
                                  side: const BorderSide(
                                    color: Color(0xff294052),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.system_update_alt,
                                  size: 18,
                                ),
                                label: Text(l10n.checkForUpdates),
                                onPressed: () => _checkForUpdates(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Disclaimer
                    Container(
                      key: const Key('about-disclaimer-scroll'),
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xff0a131c),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Color(0xff8197a5),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.disclaimerTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff8197a5),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${l10n.disclaimerP1}\n\n${l10n.disclaimerP2}\n\n'
                            '${l10n.disclaimerP3}',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: Color(0xffa0b6c4),
                            ),
                          ),
                          const SizedBox(key: Key('about-disclaimer-end')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xff142735))),
                color: Color(0xff0d1a26),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.openSourceLicense,
                style: const TextStyle(fontSize: 12, color: Color(0xff567080)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
