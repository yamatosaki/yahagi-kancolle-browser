import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../audio/game_audio_controller.dart';
import '../audio/game_audio_feedback.dart';
import 'settings_ui_helpers.dart';

class SoundSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const SoundSettingsPage({super.key, required this.audioController});

  final GameAudioController audioController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildSectionTitle(l10n.gameAndSound),
            buildCard(
              child: AnimatedBuilder(
                animation: audioController,
                builder: (context, _) => Column(
                  children: <Widget>[
                    buildSwitchTile(
                      title: l10n.gameSound,
                      value: !audioController.isMuted,
                      subtitle: switch (audioController.errorMessage) {
                        final error? => gameAudioErrorText(context, error),
                        null => null,
                      },
                      onChanged: audioController.canToggle
                          ? (_) => audioController.toggleMuted()
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
