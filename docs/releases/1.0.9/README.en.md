# Yahagi v1.0.9 Stable Release Notes

[简体中文](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.0.9/README.md) ｜ [繁體中文](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.0.9/README.zh-Hant.md) ｜ [日本語](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.0.9/README.ja.md) ｜ English ｜ [한국어](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.0.9/README.ko.md)

[Back to this release / Download installation files](https://github.com/yamatosaki/yahagi-kancolle-browser/releases/tag/1.0.9)

---

Compared with v1.0.8, this update focuses on **mod resource management, ship voice subtitles, and more interface customization options**. It also adds a **minimap to Battle prediction**, with extensive improvements to the Quest Center, battle reminders, ranking point statistics, and record backup, while continuing to improve the experience on phones, tablets, and foldables.

The Android version supports **direct in-place upgrades from v1.0.8 and previously released v1.0.9 Beta versions**. There is no need to uninstall the old version before installation. Please do not uninstall it, as doing so may cause the loss of data stored in the app.

**Thank you as well to GitHub user [@Kutinana](https://github.com/Kutinana) for making an iOS 1.0.9 port. This version was independently ported and produced by a third party.**

**Additional iOS installation options:**

In addition to the existing **IPA sideloading option**, the port's author now provides a **public TestFlight beta**. For users sideloading with a free Apple personal developer account, installing through TestFlight avoids the need to re-sign every 7 days and makes it easier to receive subsequent beta updates.

- **Build expiration:** Each TestFlight beta build is available for up to **90 days** from the date the developer uploads it. Check the expiration shown in TestFlight for the exact time remaining, and watch for updates from the port's author before the build expires.
- **Tester capacity:** TestFlight external testing supports up to **10,000 testers**. Available places and whether you can join depend on the invitation page's status at the time.
- **How to install:** First install Apple's official **TestFlight** app from the App Store, then use the link below to join the beta and install the app.

**Public TestFlight beta: [Join the iOS public beta](https://testflight.apple.com/join/WWU4StEm)**

For the iOS port's specific features, compatibility, and future updates, refer to the port author's notes and the actual version provided.

## 1. New features and main improvements

### 1. Mod resource management

Added **Mods** to the Toolbox, allowing you to import and manage supported resource packs locally on your device to replace ship artwork, voices, and the corresponding position settings in the game.

- Import mod packs in ZIP format, or select a local resource folder to scan for ZIP files and extracted directories and import them in bulk.
- Select normal artwork, damaged artwork, position settings, and voice resources separately, and manage which packs are enabled and their priority.
- Use **Apply and refresh game** to apply your changes together. Changes that have not yet been applied can be canceled.
- View processing progress during import, scanning, and application to check the current status.
- Sync ship portraits from applied mods to the fleet summary, ship details, and ship inventory, keeping ship displays in the app consistent with the game.
- Disable mods or restore original resources while preserving existing login information, regular game cache, settings, and records.

Mod resources must use supported formats and paths. When packs contain overlapping resources, the configured priority determines which resources take effect. The import precheck explains what is supported and identifies unsupported items.

### 2. Ship voice subtitles

Added **Ship voice subtitles**, displaying the corresponding lines when a ship's voice plays in the game to make the dialogue easier to read and understand.

- Supports five subtitle languages: **Simplified Chinese, Traditional Chinese, Japanese, English, and Korean**.
- Choose a subtitle language independently of the app's interface language.
- Choose from small, medium, and large text sizes. After unlocking the interface, drag the handle to adjust the subtitle position.
- The subtitle position is saved and retained when you turn the feature back on or resize the window.
- Long lines are displayed in pages based on voice duration to reduce text extending beyond the game display.
- Subtitle data is included, with an option to check for updates in Settings. When subtitles are enabled, the app also checks for data updates periodically.

Subtitles are disabled by default and can be enabled manually in Settings. Subtitle data updates download dialogue and name text; they do not include game voice files.

### 3. Interface customization and mobile layout improvements

This update adds more appearance and display options, allowing you to adjust the interface to your preferences on phones, small windows, and larger devices.

**New minimal interface and tabbed summary:**

- Added a **Minimal** interface option alongside the existing Normal and Compact options, reducing the space taken up by controls and improving information display on smaller screens.
- Added a simpler, flat information panel style.
- The summary in the Normal layout now offers a **Tabbed** view. Switch between modules using tabs to reduce vertical scrolling, or continue using the existing collapsible view.

**New themes and custom fonts:**

- Added two light themes, **Sea Salt Teal and Clear Sky Blue**, alongside the original dark appearance.
- Import TTF and OTF fonts, preview and apply them, or restore the default font.
- Set interface density and text size separately. Text size can follow the system setting or use small, medium, or large presets.

**Improved screen adaptation:**

- Added camera, notch, and hole-punch clearance settings, with adjustable spacing to suit your device.
- Improved layouts for split-screen mode, short windows, narrow screens, and enlarged text, reducing clipped content, overlap, and crowded controls.

### 4. English and Korean interfaces

Added **English and Korean interfaces** alongside the existing Simplified Chinese, Traditional Chinese, and Japanese options.

- Added English and Korean names for ships, equipment, ship types, equipment categories, and more.
- Applied the corresponding name translations to fleet, inventory, quest, development, improvement, and experience calculator pages.
- Relevant searches recognize the supported original and translated names, making information easier to find across languages.
- Translation data can be updated. Content without a corresponding translation continues to display its original name.

Name translations apply to Yahagi's companion interface. They do not change in-game data, resource paths, or the original content of exported data.

### 5. Quest Center and progress tracking improvements

Quest information lookup and local progress tracking continue to improve, making it easier to find quests, check requirements, and plan prerequisite and follow-up quests.

- Reorganized search and filters, bringing keyword, type, cycle, and status criteria together and showing a preview of the number of matches before applying them.
- Improved quest ID lookup and added support for finding related quests using ship and equipment names in the display language.
- Quest details are divided into **Requirements and progress, Rewards, and Related quests** tabs, with more complete displays of resource, text-described, and selectable rewards.
- Expand prerequisites to trace quest dependencies, and return to the original quest after viewing a related one, making quest chains easier to follow.
- Expanded the built-in local progress rules to **432 quests**, with an independent option in Settings to check for and install rule updates.
- Corrected some ship, ship type, map node, and accompanying ship requirements, and improved cycle resets, progress saving, and rule retention after upgrades.

Local progress is accumulated from data the app actually observes. Some quests still provide reference counts only. Check the in-game status to confirm completion and whether rewards can be claimed.

### 6. Minimap in Battle prediction

Battle prediction now includes a **minimap**, showing the current map's nodes and routes during a sortie so you can check your route alongside battle information.

- Shows the current node and the route already traveled during the current sortie, based on captured sortie data.
- Displays the minimap alongside live battle information, without needing to switch to the Toolbox lookup page.
- Supports expanding and collapsing and adapts to information panels of different widths to save space on smaller devices.
- Adjusted node labels and route layouts to reduce obscured text and misread routes.

The minimap uses the game data and map information obtained so far. If map information is temporarily unavailable or data capture is incomplete, the display may also be incomplete. Check it against the game display.

### 7. Heavy damage reminders and battle information improvements

Building on the existing battle assistance and heavy damage reminders, this update improves damage control information, reminder timing, and in-game notice presentation.

- Heavy damage reminders list the relevant ships together and check both regular equipment slots and reinforcement expansion slots for **remaining Emergency Repair Personnel and Emergency Repair Goddesses**.
- Distinguishes between ships without damage control, ships with remaining damage control, and ships whose status cannot be confirmed, making it easier to check their condition.
- Enable **reminders after battle results and reminders after advancing** separately or together.
- Choose Always confirm or Smart reminders. Smart reminders use remaining damage control and data reliability to decide between a top-of-screen notice and a confirmation dialog.
- Mute reminders for the current sortie, and access manual game refresh and game frame refresh from the reminder.
- Battle prediction now marks damage control activations at the current node, making it easier to check damage control use during the battle.
- Added notices related to event mechanics and armor debuffs. When the game returns a relevant trigger or weakening signal, the app can show a dialog or top-of-screen notice.

Heavy damage, new ship, and other notices also display more reliably over the Android native game view, reducing issues such as reminders being hidden behind the game and the game display freezing after a dialog appears.

### 8. Ranking point statistics and record backup improvements

Continued improving the accuracy of ranking point records, the calendar, and goal calculations, while expanding the scope of record backups.

- Improved ranking point records from experience, EO, and quest rewards, correcting some duplicate entries, delayed updates, and month-end attribution issues.
- Improved recognition of quest ranking point rewards, reducing cases where ranking points were incorrectly recorded after another reward was selected.
- Corrected calculations for the ranking point calendar, today's remaining goal, and daily requirements, reducing repeated deductions caused by ranking refreshes or plan adjustments.
- Moved base ranking point entry and reset controls together on the ranking point information page for easier review and adjustment.
- Record backups now include **the current account's ranking point archive**, preserving more records in addition to the existing logbook and fleet composition records.
- Improved backup merging, saving, restoration, and handling of interruptions, while maintaining compatibility with existing backup files.

## 2. Fixes and experience improvements

- **Game display and browsing:** Improved OOI game entry detection and native game view adaptation, with better scaling, cropping, and recovery on tablets, in split-screen mode, and in short windows.
- **Dialogs and refreshes:** Fixed some game display freezes caused by dialogs and refresh operations, improving game playback and interaction while notices are displayed.
- **Battle prediction:** Improved state recovery after data capture interruptions and the display of unconfirmed states, with better battle information synchronization and refreshing.
- **Notifications and background operation:** Improved background persistence and recovery, and restoration of valid scheduled reminders after device restarts, app upgrades, or relevant permission changes.
- **Logbook:** Improved filtering and pagination for expedition, construction, development, and scrapping records, reducing issues where older records were excluded from filtering or the browsing position was lost after a refresh.
- **Toolbox and data updates:** Improved name displays, filter controls, and narrow-screen layouts on development, improvement, expedition, experience calculator, and other pages, reducing interface stuttering caused by some data processing operations.
- **Interface and settings:** Updated the app icon and top branding, reorganized Settings categories, and unified the appearance of themes, toggles, and filter controls.
- **Other fixes:** Corrected some proxy routing, cache recovery, account switching, and record saving issues, with further improvements to overall stability.

## 3. Usage notes

- **There is no need to uninstall the old version for an in-place upgrade.** If you plan to change devices, uninstall the app, or clear its data, first export the records you want to keep and confirm that the backup file has been saved.
- Mods only support resource packs that meet the requirements. Check the import precheck results before applying them to the game. Keeping your original resource packs and font files is recommended.
- Voice subtitles require the game to generate the corresponding voice playback events. Subtitles may not appear if game voices are completely disabled. Some older system WebView versions may also need updating.
- Local quest progress, ranking point estimates, the minimap, and battle notices are aids for reviewing information. Refer to the actual in-game display for the final status.
- Heavy damage reminders cannot intercept advance requests that have already been sent and do not retreat automatically. Carrying damage control does not remove the need to check the in-game status.
- Event mechanic and armor debuff reminders indicate relevant signals returned by the game. They do not provide a complete guide to event mechanics or mean that every armor debuff requirement has been completed.
- Record backups currently include the logbook, fleet composition records, and ranking point archive. They still do not provide a complete migration of app data and settings.
- Background reminders remain subject to system permissions, power-saving policies, and the device's background app management.

Thank you to all admirals for your continued feedback and support!

With mods, subtitles, and more flexible interface settings, v1.0.9 aims to make Yahagi better suited to different players' preferences. We will continue improving existing features and device compatibility based on your feedback.
