<div align="center">
  <img src="assets/app_icon.png" width="128" alt="ヤハギ應用程式圖示">

# ヤハギ（Yahagi KanColle Browser）

面向行動裝置的《艦隊 Collection》非官方瀏覽器及本機資訊輔助工具。

<p>
  <strong>🌐 其他語言 / Other Languages:</strong><br>
  <a href="README.md">简体中文</a> ｜
  <strong>繁體中文</strong> ｜
  <a href="README.ja.md">日本語</a>
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com/)
[![CI](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml/badge.svg)](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml)

</div>

## 軟體介紹

ヤハギ（Yahagi）是一款以 Flutter 和 Android System WebView 開發的《艦隊 Collection》行動裝置瀏覽器及本機資訊輔助工具。遊戲網頁由 Android System WebView（Chromium）載入，瀏覽、登入、Cookie 和頁面互動方式與同一裝置上的 Chrome 接近；受系統 WebView 與 Chrome 版本差異影響，實際行為可能略有不同。

應用程式只讀取遊戲頁面已經收到的 `/kcsapi/` 回應，用於在裝置本機產生輔助資訊和日誌。它不會自動填寫帳號、點擊頁面、編成艦隊、補給、出擊或領取任務，所有遊戲操作仍由玩家本人完成。

## 軟體展示

### 裝置適配

<table>
  <tr>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/phone.png">
        <img src="docs/images/screenshots/phone.png" alt="一般手機橫向顯示">
      </a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/tablet.png">
        <img src="docs/images/screenshots/tablet.png" alt="平板橫向顯示">
      </a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/foldable.png">
        <img src="docs/images/screenshots/foldable.png" alt="摺疊螢幕裝置展示">
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">一般手機</td>
    <td align="center">平板</td>
    <td align="center">摺疊螢幕裝置</td>
  </tr>
</table>

ヤハギ針對平板橫向顯示、摺疊螢幕裝置，以及遊戲畫面與資訊面板並排使用的情境最佳化版面配置。目前更推薦在平板和摺疊螢幕裝置上使用。一般手機同樣可以執行，但受螢幕尺寸限制，首頁能夠同時顯示的輔助資訊不如大螢幕裝置完整。

### 遊戲與戰鬥輔助

點擊圖片可查看原圖。

<table>
  <tr>
    <td width="64%" rowspan="2" align="center" valign="middle">
      <a href="docs/images/screenshots/battle.png">
        <img src="docs/images/screenshots/battle.png" width="100%" alt="戰鬥畫面與即時輔助資訊並排顯示">
      </a>
      <br><strong>遊戲與戰鬥輔助</strong>
    </td>
    <td width="36%" align="center" valign="middle">
      <a href="docs/images/screenshots/fleet.png">
        <img src="docs/images/screenshots/fleet.png" width="100%" alt="編隊資訊展示">
      </a>
      <br>編隊資訊
    </td>
  </tr>
  <tr>
    <td width="36%" align="center" valign="middle">
      <a href="docs/images/screenshots/quests.png">
        <img src="docs/images/screenshots/quests.png" width="100%" alt="任務資訊展示">
      </a>
      <br>任務資訊
    </td>
  </tr>
</table>

## 執行模式

應用程式提供兩種可隨時切換的執行模式：

- **遊戲資訊模式：** 讀取遊戲頁面已經收到的 `/kcsapi/` 回應，啟用下方列出的本機輔助功能。
- **純瀏覽模式：** 關閉介面資訊讀取，只使用 WebView 開啟和操作遊戲頁面，適合只想在應用程式內遊玩遊戲的情境。

無論使用哪一種模式，應用程式都不會代替玩家執行遊戲操作。

## 核心功能

### 遊戲瀏覽

- 使用 Android System WebView 載入 DMM 登入頁面和遊戲頁面。
- 提供返回、重新整理、首頁、靜音和畫面適配等常用控制。
- 系統自動旋轉關閉時預設保持橫向；開啟後會隨裝置方向在橫向和直向之間切換。
- 首頁功能卡片支援長按拖曳，可自由調整顯示順序。
- 支援簡體中文、繁體中文和日文介面。

