<div align="center">
  <img src="assets/app_icon.png" width="128" alt="ヤハギ 앱 아이콘">

# ヤハギ（Yahagi KanColle Browser）

**함대 정보와 일상 도구를 곁에 두고 출격하세요.**

《함대 컬렉션》 플레이어를 위한 모바일 브라우저 및 정보 보조 도구입니다.

[공식 웹사이트](https://yahagi.xyz/?lang=ko) · [앱 다운로드](https://github.com/yamatosaki/yahagi-kancolle-browser/releases/latest) · [업데이트 내역](https://github.com/yamatosaki/yahagi-kancolle-browser/releases) · [문제 제보](https://github.com/yamatosaki/yahagi-kancolle-browser/issues)

[简体中文](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.md) ｜ [繁體中文](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.zh-Hant.md) ｜ [日本語](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.ja.md) ｜ [English](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/README.en.md) ｜ 한국어

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com/)
[![iOS(서드파티 이식판)](https://img.shields.io/badge/Platform-iOS-000000?logo=apple)](https://github.com/yamatosaki/yahagi-kancolle-browser/releases)
[![CI](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml/badge.svg)](https://github.com/yamatosaki/yahagi-kancolle-browser/actions/workflows/ci.yml)

</div>

## 앱 소개

ヤハギ는 게임 화면과 자주 사용하는 보조 정보를 한곳에서 보여 줍니다. 플레이 중에는 함대 상태, 임무 진행도, 전투 예측과 항해 일지를 함께 확인할 수 있습니다. 출격을 준비하거나 일상 플레이 계획을 세울 때는 개수 계획, 개발 계산, 원정 점검, 해역 조회, 경험치 계산 등의 도구를 사용할 수 있습니다.

스마트폰, 태블릿, 폴더블 기기를 지원하며, 정보 배치를 조정할 수 있는 레이아웃과 대화면 기기에 적합한 HD 레이아웃을 제공합니다. 인터페이스 언어는 중국어 간체, 중국어 번체, 일본어, 영어, 한국어를 지원합니다.

게임 조작은 항상 플레이어가 직접 수행합니다. ヤハギ는 게임 페이지가 이미 받은 데이터를 정리해 보조 정보를 제공하며, 플레이어를 대신해 편성, 보급, 출격, 개발, 개수 또는 임무 수락을 수행하지 않습니다.

## 다운로드 및 설치

[GitHub Releases](https://github.com/yamatosaki/yahagi-kancolle-browser/releases/latest)에서 공개된 버전, 설치 파일 및 해당 버전의 사용 안내를 확인하세요.

| 플랫폼 | 다운로드 및 안내 |
| --- | --- |
| Android | 이 프로젝트에서 주로 유지·관리하는 버전입니다. 릴리스 페이지에서 APK를 다운로드해 설치할 수 있습니다. |
| iOS | [Kutinana](https://github.com/Kutinana) 님이 제작한 서드파티 이식판 IPA를 릴리스 페이지에서 제공합니다. 설치 방법, 지원 기능 및 유지·관리 현황은 해당 버전의 릴리스 설명을 확인해 주세요. |

Android 버전을 업데이트할 때는 릴리스 설명에 따라 기존 앱 위에 설치하는 방법을 우선 이용해 주세요. 앱을 삭제하거나 앱 데이터를 지우거나 기기를 바꾸기 전에는 보관할 항해 일지와 편성 기록을 먼저 내보내세요.

## 앱 화면

### 스마트폰, 태블릿 및 폴더블 기기

<table>
  <tr>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/phone.png"><img src="docs/images/screenshots/phone.png" alt="스마트폰의 게임 및 보조 정보 레이아웃"></a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/tablet.png"><img src="docs/images/screenshots/tablet.png" alt="태블릿의 게임 및 보조 정보 레이아웃"></a>
    </td>
    <td width="33%" align="center">
      <a href="docs/images/screenshots/foldable.png"><img src="docs/images/screenshots/foldable.png" alt="폴더블 기기의 게임 및 보조 정보 레이아웃"></a>
    </td>
  </tr>
  <tr>
    <td align="center">스마트폰</td>
    <td align="center">태블릿</td>
    <td align="center">폴더블 기기</td>
  </tr>
</table>

일반 레이아웃은 스마트폰 등에 적합하며, HD 레이아웃은 태블릿이나 펼친 폴더블 화면처럼 창이 큰 환경을 위한 것입니다. 기기 크기와 사용 방식에 맞춰 정보 패널의 너비, 모듈 순서 및 표시 항목을 조정할 수 있습니다.

### 게임 및 보조 정보

<table>
  <tr>
    <td width="64%" rowspan="2" align="center" valign="middle">
      <a href="docs/images/screenshots/battle.png"><img src="docs/images/screenshots/battle.png" width="100%" alt="게임 화면 및 전투 예측 정보"></a>
      <br><strong>게임 및 전투 보조</strong>
    </td>
    <td width="36%" align="center">
      <a href="docs/images/screenshots/fleet.png"><img src="docs/images/screenshots/fleet.png" width="100%" alt="함대 및 장비 정보"></a>
      <br>함대 정보
    </td>
  </tr>
  <tr>
    <td width="36%" align="center">
      <a href="docs/images/screenshots/quests.png"><img src="docs/images/screenshots/quests.png" width="100%" alt="임무 목록 및 상세 정보"></a>
      <br>임무 센터
    </td>
  </tr>
</table>

## 주요 기능

| 기능 | 설명 |
| --- | --- |
| 함대 및 전투 보조 | 함대 상태, 제공 및 색적 정보를 확인하고, 전투 예측으로 전투 진행과 예상 결과를 살펴보며 출격 전 상태를 점검합니다. |
| 임무 센터 | 임무 설명, 보상, 선행·후속 임무를 조회하고 임무를 필터링하며 일부 임무의 세부 진행도를 추적합니다. |
| 칸무스 및 장비 | 보유·미보유 도감을 살펴보고, 필터링과 정렬로 장비 장착 현황 및 칸무스별 장착 가능 장비를 확인합니다. |
| 일상 플레이 계획 | 개수 일정과 소모량을 조회하고, 개발 레시피와 확률을 계산하며, 원정 조건을 점검하고 수익을 예상합니다. |
| 전과 및 육성 | 전과 기록과 달력을 확인하고, 전과 목표를 계획하며, 레벨업 경험치와 출격 횟수를 계산하고 육성 진행도를 저장합니다. |
| 편성 및 해역 | 함대와 기지항공대 편성을 저장하고, 편성 이미지 및 외부 도구용 데이터를 내보내며, 해역 경로, 지점 및 적 함선 정보를 조회합니다. |
| 일지 및 백업 | 여섯 종류의 항해 기록과 자원 추이를 확인하고, 전투 상세 정보를 필터링하며, 일지와 편성 기록을 내보내고 동기화하거나 복원합니다. |
| 모바일 사용 환경 | 인터페이스와 자원 표시줄을 맞춤 설정하고, 완료 알림, 백그라운드 타이머, 게임 리소스 캐시 및 마우스 호환 설정을 사용합니다. |

### 함대 및 전투 예측

- 칸무스의 레벨, 내구도, 피로도, 연료, 탄약, 장비 및 함대 요약 정보를 확인합니다.
- 제공, 색적 등의 참고 정보와 원정, 입거, 건조, 정박지 수리 상태를 확인합니다.
- 일반 함대와 연합함대의 전투 정보를 지원하며, 아군과 적군의 내구도 변화, 예상 승리 등급 및 MVP를 표시합니다.
- 출격 전 상태 점검, 대파 경고 및 전투 전 적 함선 정보 표시 기능을 제공합니다.

전투 예측은 게임 페이지가 이미 받은 전투 데이터를 정리해 보여 주며, 서버의 전투 결과가 도착하면 확정 결과로 갱신합니다. 예측과 상태 안내는 참고용이므로 게임 화면과 함께 확인해 주세요.

### 임무 센터

- 수락한 임무와 임무 자료를 살펴보고, 유형과 주기 등의 조건으로 필터링하거나 검색합니다.
- 임무 설명, 기본 보상, 선행 및 후속 임무를 확인해 수행 순서를 계획합니다.
- 일부 임무의 세부 진행도를 추적하고 완료 알림을 제공합니다.
- 임무 자료 업데이트를 지원합니다.

일부 임무의 진행도는 기기에서 관찰하고 기록한 데이터를 바탕으로 추정합니다. 앱이 아직 관찰하지 못한 진행 상황은 반영되지 않을 수 있습니다.

### 칸무스 및 장비

- 보유·미보유 칸무스와 장비를 분류별로 확인하고, 조건에 따라 필터링하거나 정렬합니다.
- 장비의 개수, 숙련도 및 장착 현황을 확인합니다.
- 장비에서 장착 가능한 칸무스를 조회하거나, 칸무스에서 사용 가능한 장비를 조회할 수 있으며 일반 슬롯과 보강증설 슬롯을 구분합니다.

### 개수, 개발 및 원정 계획

- **개수 계획:** 요일, 장비 분류, 키워드 및 즐겨찾기로 조회하고, 2번함 조건, 소모량 및 장비 갱신 경로를 확인합니다.
- **개발 계산:** 비서함과 투입 자원에 따른 목표 장비의 개발 확률을 조회하거나, 목표 장비에서 레시피를 찾아봅니다.
- **원정 점검:** 함종, 레벨, 장비, 보급, 사기 등의 조건을 점검하고, 대성공 확률, 수익 및 완료 시간을 예상합니다.

### 전과 및 경험치 계획

- 기기에 기록된 전과 정보, 출격 기록 및 전과 달력을 확인합니다.
- EO와 임무 전과 보상을 반영해 목표를 계획하고, 남은 전과와 일일 필요량을 예상합니다.
- 해역, 경로, 승리 등급, 기함, MVP 등의 조건에 따라 경험치를 계산하고 레벨업에 필요한 출격 횟수를 예상합니다.
- 칸무스 육성 목표를 저장하고 경험치 및 레벨 진행도를 확인합니다.

전과와 경험치는 기록된 데이터 및 설정한 조건을 바탕으로 추정합니다.

### 편성 기록 및 해역 자료

- 현재 함대와 기지항공대 편성을 저장하고, 이름이나 해역 등의 조건으로 기록을 찾습니다.
- 고해상도 편성 이미지를 내보내 공유하거나 공략을 정리할 수 있습니다.
- DeckBuilder 데이터를 내보내거나, 사용자가 직접 제공권 시뮬레이터, Jervis 등의 외부 도구를 열어 계산을 이어갈 수 있습니다.
- 해역 경로도, 지점 유형, 적 편성, 진형, 경험치 및 제공 참고 정보를 확인하고, 적 함선을 눌러 상세 자료를 살펴봅니다.
- 해역과 적 함선 등의 자료는 앱 내에서 각각 업데이트를 확인할 수 있습니다.

저장된 편성은 열람과 공유를 위한 것이며, 게임 내 편성 조작은 플레이어가 직접 수행합니다. 해역과 적 함선 자료는 게임 업데이트에 따라 달라질 수 있으므로 실제 게임 상황을 기준으로 확인해 주세요.

### 항해 일지, 자원 추이 및 백업

- 출격, 원정, 건조, 개발, 제적, 자원의 여섯 종류 기록을 저장합니다.
- 날짜, 해역, 상태 등의 조건으로 출격 기록을 필터링하고 지점 및 전투 상세 정보를 확인합니다.
- 자원별 보유량 추이, 기간 내 증감 및 과거 기록을 확인합니다.
- 현재 계정의 항해 일지와 편성 기록을 내보내고 공유하거나 복원할 수 있으며, 문서 폴더를 선택해 백그라운드 동기화와 수동 동기화를 사용할 수도 있습니다.

기록은 앱이 실제로 관찰한 데이터부터 쌓입니다. 백업 대상은 항해 일지와 편성 기록이며, 로그인 계정과 비밀번호, 로그인 Cookie 또는 앱의 모든 설정을 포함하지는 않습니다.

### 인터페이스, 알림 및 게임 캐시

- 전체 화면, 게임 화면 맞춤, 정보 패널 조정 및 홈 화면 모듈 편집을 지원합니다. 모듈 순서를 바꾸거나 숨기고 기본 레이아웃으로 복원할 수 있습니다.
- 함대 요약과 상단 자원 표시줄의 일부 항목을 맞춤 설정할 수 있습니다.
- 원정, 입거, 건조, 정박지 수리 및 피로도 관련 알림과 남은 시간 표시를 제공합니다.
- 게임 리소스 캐시 및 로컬 캐시 다운로드를 제공하며, 일시 정지, 재개, 무결성 검사 및 삭제를 지원합니다.
- 화면과 프레임률 옵션, 외장 마우스 조작 및 마우스 휠 호환 설정을 지원합니다.

알림과 백그라운드 실행은 시스템 권한과 절전 정책의 영향을 받습니다. 리소스 캐시는 반복 다운로드를 줄이기 위한 것으로, 게임을 플레이하려면 게임 서버 연결이 필요합니다.

## 시작하기

1. 릴리스 페이지에서 설치 파일을 다운로드하고, 해당 버전의 안내에 따라 설치한 뒤 앱을 실행합니다.
2. 연결 방식을 선택하고 게임 페이지에서 직접 로그인합니다. 필요하면 시스템 네트워크, HTTP 프록시 또는 SOCKS5 프록시를 설정할 수 있습니다.
3. 모항에 진입해 앱이 함대와 계정 데이터를 받은 뒤 함대, 임무, 창고 등의 보조 화면을 확인합니다.
4. 기기 크기에 맞춰 레이아웃을 조정하고, 필요에 따라 알림, 캐시 및 기록 백업을 설정합니다.

앱은 두 가지 실행 모드를 제공합니다.

- **게임 정보 모드:** 게임 페이지가 이미 받은 API 응답을 읽어 함대, 임무, 전투 및 일지 등의 보조 기능을 활성화합니다.
- **브라우저 전용 모드:** API 정보 읽기를 끄고, 앱 안에서 게임 페이지를 열람하고 조작합니다.

DMM 접속 외에도 실험적인 OOI 서드파티 접속 경로를 제공합니다. OOI를 이용하면 로그인 인증 정보가 해당 서드파티 서비스로 전송되므로, 앱 내 안내를 확인한 후 사용해 주세요.

## 데이터 및 개인 정보

보조 기록은 주로 기기에 저장되며, 별도의 앱 클라우드 계정을 만들 필요는 없습니다. 기능별 데이터 처리 방식은 다음과 같습니다.

| 항목 | 데이터 처리 방식 |
| --- | --- |
| 항해 일지 및 편성 기록 | 기기에 저장되며, 사용자가 내보내기, 복원 또는 지정한 문서 폴더로의 동기화를 선택합니다. |
| 익명 기기 및 사용 통계 | TelemetryDeck으로 기기 정보와 현재 렌더링 모드 등 익명 사용 통계를 수집합니다. 기본으로 활성화되어 있으며 설정에서 끌 수 있습니다. |
| KCWiki 데이터 기여 | 기본으로 비활성화되어 있습니다. 버전과 설정이 지원하는 경우 사용자가 활성화 여부를 선택할 수 있습니다. |
| 진단 파일 | 사용자가 직접 저장하거나 시스템 공유 창을 통해 전송하며, 앱은 진단 파일을 자동으로 업로드하지 않습니다. |

보조 분석에 사용하는 게임 API 정보에서는 api_token, api_starttime 등의 민감한 매개변수를 제거합니다. 기록 백업에는 로그인 Cookie가 포함되지 않지만, 로그인 상태는 시스템 WebView의 기본 동작에 따라 기기에 저장될 수 있습니다.

## 소통 및 피드백

사용 경험, 호환성 문제 및 기능 제안을 환영합니다.

저는 중국어, 영어, 일본어로 소통할 수 있습니다. 이 세 언어 중 편한 언어로 연락해 주세요.

- **QQ 그룹: 1104904097**
- **연락처 이메일: yamatosaki123[AT] gmail.com**
- **문제 제보:** [GitHub Issues](https://github.com/yamatosaki/yahagi-kancolle-browser/issues)

문제를 제보할 때는 앱 버전, 기기 모델, 운영체제 버전, 재현 단계 및 관련 스크린샷을 함께 알려 주시면 원인 파악에 도움이 됩니다.

## 오픈 소스 및 기여

ヤハギ는 오픈 소스로 개발됩니다. Issue와 Pull Request를 통한 기능 개선, 호환성 테스트, 문서 작성 및 현지화 기여를 환영합니다.

소스 코드 빌드, 테스트, Fork의 GitHub Actions를 이용한 APK 빌드 방법은 [소스 코드 빌드 및 검증](BUILDING.ko.md)을 참고하세요. UI, 리소스와 독립 앱 변경은 [커스터마이징 안내 (English)](CUSTOMIZING.en.md)를 참고하세요. 개발에 참여하기 전에 [기여 안내](CONTRIBUTING.ko.md)와 [보안 정책](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/SECURITY.md)을 읽어 주세요.

프로젝트 소스 코드는 [MIT License](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/LICENSE)를 따릅니다. 서드파티 글꼴, 의존성 및 리소스에 관한 설명은 [THIRD_PARTY_NOTICES](https://github.com/yamatosaki/yahagi-kancolle-browser/blob/master/THIRD_PARTY_NOTICES)를 확인하세요.

## 면책 사항

ヤハギ는 커뮤니티에서 개발한 비공식 도구로, 《함대 컬렉션》의 운영사, 개발사, DMM 및 관련 권리자와 소속, 승인 또는 협력 관계가 없습니다.

사용자는 관련 서비스 약관을 직접 확인하고 준수해야 하며, 서드파티 도구 사용으로 발생할 수 있는 계정, 네트워크 및 호환성 위험을 부담합니다. 게임 명칭, 상표 및 서드파티 리소스의 권리는 각각의 권리자에게 있습니다.

## 감사의 말

데이터 구성, 기능 설계 및 커뮤니티 협업 측면에서 참고와 영감을 준 [POI 브라우저](https://github.com/poooi/poi) 프로젝트와 오픈 소스 커뮤니티에 특별히 감사드립니다.

iOS 서드파티 이식판을 제작하고 제공해 주신 [Kutinana](https://github.com/Kutinana) 님께 감사드립니다.

Flutter, WebView Flutter 및 각 의존성 라이브러리의 유지·관리자와 테스트, 문제 제보, 코드 기여에 참여해 주신 모든 제독님께도 감사드립니다.

ヤハギ는 독립적으로 개발되는 프로젝트입니다. 본 프로젝트의 견해와 구현은 위 프로젝트나 커뮤니티의 공식 입장을 대변하지 않습니다.

## 후원

[GitHub Sponsors로 Yahagi 후원하기](https://github.com/sponsors/yamatosaki)

Alipay 또는 WeChat Pay로도 프로젝트를 후원할 수 있습니다. QR 코드를 누르면 원본 이미지를 볼 수 있습니다.

| Alipay | WeChat Pay |
| :---: | :---: |
| <a href="docs/images/sponsors/alipay.jpg"><img src="docs/images/sponsors/alipay.jpg" width="220" alt="Alipay 후원 결제 QR 코드"></a> | <a href="docs/images/sponsors/wechat-pay.png"><img src="docs/images/sponsors/wechat-pay.png" width="220" alt="WeChat Pay 후원 결제 QR 코드"></a> |

Yahagi 프로젝트를 응원해 주셔서 감사합니다! ❤️

여러분의 후원은 저에게 큰 격려가 되며, 이 오픈 소스 프로젝트를 꾸준히 개발하고 개선해 나가는 중요한 원동력입니다.

진심으로 감사드립니다!
