import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'release_version.dart';

class AboutDialogWidget extends StatelessWidget {
  const AboutDialogWidget({super.key});

  static const String currentVersion = '1.0.0';
  static const String currentVersionTag = 'v1.0.0';
  static const String repoOwner = 'yamatosaki';
  static const String repoName = 'yahagi-kancolle-browser';
  static const String githubUrl = 'https://github.com/$repoOwner/$repoName';

  Future<void> _checkForUpdates(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      // 1. Fetch latest release from GitHub API
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['tag_name'] as String;
        final releaseName = data['name'] ?? latestTag;
        final releaseNotes = data['body'] ?? (l10n?.noUpdateLog ?? '暂无更新日志');
        final htmlUrl = data['html_url'] as String;

        if (isNewerRelease(latestTag, currentTag: currentVersionTag)) {
          // Found new version!
          _showUpdateDialog(context, releaseName, releaseNotes, htmlUrl);
        } else {
          // Already latest
          _showInfoDialog(
            context,
            l10n?.alreadyLatest ?? '已经是最新版本',
            l10n?.alreadyLatestDesc ?? '当前版本 ($currentVersion) 已经是最新版本。',
          );
        }
      } else if (response.statusCode == 404) {
        _showInfoDialog(
          context,
          l10n?.noRelease ?? '暂无发布版本',
          l10n?.noReleaseDesc ?? 'GitHub 仓库尚未发布任何 Release。',
        );
      } else {
        _showInfoDialog(
          context,
          l10n?.checkFailed ?? '检查失败',
          '无法获取最新版本信息 (状态码: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showInfoDialog(
          context,
          l10n?.networkError ?? '网络错误',
          l10n?.networkErrorDesc ?? '检查更新时发生错误，请稍后重试。',
        );
      }
    }
  }

  void _showUpdateDialog(
    BuildContext context,
    String newVersionName,
    String releaseNotes,
    String htmlUrl,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(
              l10n?.newVersionFound ?? '🚀 发现新版本！',
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
                '${l10n?.currentVersionLabel ?? "当前版本"}: $currentVersion',
                style: const TextStyle(color: Color(0xff8197a5)),
              ),
              Text(
                '${l10n?.latestVersionLabel ?? "最新版本"}: $newVersionName',
                style: const TextStyle(
                  color: Color(0xffd4a85f),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.updateContent ?? '本次更新内容:',
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
              l10n?.later ?? '以后再说',
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
              l10n?.goDownload ?? '前往下载',
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
    final l10n = AppLocalizations.of(context);
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
              l10n?.confirm ?? '确定',
              style: const TextStyle(color: Color(0xffd4a85f)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: const Color(0xff0d1a26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff294052)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      color: const Color(0xffd4a85f).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xffd4a85f).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      l10n?.version ?? '版本 学习版 1.0',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xffd4a85f),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          l10n?.viewOnGitHub ?? '去 GitHub 看看',
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff142735),
                          foregroundColor: const Color(0xff8197a5),
                          side: const BorderSide(color: Color(0xff294052)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.system_update_alt, size: 18),
                        label: Text(l10n?.checkForUpdates ?? '检查更新'),
                        onPressed: () => _checkForUpdates(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Disclaimer
            Container(
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
                        l10n?.disclaimerTitle ?? '免责声明 (DISCLAIMER)',
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
                    '${l10n?.disclaimerP1 ?? "本项目仅供编程技术交流与学习目的使用，是一款完全非盈利且非官方的第三方通用浏览器工具。本项目与 Kantai Collection (KanColle) 官方及任何相关权利方无任何关联。"}\n\n'
                    '${l10n?.disclaimerP2 ?? "本软件不参与、不阻断、不重放且不篡改游戏服务器的通信数据，也不会代替玩家执行游戏操作。原作者不对软件的质量做任何明示或暗示的保证（包括但不限于对软件完全无 Bug、适用性或系统稳定性的保证）。"}\n\n'
                    '${l10n?.disclaimerP3 ?? "在任何情况下，因使用或无法使用本软件而导致的任何移动设备损坏、数据丢失、游戏账号封禁风险或其他任何形式的直接或间接利益损失，原作者均不承担任何法律与连带责任。如果您在\"技术学习\"之外的场景使用本软件，所产生的一切版权争议、服务条款违规及其他风险，均将由使用者自行承担。"}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Color(0xffa0b6c4),
                    ),
                  ),
                ],
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
                l10n?.openSourceLicense ?? '开源协议: MIT License',
                style: const TextStyle(fontSize: 12, color: Color(0xff567080)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