### 艦隊與作業狀態

- 查看艦隊成員、等級、耐久、疲勞度、燃料、彈藥和裝備。
- 彙整速度、火力、雷裝、對空、對潛、制空和索敵等艦隊資訊。
- 顯示遠征、入渠和建造狀態及剩餘時間。
- 提供出擊前狀態檢查，協助發現需要留意的艦隊狀態。

### 任務資訊

- 顯示已接受任務、完成狀態、類型、週期和伺服器可確認的進度區間。
- 提供任務列表與詳細說明，並顯示基礎獎勵。
- 在裝置本機保留經過解析和去識別化的任務資訊。

### 戰鬥輔助與日誌

- 記錄航海節點、敵我艦隊、交戰狀態和耐久變化。
- 根據遊戲頁面已經收到的資料顯示戰鬥過程、戰果等級和 MVP 預測。
- 在官方結算回應到達後，將預測更新為正式結果。
- 支援通常艦隊與聯合艦隊，並在裝置本機儲存戰鬥記錄。

### 網路與本機資料

- 支援系統網路、HTTP Proxy 和 SOCKS5 Proxy。
- 輔助資料儲存在裝置本機，不需要額外註冊雲端帳號。
- 支援應用程式內版本檢查，並從 GitHub Releases 取得最新版本資訊。

## 資料與安全邊界

- 真實網頁導覽只允許 DMM 與艦隊伺服器的 HTTPS 來源。
- 原生擷取橋接只接受白名單來源和 `/kcsapi/` 路徑。
- 頁面端、Android 端和 Dart 端會清理 `api_token`、`api_starttime` 等敏感參數。
- 應用程式不會讀取或匯出 Cookie、登入表單和完整請求標頭。
- 擷取邏輯不會阻擋、重播或修改遊戲通訊，也不會代替玩家操作遊戲。
- Android System WebView 仍可能依照系統預設行為儲存登入 Cookie。

## 取得應用程式

請前往 [GitHub Releases](https://github.com/yamatosaki/yahagi-kancolle-browser/releases) 查看已發行版本和安裝套件。

## 未來開發計畫

目前作者預想的主要功能已經基本完成，但專案仍可能存在尚未發現或測試涵蓋不足的 Bug。歡迎透過 Issue 分享使用回饋、相容性問題和功能建議；作者會依照實際情況繼續修改、最佳化和更新。

iOS 版本目前處於規劃階段。由於作者暫時沒有 Mac 及其他 iOS 開發環境裝置，相關開發和測試仍需要一段時間。

HarmonyOS 版本也可能在未來進行可行性研究，但目前尚無明確的開發計畫和時程。

## 開放原始碼與貢獻

ヤハギ以開放原始碼方式開發。歡迎透過以下方式參與專案：

- 提交 Issue，回報錯誤或提出功能建議。
- 提交 Pull Request，改善功能、相容性、文件或本地化。
- 在不同 Android 裝置和 WebView 版本上測試，並回報執行情況。

參與開發前請閱讀 [貢獻指南](CONTRIBUTING.md) 和 [安全政策](SECURITY.md)。

專案原始碼使用 [MIT License](LICENSE)。第三方字型、相依套件及其他資產的說明請見 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES)。

## 免責聲明

ヤハギ是由社群開發的非官方工具，與《艦隊 Collection》營運方、開發方、DMM 及相關權利人不存在隸屬、授權或合作關係。

使用者應自行了解並遵守相關服務條款，並承擔使用第三方工具可能產生的帳號、網路和相容性風險。遊戲名稱、商標及第三方素材的相關權利歸各自權利人所有。

## 致謝

特別感謝 [POI 瀏覽器](https://github.com/poooi/poi) 專案及其開放原始碼社群。POI 長期透過開放原始碼推動《艦隊 Collection》社群工具的發展，在資料組織、功能設計和社群協作等方面為本專案提供了寶貴的參考與啟發。

同時感謝 Flutter、WebView Flutter 及本專案所有相依套件的維護者，也感謝每一位參與測試、回報問題和貢獻程式碼的使用者。

ヤハギ是獨立開發的專案，專案觀點與實作不代表上述專案或社群的官方立場。
