# Customization and Development

[简体中文](CUSTOMIZING.md) ｜ English

Follow [Building and Verifying from Source](BUILDING.en.md) to complete a debug build before making changes. A normal APK build uses the asset snapshots in this repository. It does not depend on the maintainer's private backups, caches, or data-fetching setup.

## Customization Without Rebuilding

- App settings provide themes, fonts, information layouts, dashboard modules, header resources, reminders, and subtitles.
- Import a compatible ZIP under Toolbox → Mods to replace supported game images or voices. See the [mod package guide (Chinese)](docs/game-mods.md) for the format and limitations. These packages do not execute custom Dart or Kotlin code.
- See [game name translations (Chinese)](docs/game-name-localization.md) and [voice subtitles (Chinese)](docs/ship-voice-subtitles.md) for their data sources and display behavior.

Modify the source when adding features, changing default behavior, or distributing an independent app.

## Common Source Entry Points

| Change | Entry point and notes |
| --- | --- |
| Startup and module wiring | [`lib/main.dart`](lib/main.dart); feature implementations live under `lib/src/`. |
| Themes, colors, and fonts | [`lib/src/theme/`](lib/src/theme/); declare new bundled fonts in `pubspec.yaml`. |
| Interface text | `lib/l10n/app_*.arb`; run `flutter gen-l10n` after editing ARB files. Do not edit only the generated `app_localizations*.dart` files. Some dynamic text lives in `lib/src/localization/` or module-specific string files. |
| Native Android dialogs, notifications, and WebViews | [`android/app/src/main/kotlin/app/yahagi/kancollebrowser/`](android/app/src/main/kotlin/app/yahagi/kancollebrowser/); native notification text includes `notification/NotificationStrings.kt` and does not all come from Flutter ARB files. |
| Icon and app display name | `assets/app_icon.png` and `flutter_icons` in `pubspec.yaml`; run `dart run flutter_launcher_icons` after changing the icon. The launcher label is `android:label` in `android/app/src/main/AndroidManifest.xml`. |
| Version | `version` in [`pubspec.yaml`](pubspec.yaml), using `versionName+increasingBuildNumber`; keep version-related tests consistent. |
| Bundled quest, map, enemy, and subtitle data | [`assets/data/`](assets/data/); source data and release procedures are documented in [`data/sortie/README.md`](data/sortie/README.md), [`data/enemy/README.md`](data/enemy/README.md), and the relevant data license notices. |
| Dart/Android communication | Dart `*_port.dart` files and native `MethodChannel` handlers. Change both ends and the relevant tests when changing channel names or parameters. |

Commit new assets and declare them in `pubspec.yaml`; check asset declarations when adding subdirectories. Runtime behavior must not depend on machine-specific absolute paths, uncommitted files, or development caches.

The app uses Flutter and native Android code. It currently has no stable external code plugin API. New features generally require source changes and a rebuild; mod ZIPs cover supported game asset replacements.

## Install Alongside the Official App

Change `defaultConfig.applicationId` in `android/app/build.gradle.kts` to a unique ID you control, such as `org.example.yahagi.custom`. For this installation-ID change, you can keep the existing `namespace` and Kotlin `package` declarations without migrating all native source packages.

Use your own display name, icon, and signing key, then rebuild. Different application IDs have separate data and do not automatically inherit the official app's login state or records. Use the existing record export/restore feature if you need to migrate supported records. See [Release Signing](BUILDING.en.md#release-signing) for creating and using a personal release key.

## Configuration for Independent Distribution

Some defaults still point to this project or upstream data sources after you fork it. Review these locations before distributing your own version:

| Configuration | Source location |
| --- | --- |
| App update checks | The default `GitHubReleaseChecker.endpoint` in `lib/src/settings/release_check_service.dart` and its construction in `lib/main.dart`. It checks this project's Releases by default. Use your own release source or remove the corresponding update entry. |
| About, feedback, and release links | Repository constants in `lib/src/settings/about_dialog.dart` and localized text. Use your own name and contact links while retaining required attribution. |
| Anonymous usage statistics | The default TelemetryDeck App ID in `lib/src/telemetry/telemetry_service.dart` and `AppTelemetryService` construction in `lib/main.dart`. For independent distribution, use your own ID or pass `telemetryDeckAppID: null` when constructing the service to disable reporting. This public ID identifies a statistics project; it is not a signing or build secret. |
| Map and enemy online data updates | Both `*_update_service.dart` files under `lib/src/toolbox/sortie_map_query/`, plus `data/sortie/manifest.json` and `data/enemy/manifest.json`. When hosting your own data, update manifests, download locations, versions, and SHA-256 values together, and review the client's download URL validation. |
| Quest, improvement, subtitle, and name translation updates | The relevant module's `*_update_service.dart` files. If you customize bundled data, decide whether upstream online data should replace it. Retain format validation, integrity checks, and failure fallbacks. |

These settings currently live in source code; there is no unified `--dart-define` configuration interface. Do not copy the maintainer's signing key or any account tokens into your fork. Building the APK does not require private information.

## Validate Your Changes

Run tests for the area you changed, then complete the public checks and APK build in the [build guide](BUILDING.en.md#verification-commands). For native interaction changes, also check the affected dialogs, notifications, or WebView behavior on Android hardware.

When maintaining map or enemy data, use `dart run tool/verify_data_release.dart --local-only` to check local artifacts first. The full online verification accesses published assets. Python and Pillow are needed for these data tools, not as prerequisites for building an APK.

Before committing, run `python tool/check_repository_hygiene.py --working-tree` to check for accidental local paths, logs, backups, or signing material. See [LICENSE](LICENSE) for the source license and [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) for third-party code, font, and data licenses and attribution requirements.
