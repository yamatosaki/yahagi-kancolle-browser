<div align="center">
  <img src="assets/app_icon.png" width="128" alt="ヤハギ應用程式圖示">

# ヤハギ（Yahagi KanColle Browser）

**讓艦隊資訊與日常工具陪你一起出擊。**

面向《艦隊 Collection》玩家的行動裝置瀏覽器及資訊輔助工具。

[官方網站](https://yahagi.xyz/?lang=zh-TW) · [下載應用程式](https://github.com/yamatosaki/yahagi-kancolle-browser/releases/latest) · [版本更新](https://github.com/yamatosaki/yahagi-kancolle-browser/releases) · [問題回報](https://github.com/yamatosaki/yahagi-kancolle-browser/issues)

[简体中文](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.md) ｜ 繁體中文 ｜ [日本語](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.ja.md) ｜ [English](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.en.md) ｜ [한국어](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com/)
[![iOS（第三方移植）](https://img.shields.io/badge/Platform-iOS-000000?logo=apple)](https://github.com/yamatosaki/yahagi-kancolle-browser/releases)
[![CI](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml/badge.svg)](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml)

</div>

## 軟體介紹

ヤハギ將遊戲畫面與常用輔助資訊放在一起。遊玩時，可以同步查看艦隊狀態、任務進度、未卜先知戰鬥資訊和航海記錄；準備出擊或安排日常時，也能使用改修規劃、開發計算、遠征檢查、海域查詢及經驗計算等工具。

應用程式支援手機、平板和摺疊螢幕，提供可調整的資訊版面與適合大螢幕裝置的 HD 版面，並支援簡體中文、繁體中文、日語、英語和韓語介面。

遊戲操作始終由玩家自行完成。ヤハギ根據遊戲頁面已經收到的資料整理輔助資訊，不會代替玩家編成、補給、出擊、開發、改修或領取任務。

## 下載與安裝

前往 [GitHub Releases](https://github.com/yamatosaki/yahagi-kancolle-browser/releases/latest) 取得已發布版本、安裝套件和對應的使用說明。

| 平台 | 取得方式與說明 |
| --- | --- |
| Android | 本專案主要維護的版本，在發布頁面下載 APK 安裝。 |
| iOS | 發布頁面提供由 [Kutinana](https://github.com/Kutinana) 製作的第三方移植版 IPA。安裝方式、支援功能和維護情況請以對應版本的發布說明為準。 |

更新 Android 版本時，請優先按照發布說明覆蓋安裝。解除安裝應用程式、清除應用程式資料或更換裝置前，請先匯出需要保留的航海日誌與編成記錄。

## 軟體展示

### 手機、平板與摺疊螢幕

<table>
  <tr>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/phone.png"><img src="docs/images/screenshots/phone.png" alt="手機上的遊戲與輔助資訊版面"></a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/tablet.png"><img src="docs/images/screenshots/tablet.png" alt="平板上的遊戲與輔助資訊版面"></a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/foldable.png"><img src="docs/images/screenshots/foldable.png" alt="摺疊螢幕上的遊戲與輔助資訊版面"></a>
    </td>
  </tr>
  <tr>
    <td align="center">手機</td>
    <td align="center">平板</td>
    <td align="center">摺疊螢幕</td>
  </tr>
</table>

一般版面適用於手機等裝置；HD 版面則適合平板、展開後的摺疊螢幕等較大的視窗。可依裝置尺寸和使用習慣調整資訊區寬度、區塊順序及顯示項目。

### 遊戲與輔助資訊

<table>
  <tr>
    <td width="64%" rowspan="2" align="center" valign="middle">
      <a href="docs/images/screenshots/battle.png"><img src="docs/images/screenshots/battle.png" width="100%" alt="遊戲畫面與未卜先知戰鬥資訊"></a>
      <br><strong>遊戲與戰鬥輔助</strong>
    </td>
    <td width="36%" align="center">
      <a href="docs/images/screenshots/fleet.png"><img src="docs/images/screenshots/fleet.png" width="100%" alt="艦隊與裝備資訊"></a>
      <br>艦隊資訊
    </td>
  </tr>
  <tr>
    <td width="36%" align="center">
      <a href="docs/images/screenshots/quests.png"><img src="docs/images/screenshots/quests.png" width="100%" alt="任務清單與任務資訊"></a>
      <br>任務中心
    </td>
  </tr>
</table>

## 功能概覽

| 功能 | 可以做什麼 |
| --- | --- |
| 艦隊與戰鬥輔助 | 查看艦隊狀態、制空與索敵資訊，使用未卜先知查看戰鬥過程與結果預測，進行出擊狀態檢查。 |
| 任務中心 | 查詢任務說明、獎勵與前後置關係，篩選任務，追蹤部分任務的分項進度。 |
| 艦娘與裝備 | 瀏覽持有與未持有圖鑑，篩選、排序並查看裝備裝載情況，查詢艦娘與裝備的適裝關係。 |
| 日常規劃 | 查詢改修安排與消耗，計算開發配方與機率，檢查遠征條件並估算收益。 |
| 戰果與養成 | 查看戰果記錄與日曆，規劃戰果目標，計算升級經驗與出擊次數，儲存養成追蹤。 |
| 編成與海域 | 儲存編成和陸航記錄，匯出編成圖與外部工具資料，查詢海域路線、節點和敵艦資料。 |
| 日誌與備份 | 查看六類航海記錄與資源趨勢，篩選戰鬥詳情，匯出、同步和還原日誌及編成記錄。 |
| 行動裝置體驗 | 自訂介面與資源欄，使用完成提醒、背景倒數計時、遊戲資源快取及滑鼠相容性設定。 |

### 艦隊與未卜先知

- 查看艦娘等級、耐久、疲勞度、燃料、彈藥、裝備及艦隊彙整資訊。
- 查看制空、索敵等參考資訊，以及遠征、入渠、建造和泊地修理狀態。
- 支援通常艦隊與聯合艦隊的戰鬥資訊，顯示敵我耐久變化、戰果等級及 MVP 預測。
- 提供出擊前狀態檢查、大破提醒和戰前敵艦資訊顯示。

未卜先知根據遊戲頁面已經收到的戰鬥資料整理資訊，官方結算到達後會更新為正式結果。預測與狀態提示供玩家參考，請搭配遊戲畫面判斷。

### 任務中心

- 瀏覽已接受任務與任務資料，依類型、週期等條件篩選和搜尋。
- 查看任務說明、基礎獎勵、前置與後續任務，方便安排任務順序。
- 追蹤部分任務的分項進度，並提供完成提示。
- 支援任務資料更新。

部分任務進度依據本機觀察與記錄推算；尚未被應用程式觀察到的進度可能不完整。

### 艦娘與裝備

- 分類查看持有與未持有艦娘、裝備，依條件篩選與排序。
- 查看裝備的改修、熟練度和裝載情況。
- 從裝備查詢可裝備的艦娘，也可從艦娘查詢可用裝備，並區分一般裝備欄與增設裝備欄。

### 改修、開發與遠征規劃

- **改修規劃：** 依星期、裝備分類、關鍵字與收藏查詢，查看二番艦條件、消耗及進化路線。
- **開發計算：** 依秘書艦與投入資源查詢目標裝備的開發機率，也可依目標裝備反查配方。
- **遠征檢查：** 檢查艦種、等級、裝備、補給和士氣等條件，估算大成功率、收益及完成時間。

### 戰果與經驗規劃

- 查看本機戰果資訊、出擊記錄與戰果日曆。
- 結合 EO 與任務戰果獎勵規劃目標，估算剩餘戰果及每日需求。
- 依海域、路線、勝利評價、旗艦和 MVP 等條件計算經驗，估算升級所需出擊次數。
- 儲存艦娘養成目標，持續查看經驗與等級進度。

戰果與經驗計算依據已記錄的資料和設定條件進行估算。

### 編成記錄與海域資料

- 儲存目前艦隊與陸航編成，依名稱、海域等條件尋找記錄。
- 匯出高解析度編成圖，方便分享和整理攻略。
- 匯出 DeckBuilder 資料，或主動開啟制空權模擬器、Jervis 等外部工具繼續計算。
- 查看海域路線圖、節點類型、敵方編成、陣形、經驗和制空參考；點擊敵艦可查看詳細資料。
- 海域、敵艦等資料支援在應用程式內獨立檢查更新。

儲存的編成用於查閱與分享，遊戲內的編成操作仍由玩家完成。海域與敵艦資料可能隨遊戲更新而變動，請以遊戲內實際情況為準。

### 航海日誌、資源趨勢與備份

- 儲存出擊、遠征、建造、開發、除籍和資源六類記錄。
- 依日期、海域和狀態等條件篩選出擊記錄，查看節點與戰鬥詳情。
- 查看各類資源的存量趨勢、區間變化與歷史記錄。
- 支援為目前帳號匯出、分享和還原航海日誌與編成記錄，也可選擇文件資料夾進行背景同步與手動同步。

記錄從應用程式實際觀察到的資料開始累積。備份範圍是航海日誌與編成記錄，不包含登入帳號密碼、登入 Cookie 或全部應用程式設定。

### 介面、提醒與遊戲快取

- 支援全螢幕、畫面適配、資訊區調整與首頁區塊編輯，可調整順序、隱藏區塊並還原預設版面。
- 可自訂部分艦隊簡報與頂部資源欄項目。
- 提供遠征、入渠、建造、泊地修理及疲勞相關提醒與倒數計時顯示。
- 提供遊戲資源快取與本機快取下載，支援暫停、繼續、完整性檢查和清理。
- 支援畫面與幀率選項、外接滑鼠操作及滑鼠滾輪相容性設定。

提醒與背景執行會受到系統權限和省電策略影響。資源快取用於減少重複載入，遊玩時仍需連線至遊戲伺服器。

## 開始使用

1. 從發布頁面下載安裝套件，按照對應版本的說明安裝並開啟應用程式。
2. 選擇連線方式，在遊戲頁面自行完成登入。需要時可設定系統網路、HTTP Proxy 或 SOCKS5 Proxy。
3. 進入母港，讓應用程式收到艦隊與帳號資料後，再查看艦隊、任務、倉庫等輔助頁面。
4. 依裝置尺寸調整版面，並視需要設定通知、快取與記錄備份。

應用程式提供兩種執行模式：

- **遊戲資訊模式：** 讀取遊戲頁面已經收到的 API 回應，啟用艦隊、任務、戰鬥與日誌等輔助功能。
- **純瀏覽模式：** 關閉 API 資訊讀取，僅在應用程式內瀏覽和操作遊戲頁面。

除了 DMM 入口，應用程式也提供實驗性的 OOI 第三方連線入口。使用 OOI 時，登入憑證會提交給該第三方服務，請依應用程式內說明確認後再使用。

## 資料與隱私

輔助記錄主要儲存在裝置本機，無需額外註冊應用程式雲端帳號。不同功能的資料處理方式如下：

| 項目 | 資料處理方式 |
| --- | --- |
| 航海日誌與編成記錄 | 儲存在本機；由使用者選擇匯出、還原或同步到指定文件資料夾。 |
| 匿名裝置與使用統計 | 使用 TelemetryDeck 統計匿名裝置資訊和目前渲染模式等使用情況，預設開啟，可在設定中關閉。 |
| KCWiki 資料貢獻 | 預設關閉；在版本和設定支援時，由使用者自行選擇是否啟用。 |
| 診斷檔案 | 由使用者手動儲存或透過系統分享面板傳送，應用程式不會自動上傳診斷檔案。 |

用於輔助分析的遊戲 API 資訊會清理 api_token、api_starttime 等敏感參數。記錄備份不包含登入 Cookie；登入狀態仍可能由系統 WebView 按其預設機制儲存在裝置上。

## 交流與回饋

歡迎分享使用體驗、相容性問題和功能建議。

我可以使用中文、英文和日語交流，歡迎用這些語言聯絡我。

- **QQ 群：1104904097**
- **聯絡信箱：yamatosaki123[AT] gmail.com**
- **問題回報：** [GitHub Issues](https://github.com/yamatosaki/yahagi-kancolle-browser/issues)

回報問題時，請盡量說明應用程式版本、裝置型號、系統版本、重現步驟及相關截圖，方便定位。

## 開放原始碼與貢獻

ヤハギ以開放原始碼的方式開發，歡迎提交 Issue、Pull Request，參與功能改進、相容性測試、文件與本地化。

從原始碼建置或執行測試，請參閱 [原始碼建置與驗證（簡體中文）](BUILDING.md)，也可透過 Fork 後的 GitHub Actions 自行打包。修改介面、資源或開發獨立版本，請參閱 [客製化與二次開發（簡體中文）](CUSTOMIZING.md)。參與開發前請閱讀 [貢獻指南](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/CONTRIBUTING.md) 和 [安全政策](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/SECURITY.md)。

專案原始碼使用 [MIT License](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/LICENSE)。第三方字型、相依套件與資產說明見 [THIRD_PARTY_NOTICES](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/THIRD_PARTY_NOTICES)。

## 免責聲明

ヤハギ是社群開發的非官方工具，與《艦隊 Collection》營運方、開發方、DMM 及相關權利方不存在隸屬、授權或合作關係。

使用者應自行了解並遵守相關服務條款，並承擔使用第三方工具可能產生的帳號、網路與相容性風險。遊戲名稱、商標及第三方素材的相關權利歸各自權利人所有。

## 致謝

特別感謝 [POI 瀏覽器](https://github.com/poooi/poi) 專案及其開放原始碼社群，在資料組織、功能設計和社群協作方面為本專案提供的參考與啟發。

感謝 [Kutinana](https://github.com/Kutinana) 製作和提供 iOS 第三方移植版本。

同時感謝 Flutter、WebView Flutter 及各相依套件的維護者，以及每一位參與測試、回報問題和貢獻程式碼的提督。

ヤハギ是獨立開發的專案，專案觀點與實作不代表上述專案或社群的官方立場。

## 贊助支持

[透過 GitHub Sponsors 支持 Yahagi](https://github.com/sponsors/yamatosaki)

也可以透過支付寶或微信支持專案，點擊 QR Code 可檢視原圖。

| 支付寶 | 微信支付 |
| :---: | :---: |
| <a href="docs/images/sponsors/alipay.jpg"><img src="docs/images/sponsors/alipay.jpg" width="220" alt="支付寶贊助收款碼"></a> | <a href="docs/images/sponsors/wechat-pay.png"><img src="docs/images/sponsors/wechat-pay.png" width="220" alt="微信支付贊助收款碼"></a> |

感謝您對 Yahagi 專案的支持！❤️

您的贊助是對我莫大的鼓勵，也是我持續開發和改進這個開源專案的重要動力。

衷心感謝您的支持！
