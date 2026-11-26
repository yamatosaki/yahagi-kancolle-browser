# Yahagi v1.10 Stable Release Notes

[简体中文](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.10/README.md) ｜ [繁體中文](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.10/README.zh-Hant.md) ｜ [日本語](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.10/README.ja.md) ｜ English ｜ [한국어](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/docs/releases/1.10/README.ko.md)

[Back to this release / Download installation files](https://github.com/yamatosaki/yahagi-kancolle-browser/releases/tag/1.10)

---

Yahagi now supports **Kanxy mods** on Android, tracks **sortie EXP and MVP awards for each ship**, and shows **transport points (TP)** for your fleet. This release also fixes compatibility issues with **in-game Chinese translation packs** and improves the experience on phones, tablets, and foldables.

On Android, **install v1.10 directly over v1.0.9 or any previously released v1.10 beta**. Keep the existing app installed so you retain your app data.

Thanks to GitHub user [@Kutinana](https://github.com/Kutinana) for independently developing the third-party iOS 1.10 port.

**Installing on iOS**

You can sideload the IPA or join the port author's **public TestFlight beta**. If you sideload with a free personal Apple developer account, TestFlight saves you from having to re-sign the app every **7 days** and makes it easier to receive beta updates.

- **Build expiration.** Each TestFlight build is available for up to **90 days** from the date the developer uploads it. Check the expiration date in TestFlight and look for an update from the port author before your build expires.
- **Tester capacity.** TestFlight allows up to **10,000 external testers**. Check the invitation page to see whether a place is available.
- **Installation.** Install Apple's **TestFlight** app from the App Store, then follow the invitation to install Yahagi. [Join the iOS public beta](https://testflight.apple.com/join/WWU4StEm)

For iOS features, compatibility, and updates, refer to the port author's notes for the build you are using.

## 1. New features and improvements

### 1. Kanxy mods on Android

Yahagi can load game resources through Kanxy's VPN or local HTTP proxy. If you switch connections during play, Yahagi waits until the game is in the foreground and confirms that you are back at home port before reloading.

**For first-time setup, configure Kanxy first, then Yahagi.**

1. **Choose your mod packs in Kanxy.** Open Kanxy's mod settings, enable mods, and download or select the packs you want. We recommend also enabling Kanxy's resource cache. If Kanxy asks you to install a certificate, follow its instructions.
2. **Enable Kanxy's HTTP proxy.** Note the address and port it displays. If both apps are on the same phone, use `127.0.0.1` in Yahagi and enter the port shown in Kanxy.
3. **Connect Yahagi.** Under **Settings → Network & connection**, select **HTTP proxy**, enter the address and port, and tap **Apply settings and reload game**. **Temporary cache** is usually sufficient for the original game resources. Kanxy images have their own cache, and Yahagi pauses predownloads of original resources while connected through Kanxy.

**Switching Kanxy mod packs**

Select the new pack in Kanxy and disable the one it replaces. In Yahagi, open **Settings → Data management → Local game resource cache** and tap **Clear Kanxy cache and reload the game**. If the title screen appears, tap **GAME START**. When you keep using the same packs, you can enter the game as usual.

**Using Kanxy alongside local Yahagi mods**

If both replace the same image, Yahagi displays the image from its local pack. To use Kanxy's image, disable the corresponding resource under **Toolbox → Mods** in Yahagi, tap **Apply & reload game**, then follow the pack-switching steps above.

### 2. Sortie EXP and MVP counts for each ship

- The standard and HD layouts can both show the **Sortie EXP** summary. After a sortie or practice battle, check each ship's EXP gain, progress toward its next level, and MVP count. For combined fleets, the main and escort fleets appear separately.
- The new **EXP** tab in the Logbook lets you revisit the fleet and ship details for each sortie and practice battle. To track EXP and MVP totals over time, turn on **Total** in the summary for the current account. This setting is off by default. The Logbook saves EXP records independently of it.
- Record backups now include Logbook EXP records and remain compatible with older backups. Entries with missing data are labeled **Partial record**.

### 3. Fleet transport points and status at a glance

- The fleet summary shows TP for both **Normal transport** and **Tank transport**. Open the details to compare the estimates for S-rank and A-rank victories. For combined fleets, you can also see how much the first and second fleets each contribute, plus any applicable Kinu Kai Ni bonus. TP is also shown on fleet composition images and in saved fleet compositions.
- Fleet tabs use color to distinguish sorties, practice, expeditions, and fleets awaiting resupply. When a fleet returns from an expedition, Yahagi waits for the latest fuel and ammunition figures before flagging it for resupply. The fleet summary and ship details also switch to damaged artwork when a ship takes moderate or heavy damage.

### 4. Chinese translation pack fixes and ZIP updates

Switching Chinese translation packs now applies the new font correctly. Import a supported ZIP under **Toolbox → Mods** to replace interface images and fonts and translate quest titles, quest descriptions, game text, and BGM track titles, depending on what the pack contains. You can import **the `Kancolle_to_CHS` v1.4.0 release ZIP** directly and check which resources were recognized in the import preview. [Kancolle_to_CHS project thread](https://bbs.nga.cn/read.php?tid=44139718)

When a translation or artwork pack gets an update, open the installed pack's details and select **Update from ZIP** to preview which resources the update adds or removes. Yahagi keeps your selections for existing resources, the pack's on/off setting, and its priority. New supported resources are selected by default. Review the changes, then tap **Apply & reload game**.

Android's media gallery now skips assets in the shared mod folder, helping keep ship artwork out of your gallery.

### 5. Choose when the fleet summary updates during battle

Under **Settings → Sortie & battle → Battle prediction → Fleet information sync**, choose when the fleet summary updates ship HP and damage control usage.

- **Immediate (default)** updates the summary as soon as battle data arrives, including while the battle is in progress.
- **After battle results** waits for the current battle's result, so you see the changes at the same point as in the game.

### 6. Startup checks are on by default

When you enter the game, the startup indicator moves through **Connection**, **Entry page**, and **Game startup** in order. If loading stalls, you can keep waiting or reload. If the connection fails, you can view and copy the failed stage, host, and error code, or dismiss the message.

You can turn **Startup checks** off or back on under **Settings → Game runtime**.

### 7. The Quest Center lists fleets that meet composition requirements

The quest list highlights progress milestones reported by the game server, such as **50% or 80%**. In quest details, the server milestone appears above Yahagi's local count so you can compare the progress confirmed by the game with the number of actions Yahagi has recorded.

For quests whose composition requirements Yahagi can check, the details list which of your first four fleets qualify. This release also fixes cases where sortie and practice counts were mixed up, ships in a combined fleet's escort fleet were evaluated incorrectly, or a boss node was misidentified.

### 8. Individual controls for sortie, expedition, and result notifications

Top-of-screen notifications now have **12 separate switches**. You can keep heavy damage, resupply, and capacity warnings on while turning off notices such as equipment development, equipment improvement, practice EXP, or quest completion.

When you open the sortie or expedition screen, Yahagi checks the relevant fleets for heavy damage and missing fuel or ammunition and shows warnings according to your settings. After an expedition departs, Yahagi warns that it **may fail** if the fleet composition falls short of the known success requirements.

## 2. Fixes and usability improvements

- **Battle prediction and battle records.** You can toggle the area minimap, enemy fleet preview, and predicted results separately. Battle records now recognize carrier night attack cut-ins, several destroyer night cut-ins, the Zuiun Multi-Angle Attack, and the Sea/Air Multi-Angle Attack. Some combined-fleet night battle special attacks were credited to the wrong ship. The records now show the correct ship.
- **Game display and controls.** The game is centered below the top bar at its original aspect ratio. Scaling and touch alignment are more accurate after resizing a split-screen window, rotating the device, or switching to or from full screen. Temporarily showing the system bars causes less jitter. Mouse-wheel input is more responsive, and Yahagi restores the mute setting more reliably when you return to the app or the game view is recreated.
- **Summaries and Toolbox.** The repair dock summary shows fuel and steel costs alongside the estimated completion time. Map lookup keeps the zoom level and enemy fleet details when you change pages or rotate the screen. Display options for the in-game panels are now grouped, and you can check for updates to map, enemy ship, quest, equipment improvement, and subtitle data directly from the data management page.
- **Language and messages.** The Traditional Chinese, Japanese, English, and Korean translations have been checked against the Simplified Chinese text. Messages now distinguish equipped damage control from damage control that has activated, and terms such as minimum fleet morale are consistent. Messages in the pre-battle enemy preview, mod library scan, and backup restore also follow the selected app language.

## 3. Usage notes

- To translate the game into Chinese, import a supported translation pack yourself.
- TP estimates use your current fleet and equipment. Tank transport follows the rules for the summer 2026 event. Check the in-game results for the actual TP deducted, quest completion, and expedition outcomes.

Thank you to all admirals for your continued feedback and support!
