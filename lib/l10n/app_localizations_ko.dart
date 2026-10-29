// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get debuffReminderTitle => '장갑 파쇄 알림';

  @override
  String get debuffReminderSourcePort => '모항';

  @override
  String get debuffReminderSourceBattleResult => '전투 결과';

  @override
  String get debuffReminderSourceAirDefense => '기지 방공';

  @override
  String debuffReminderMessage(String source) {
    return '$source: 기믹 또는 약화 알림이 감지되었습니다.';
  }

  @override
  String get debuffReminderSectionTitle => '게임 내 알림';

  @override
  String get debuffReminderSettingTitle => '장갑 파쇄 알림';

  @override
  String get debuffReminderSettingSubtitle =>
      '두 방식 모두 진동하며, 기믹 해제 또는 약화 신호 감지 시 알립니다.';

  @override
  String get debuffReminderStyleDialog => '확인 대화상자(기본)';

  @override
  String get debuffReminderStyleTopNotice => '상단 알림';

  @override
  String get cameraAvoidanceTitle => '카메라 회피';

  @override
  String get cameraAvoidanceDesc =>
      '카메라가 있는 쪽의 화면 여백을 조정합니다. 화면을 뒤집으면 여백도 자동으로 반대쪽으로 바뀝니다.';

  @override
  String get cameraAvoidanceDistance => '회피 거리';

  @override
  String get operationProtectionTitle => '오조작 방지';

  @override
  String get confirmBeforeExitTitle => '실수로 종료 방지';

  @override
  String get confirmBeforeExitDescription =>
      '뒤로 버튼이나 뒤로 가기 제스처로 앱을 나가기 전에 확인합니다.';

  @override
  String get confirmBeforeExitSaveFailed => '종료 방지 설정을 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get appExitConfirmTitle => '홈 화면으로 이동할까요?';

  @override
  String get appExitConfirmDescription => '게임이 백그라운드로 전환됩니다.';

  @override
  String get appExitStay => '게임 계속하기';

  @override
  String get appExitToDesktop => '홈 화면으로 이동';

  @override
  String get appExitFailed => '홈 화면으로 이동하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get enterGameFullscreen => '게임 전체 화면';

  @override
  String get exitGameFullscreen => '전체 화면 종료';

  @override
  String get exitFullscreenShort => '나가기';

  @override
  String get exitFullscreenConfirmTitle => '게임 전체 화면을 종료할까요?';

  @override
  String get exitFullscreenConfirmDescription =>
      '전체 화면을 종료하면 정보 패널과 도구 모음이 다시 표시됩니다.';

  @override
  String get exitFullscreenSkipConfirmation => '다시 묻지 않기';

  @override
  String get exitFullscreenConfirmAction => '전체 화면 종료';

  @override
  String get gameFullscreenHint =>
      '플로팅 버튼을 누르거나 뒤로 버튼으로 전체 화면을 종료하세요. 버튼을 드래그해 위치를 바꿀 수 있습니다';

  @override
  String get gameFullscreenUnavailable => '종료 버튼을 표시할 수 없어 일반 레이아웃으로 복원했습니다';

  @override
  String get questCompletionNotice => '완료된 임무가 있습니다';

  @override
  String questCompletionCount(int count) {
    return '임무 $count개 완료 · 보상 수령 대기';
  }

  @override
  String get resourceTrend90d => '90일';

  @override
  String get resourceTrendInventoryTitle => '보유량 추이';

  @override
  String get resourceTrendCustomize => '표시할 자원';

  @override
  String get resourceTrendAtLeastOne => '자원을 하나 이상 선택해 주세요';

  @override
  String get resourceTrendBuildMaterial => '고속건조재';

  @override
  String get resourceTrendRepairMaterial => '고속수복재';

  @override
  String get resourceTrendDevMaterial => '개발자재';

  @override
  String get resourceTrendImproveMaterial => '개수자재';

  @override
  String get resourceTrendLatest => '최근 보유량';

  @override
  String get resourceTrendChange => '기간 내 증감';

  @override
  String resourceTrendBaseline(String time) {
    return '증감 기준: $time JST';
  }

  @override
  String resourceTrendObserved(String time) {
    return '최근 기록: $time JST';
  }

  @override
  String get resourceTrendPartial => '기간 시작 기록이 없어 첫 기록을 기준으로 증감을 계산합니다';

  @override
  String get resourceTrendInsufficient => '비교할 기록이 부족합니다';

  @override
  String get resourceTrendNoPeriodData => '이 기간의 자원 기록이 없습니다';

  @override
  String get resourceTrendLoadError => '자원 기록을 불러오지 못했습니다';

  @override
  String get resourceTrendSaveError => '자원 표시 설정을 저장하지 못했습니다';

  @override
  String get resourceTrendInspect => '밀어서 확인';

  @override
  String get resourceTrendExpand => '차트 확대';

  @override
  String get resourceTrendSampled =>
      '장기간 차트는 최댓값과 최솟값을 유지하며, 표시된 값은 실제 표본 기록에 해당합니다';

  @override
  String get resourceTrendLocalScale => '세로축이 보유량 범위에 맞춰 조정됩니다';

  @override
  String get resourceTrendBaseShort => '기준';

  @override
  String get diagnosticLoggingSection => '클라이언트 진단 로그';

  @override
  String get diagnosticLoggingTitle => '클라이언트 진단 로그 기록';

  @override
  String get diagnosticLoggingDesc =>
      '성능 및 오류 요약만 기록하며 계정, 비밀번호, 로그인 인증 정보는 포함하지 않습니다';

  @override
  String get telemetryAnonymousStatsTitle => '익명 기기 및 사용 통계';

  @override
  String get telemetrySaveFailed =>
      '설정을 저장하지 못해 통계를 중지했습니다. 앱을 다시 시작하면 이전 설정으로 돌아갈 수 있습니다. 저장을 다시 시도해 주세요.';

  @override
  String get telemetryRetrySave => '통계 설정 저장 다시 시도';

  @override
  String get telemetryAnonymousStatsDesc =>
      '앱 개선을 위해 기기 정보와 렌더링 모드가 포함된 익명 통계를 보냅니다. 계정 및 개인 정보는 포함하지 않습니다.';

  @override
  String get diagnosticPrivacyTitle => '개인 정보 보호 진단';

  @override
  String get diagnosticPrivacyDesc =>
      '내보내기 전에 내용을 다시 검사합니다. 로그에는 계정, 비밀번호, Cookie, 토큰, 요청 본문, 응답 본문, 채팅 내용, 스크린샷을 기록하지 않으며 자동으로 업로드하지 않습니다.';

  @override
  String get diagnosticStatusEnabled => '기록 중';

  @override
  String get diagnosticStatusDisabled => '기록 중지됨';

  @override
  String diagnosticStorageUsage(String size) {
    return '로컬 로그 크기: $size';
  }

  @override
  String get exportDiagnosticFile => '진단 파일 내보내기';

  @override
  String get saveDiagnosticFile => '기기에 저장';

  @override
  String get shareDiagnosticFile => '진단 파일 공유';

  @override
  String get diagnosticSaveConfirmTitle => '진단 파일을 저장할까요?';

  @override
  String get diagnosticSaveConfirmDesc =>
      '개인 정보 검사를 마친 JSON 파일을 생성합니다. 저장할 폴더만 선택하면 됩니다. 파일 이름은 클라이언트가 자동 생성하며 변경할 수 없습니다.';

  @override
  String get diagnosticSaveAction => '폴더 선택';

  @override
  String diagnosticSaveSucceeded(String fileName) {
    return '저장됨: $fileName';
  }

  @override
  String get diagnosticSaveFailed => '진단 파일을 저장하지 못했습니다';

  @override
  String get diagnosticShareConfirmTitle => '진단 파일을 공유할까요?';

  @override
  String get diagnosticShareConfirmDesc =>
      '개인 정보 검사를 마친 JSON 파일을 생성하고 시스템 공유 창을 엽니다. 보내기 전에 수신자를 직접 확인해 주세요.';

  @override
  String get diagnosticShareAction => '공유';

  @override
  String get diagnosticShareFailed => '진단 파일을 공유하지 못했습니다';

  @override
  String get clearDiagnosticData => '진단 로그 삭제';

  @override
  String get diagnosticExportConfirmTitle => '진단 파일을 내보낼까요?';

  @override
  String get diagnosticExportConfirmDesc =>
      'JSON 파일을 생성하고 시스템 공유 창을 엽니다. 파일에는 클라이언트 성능, 오류 요약, 익명 기기 실행 정보만 포함됩니다. 보내기 전에 수신자를 직접 확인해 주세요.';

  @override
  String get diagnosticExportAction => '내보내기';

  @override
  String get diagnosticClearConfirmTitle => '진단 로그를 삭제할까요?';

  @override
  String get diagnosticClearConfirmDesc =>
      '앱 내 진단 로그와 임시 내보내기 사본을 삭제합니다. 별도로 저장하거나 공유한 파일은 직접 삭제해야 합니다.';

  @override
  String get diagnosticClearFailed => '진단 데이터를 삭제하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get diagnosticExportFailed => '진단 파일을 내보내지 못했습니다';

  @override
  String get langKo => '한국어';

  @override
  String get langEn => 'English';

  @override
  String get dataVersionLabel => '데이터 버전';

  @override
  String get dataLastCheckedLabel => '최근 확인';

  @override
  String get dataNotChecked => '확인한 적 없음';

  @override
  String get sortieMapDataTitle => '해역 데이터';

  @override
  String get enemyDataTitle => '적 함선 데이터';

  @override
  String dataCatalogUpToDate(String version) {
    return '최신 데이터입니다.\n버전: $version';
  }

  @override
  String dataCatalogUpdated(String before, String after) {
    return '데이터를 업데이트했습니다.\n$before → $after';
  }

  @override
  String get dataCatalogIncompatible => '현재 앱 버전이 낮습니다. 앱을 먼저 업데이트해 주세요.';

  @override
  String get dataCatalogValidationFailed =>
      '업데이트 데이터를 검증하지 못해 현재 데이터를 계속 사용합니다.';

  @override
  String get dataCatalogStorageFailed => '업데이트 데이터를 저장하지 못했습니다.';

  @override
  String get dataCatalogNetworkFailed => '네트워크 업데이트에 실패했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get questLocalProgress => '로컬 진행도';

  @override
  String questServerProgress(String progress) {
    return '서버 진행도: $progress';
  }

  @override
  String get appTitle => 'ヤハギ';

  @override
  String get game => '게임';

  @override
  String get fleet => '함대';

  @override
  String get expedition => '원정';

  @override
  String get repair => '수리';

  @override
  String get construction => '건조';

  @override
  String get quests => '임무';

  @override
  String get battleRecords => '항해 일지';

  @override
  String get settings => '설정';

  @override
  String get settingsTitle => '설정';

  @override
  String get layoutSettings => '화면 및 레이아웃';

  @override
  String get themeColorTitle => '테마 색상';

  @override
  String get themeClassicDark => '기본 다크';

  @override
  String get themeSeaSaltTeal => '씨솔트 틸';

  @override
  String get themeClearSkyBlue => '스카이 블루';

  @override
  String get uiFontSizeTitle => '화면 글자 크기';

  @override
  String get uiFontSizeDescription => '기본값은 시스템 설정을 따릅니다.';

  @override
  String get uiFontSizeSystem => '기본값 (시스템 설정 따름)';

  @override
  String get uiFontSizeSmall => '작게';

  @override
  String get uiFontSizeMedium => '보통';

  @override
  String get uiFontSizeLarge => '크게';

  @override
  String get uiDisplaySizeTitle => 'UI 크기';

  @override
  String get uiDisplaySizeDesc => '상단 바, 탐색 바, 정보 바의 표시 밀도를 조정합니다.';

  @override
  String get uiDisplaySizeNormal => '보통';

  @override
  String get uiDisplaySizeCompact => '작게';

  @override
  String get uiDisplaySizeMinimal => '미니멀';

  @override
  String get panelResourcesExpand => '자원 펼치기';

  @override
  String get panelResourcesCollapse => '자원 접기';

  @override
  String get panelResourcesCollapsedItems => '접었을 때 표시';

  @override
  String get panelResourcesCollapsedItemsReset => '기본값으로 복원';

  @override
  String get minimalResourcePositionTitle => '자원 위치';

  @override
  String get minimalResourcePositionDesc =>
      '미니멀에서 휴대폰 가로 모드일 때 게임 페이지의 자원을 정보 바 상단, 게임 위의 얇은 바, 또는 화면 하단의 얇은 바에 표시합니다';

  @override
  String get minimalResourcePositionPanel => '정보 바';

  @override
  String get minimalResourcePositionTopBar => '상단 바';

  @override
  String get minimalResourcePositionBottomBar => '하단 바';

  @override
  String get gameAreaRatio => '게임 영역 비율';

  @override
  String get infoPanelWidth => '정보 패널 너비 (세로 화면에서는 적용 안 됨)';

  @override
  String get autoZoom => '권장 표시 비율 적용 (게임:메뉴 67:33)';

  @override
  String get enhancedDamagePulse => '손상 맥동 효과 강화';

  @override
  String get enhancedDamagePulseDesc =>
      '소파·중파·대파에 따라 색상, 속도, 초상화 내부 빛 효과를 강화합니다. 끄면 일반 효과를 사용합니다.';

  @override
  String get informationPanelOnLeft => '기능 영역을 왼쪽에 배치';

  @override
  String get informationPanelOnLeftDesc =>
      '끄면 기능 영역이 오른쪽에 표시됩니다. 세로 화면에서는 위아래 배치를 유지합니다.';

  @override
  String get workspaceMenuOnRight => '메뉴를 오른쪽에 배치';

  @override
  String get workspaceMenuOnRightDesc => '끄면 메뉴가 왼쪽에 표시됩니다.';

  @override
  String get language => '언어 (Language)';

  @override
  String get networkSettings => '네트워크 설정';

  @override
  String get networkStatus => '네트워크 상태';

  @override
  String get proxyNotSupported =>
      '이 기기의 Android System WebView는 앱 내 프록시 설정을 지원하지 않습니다.\n시스템 네트워크 또는 전체 VPN만 사용할 수 있습니다.';

  @override
  String get systemNetwork => '시스템 네트워크 / VPN';

  @override
  String get systemNetworkDesc => '앱 내 프록시를 사용하지 않고 시스템 네트워크 환경을 따릅니다.';

  @override
  String get httpProxy => 'HTTP 프록시';

  @override
  String get httpProxyDesc => '사용자 지정 HTTP 프록시 서버에 연결합니다.';

  @override
  String get socks5Proxy => 'SOCKS5 프록시';

  @override
  String get socks5ProxyDesc => '사용자 지정 SOCKS5 프록시 서버에 연결합니다.';

  @override
  String get hostAddress => '호스트 주소 (IP 또는 도메인)';

  @override
  String get hostHint => '예: 192.168.1.10';

  @override
  String get port => '포트';

  @override
  String get currentSavedMode => '현재 저장된 모드';

  @override
  String get vpnStatus => 'VPN 상태';

  @override
  String get vpnActive => '활성 VPN이 감지되었습니다';

  @override
  String get vpnInactive => '활성 VPN이 감지되지 않았습니다';

  @override
  String get testConnection => '네트워크 연결 테스트';

  @override
  String get applySettings => '설정 적용 후 게임 새로고침';

  @override
  String get restoreSystemNetwork => '시스템 네트워크로 복원';

  @override
  String get gameSafety => '대파 경고';

  @override
  String get battleSafetySectionTitle => '게임 안전';

  @override
  String get blockSortieTitle => '대파 진격 경고';

  @override
  String get blockSortieDesc =>
      '출격·진격 요청에 대한 응답을 받은 후, 출격 함대에 기함이 아닌 대파 함선(퇴피한 함선 제외)이 있으면 확인이 필요한 경고를 표시합니다. 출격·진격 요청을 차단하거나 자동으로 철수하지 않습니다.';

  @override
  String get storageAndCache => '저장 공간 및 캐시';

  @override
  String get logoutAndClear => '로그아웃 / 계정 정보 삭제';

  @override
  String get logoutAndClearDesc => '게임 로그인 상태를 지웁니다. 다음에 열 때 다시 로그인해야 합니다.';

  @override
  String get clearQuestCache => '임무 데이터 캐시 삭제';

  @override
  String get clearQuestCacheDesc =>
      '로컬에 캐시된 비식별화 임무 데이터를 지웁니다. 앱을 다시 시작한 뒤 게임 내 임무 화면을 열어 데이터를 다시 받아야 합니다';

  @override
  String get clearWebCache => '브라우저 캐시 삭제';

  @override
  String get clearWebCacheDesc => 'WebView의 임시 페이지 및 스크립트 데이터를 지웁니다.';

  @override
  String get baseSenkaResetTitle => '기본 전과 초기화';

  @override
  String get baseSenkaResetDesc =>
      '이번 달 누적 기본 전과를 0.00으로 설정합니다. EO, 임무 및 기타 전과 데이터에는 영향을 주지 않습니다.';

  @override
  String get baseSenkaResetConfirmTitle => '기본 전과 초기화';

  @override
  String get baseSenkaResetConfirmDesc =>
      '이번 달 누적 기본 전과를 초기화할까요? 일별 EO 및 임무 보상 기록은 유지되며, 이후 경험치 증가분은 0.00부터 누적됩니다.';

  @override
  String get baseSenkaResetSuccess => '이번 달 누적 기본 전과를 초기화했습니다';

  @override
  String get baseSenkaManualTitle => '기본 전과 직접 입력';

  @override
  String baseSenkaCurrentValue(String value) {
    return '이번 달 누적: 전과 $value';
  }

  @override
  String get baseSenkaManualDialogTitle => '이번 달 누적 기본 전과 입력';

  @override
  String get baseSenkaManualInputLabel => '이번 달 누적 기본 전과';

  @override
  String get baseSenkaManualInvalid => '0 이상의 숫자를 소수점 둘째 자리까지 입력해 주세요';

  @override
  String baseSenkaSetSuccess(String value) {
    return '이번 달 누적 기본 전과를 $value(으)로 설정했습니다';
  }

  @override
  String get baseSenkaSaveFailed => '기본 전과를 저장하지 못했습니다. 다시 시도해 주세요';

  @override
  String get senkaTodaySorties => '오늘 출격';

  @override
  String get fleetBrief => '함대 요약';

  @override
  String get expeditionBrief => '원정 요약';

  @override
  String get repairBrief => '수리 요약';

  @override
  String get repairDockMode => '입거';

  @override
  String get anchorageRepairMode => '정박지';

  @override
  String get idle => '비어 있음';

  @override
  String get inactive => '미사용';

  @override
  String get repairing => '수리 중';

  @override
  String get outOfRepairRange => '수리 범위 밖';

  @override
  String get unableToRepair => '수리 불가';

  @override
  String get constructionBrief => '건조 요약';

  @override
  String get questBrief => '임무 요약';

  @override
  String get preSortieCheck => '출격 전 점검';

  @override
  String get sortieCheckShipsMode => '칸무스';

  @override
  String get sortieCheckMapsMode => '해역';

  @override
  String get mapHpGauges => '해역 게이지';

  @override
  String get noMapGaugeData => '해역 게이지 데이터가 없습니다';

  @override
  String get noMapGaugeDataHint => '게임에서 출격 해역에 진입하면 데이터가 동기화됩니다';

  @override
  String get showClearedMaps => '공략 완료 해역 표시';

  @override
  String get allMapsCleared => '모든 해역의 공략을 완료했습니다';

  @override
  String get forecast => '전투 예측';

  @override
  String get waitingForSortieData => '출격 데이터 대기 중';

  @override
  String get standby => '대기';

  @override
  String get compact => '간략히';

  @override
  String get detailed => '자세히';

  @override
  String get questDesc => '임무 설명';

  @override
  String get baseReward => '기본 보상';

  @override
  String get accepted => '수락함';

  @override
  String get completed => '완료';

  @override
  String get updatedAt => '갱신 시각';

  @override
  String get questDaily => '일간';

  @override
  String get questWeekly => '주간';

  @override
  String get questMonthly => '월간';

  @override
  String get questOneTime => '단발';

  @override
  String get questOther => '기타';

  @override
  String get questUnknown => '알 수 없음';

  @override
  String get inProgress => '진행 중';

  @override
  String get clearWebCacheConfirmTitle => '브라우저 캐시 삭제';

  @override
  String get clearWebCacheConfirmDesc =>
      '브라우저 캐시를 삭제할까요? WebView가 캐시한 임시 데이터를 삭제합니다. 다운로드한 게임 리소스에는 영향을 주지 않습니다.';

  @override
  String get confirmClear => '삭제';

  @override
  String get captureMode => '데이터 수집 모드';

  @override
  String get gameAndSound => '게임 및 소리';

  @override
  String get gameSound => '게임 소리';

  @override
  String get aboutApp => 'ヤハギ 정보';

  @override
  String get aboutSubtitle => '학습용 버전 1.0.2 · 면책 조항 · 업데이트 확인';

  @override
  String get version => '학습용 버전 1.0.2';

  @override
  String get disclaimerTitle => '면책 조항 (DISCLAIMER)';

  @override
  String get disclaimerP1 =>
      '이 프로젝트는 프로그래밍 기술 교류 및 학습 목적으로만 제공되는 비영리·비공식 서드파티 범용 브라우저 도구입니다. Kantai Collection (KanColle) 공식 운영 주체 및 관련 권리자와 아무런 관계가 없습니다.';

  @override
  String get disclaimerP2 =>
      '이 소프트웨어는 게임 서버의 통신 데이터에 관여하거나 이를 차단·재전송·변조하지 않으며, 플레이어를 대신해 게임을 조작하지 않습니다. 원저작자는 소프트웨어의 품질에 대해 명시적 또는 묵시적으로 보증하지 않습니다. 여기에는 버그 없음, 적합성, 시스템 안정성에 대한 보증 등이 포함됩니다.';

  @override
  String get disclaimerP3 =>
      '어떠한 경우에도 이 소프트웨어의 사용 또는 사용 불가로 발생한 모바일 기기 손상, 데이터 손실, 게임 계정 제재 위험, 기타 직간접적 손해에 대해 원저작자는 법적 책임이나 연대 책임을 지지 않습니다. 기술 학습 외의 목적으로 사용할 경우 발생하는 저작권 분쟁, 서비스 약관 위반 및 기타 위험은 모두 사용자가 부담합니다.';

  @override
  String get viewOnGitHub => 'GitHub에서 보기';

  @override
  String get officialWebsite => '공식 사이트';

  @override
  String get checkForUpdates => '업데이트 확인';

  @override
  String get openSourceLicense => '오픈 소스 라이선스: MIT License';

  @override
  String get newVersionFound => '🚀 새 버전이 있습니다!';

  @override
  String get currentVersionLabel => '현재 버전';

  @override
  String get latestVersionLabel => '최신 버전';

  @override
  String get updateContent => '업데이트 내용:';

  @override
  String get later => '나중에';

  @override
  String get goDownload => '다운로드 페이지로 이동';

  @override
  String get alreadyLatest => '최신 버전입니다';

  @override
  String get alreadyLatestDesc => '현재 최신 버전을 사용 중입니다.';

  @override
  String get noRelease => '출시된 버전 없음';

  @override
  String get noReleaseDesc => 'GitHub 저장소에 아직 Release가 없습니다.';

  @override
  String get checkFailed => '확인 실패';

  @override
  String get networkError => '네트워크 오류';

  @override
  String get networkErrorDesc => '업데이트 확인 중 오류가 발생했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get externalLinkOpenFailed => '링크를 열 수 없습니다. 브라우저가 설치되어 있는지 확인해 주세요.';

  @override
  String get noUpdateLog => '업데이트 내역 없음';

  @override
  String get battleWarningOff => '끄기';

  @override
  String get battleWarningConfirm => '알림 켜기';

  @override
  String get advanceWarningDisplayModeTitle => '경고 표시 방식';

  @override
  String get advanceWarningAlwaysConfirm => '항상 확인';

  @override
  String get advanceWarningSmart => '스마트 알림';

  @override
  String get advanceWarningSmartDescription =>
      '모든 대파함의 남은 응급수리 장비가 확인되면 상단 알림, 그 외에는 확인창 표시.';

  @override
  String get advanceWarningAlwaysConfirmDescription => '대파 감지 시 확인창을 표시합니다.';

  @override
  String get advanceWarningTimingModeTitle => '알림 시점';

  @override
  String get advanceWarningTimingModeDescription => '변경은 다음 출격부터 적용됩니다.';

  @override
  String get advanceWarningPostBattle => '전투 결과 후 알림';

  @override
  String get advanceWarningAfterAdvance => '진격 후 알림';

  @override
  String get advanceWarningBothTimings => '두 시점 모두 알림';

  @override
  String get advanceWarningAfterAdvanceDescription => '진격 성공 후 대파를 확인합니다.';

  @override
  String get advanceWarningPostBattleDescription => '전투 결과 후 대파를 확인합니다.';

  @override
  String get advanceWarningBothTimingsDescription =>
      '전투 결과 후와 진격 성공 후 대파를 확인합니다.';

  @override
  String get advanceWarningTimingRequired => '알림 시점을 하나 이상 선택해 주세요.';

  @override
  String get advanceWarningPostBattleOnlyWarning =>
      '진격에 성공한 후에는 대파 상태를 확인하지 않습니다.';

  @override
  String get postBattleDamageControlEquippedBody =>
      '전투 결과 확인 후 대파된 칸무스가 있습니다. 함선과 남은 응급수리 장비를 확인해 주세요.';

  @override
  String get postBattleDamageControlDangerBody =>
      '전투 결과 확인 후 대파된 칸무스가 있습니다! 진격을 멈추고 다음 전투에 들어가기 전에 게임 내 상태를 확인해 주세요.';

  @override
  String get advanceWarningDamageControlActive => '응급수리 장비 유효';

  @override
  String get advanceWarningReloadGame => '게임 새로고침';

  @override
  String get advanceWarningReloadFrame => '프레임 새로고침';

  @override
  String get advanceWarningRefreshFailed =>
      '새로고침이 완료되지 않았습니다. 게임 상태와 장비를 확인해 주세요.';

  @override
  String get logoutSnackbar => '로그아웃하고 계정 정보를 삭제했습니다.';

  @override
  String get logoutConfirmTitle => '로그아웃 및 계정 정보 삭제';

  @override
  String get logoutConfirmDesc =>
      '앱 내 게임 페이지의 Cookie, 로컬 저장소, 캐시를 지우고 로그인 페이지로 돌아갑니다. 계속할까요?';

  @override
  String get logoutSucceeded => '로그아웃했습니다. 다시 로그인해 주세요.';

  @override
  String get logoutFailed => '로그아웃하지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get questCacheCleared => '로컬 임무 데이터 캐시를 삭제했습니다';

  @override
  String get webCacheCleared => '브라우저 캐시를 삭제했습니다';

  @override
  String get clearLogbook => '항해 일지 데이터 삭제';

  @override
  String get clearLogbookDesc =>
      '로컬에 저장된 출격, 원정, 건조, 개발, 제적 및 자원 기록을 삭제합니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get clearLogbookConfirmTitle => '항해 일지 데이터 삭제';

  @override
  String get clearLogbookConfirmDesc =>
      '모든 항해 일지 데이터를 삭제할까요? 출격, 원정, 건조, 개발, 제적 및 자원 기록을 삭제합니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get logbookCleared => '모든 항해 일지 데이터를 삭제했습니다';

  @override
  String get antiCatbomb => '연결 끊김 시 고양이 오류 방지';

  @override
  String get antiCatbombDesc =>
      '네트워크 연결 끊김 등으로 게임 요청이 실패하면 게임을 일시 정지하고 계속 재시도하여 고양이 오류를 방지합니다.';

  @override
  String get close => '닫기';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get waitingForData => '데이터 대기 중';

  @override
  String get fleetNoShips => '현재 함대에 칸무스가 없습니다';

  @override
  String get unorganized => '미편성';

  @override
  String get speed => '속력';

  @override
  String get totalLevel => '총 레벨';

  @override
  String get firepower => '화력';

  @override
  String get torpedo => '뇌장';

  @override
  String get antiAir => '대공';

  @override
  String get antiSub => '대잠';

  @override
  String get airPower => '제공';

  @override
  String get los => '색적';

  @override
  String get avgCondition => '최저 컨디션';

  @override
  String get losDetail => '색적 상세';

  @override
  String get totalLos => '총 색적';

  @override
  String get specialAttack => '특수 공격';

  @override
  String get unknownShip => '알 수 없는 칸무스';

  @override
  String get unknownClass => '알 수 없는 함종';

  @override
  String get needsResupply => '보급 필요';

  @override
  String get fuel => '연료';

  @override
  String get ammo => '탄약';

  @override
  String get hp => '내구';

  @override
  String get waitingForEquip => '장비 데이터 갱신 대기 중';

  @override
  String get fastSpeed => '고속';

  @override
  String get slowSpeed => '저속';

  @override
  String get gotIt => '확인';

  @override
  String get unknownEquip => '알 수 없는 장비';

  @override
  String get noBonusStats => '장비 능력치 없음';

  @override
  String get condition => '컨디션';

  @override
  String get noExpeditionFleet => '원정 중인 함대가 없습니다';

  @override
  String get expeditionInProgress => '원정 진행 중';

  @override
  String get progress => '진행도';

  @override
  String get unlocked => '미해금';

  @override
  String get notRepairing => '입거하지 않음';

  @override
  String get repairProgress => '수리 진행도';

  @override
  String get cost => '소모';

  @override
  String get notConstructing => '건조하지 않음';

  @override
  String get lsc => '대형함 건조';

  @override
  String get normalConstruct => '일반 건조';

  @override
  String get constructing => '건조 중';

  @override
  String get constructProgress => '건조 진행도';

  @override
  String get constructComplete => '건조 완료';

  @override
  String get allRatings => '모든 평가';

  @override
  String get noBattleRecords => '전투 기록이 없습니다';

  @override
  String get autoRecordHint => '출격 후 자동으로 기록됩니다. 별도 조작은 필요하지 않습니다';

  @override
  String get thisSortie => '이번 출격';

  @override
  String get historicalRecords => '지난 전과';

  @override
  String get resourceTrend => '자원 추이';

  @override
  String get expeditionIncome => '원정 수익';

  @override
  String get noHistoricalRecords => '지난 전과가 없습니다';

  @override
  String get none => '없음';

  @override
  String get unknownNode => '알 수 없는 지점';

  @override
  String get noResourceRecords => '자원 기록이 없습니다';

  @override
  String get resourceTrend24h => '24시간';

  @override
  String get resourceTrend7d => '7일';

  @override
  String get resourceTrend30d => '30일';

  @override
  String get resourceTrendAll => '전체 기록';

  @override
  String get resourceTrendMainGroup => '4종 자원';

  @override
  String get resourceTrendAuxGroup => '보조 자원';

  @override
  String get gadgetBypass => '게임 리소스 미러 및 IP 제한 우회';

  @override
  String get gadgetBypassDesc =>
      '켜면 미러를 통해 게임 클라이언트의 정적 리소스를 불러옵니다. DMM 지역 제한 호환 처리는 자동으로 적용되며 이 스위치의 영향을 받지 않습니다.';

  @override
  String get gadgetBypassEnable => '미러 경유 활성화';

  @override
  String get gadgetBypassEndpoint => '미러 엔드포인트';

  @override
  String get endpointCustom => '사용자 지정';

  @override
  String get gadgetBypassStatusOn => '활성화됨';

  @override
  String get gadgetBypassStatusOff => '비활성화됨';

  @override
  String get gadgetBypassUnsupported => '이 기기에서는 지원하지 않습니다 (Android 8.0 이상 필요)';

  @override
  String get gadgetBypassClearCache => '캐시 비우기';

  @override
  String get gadgetBypassError => '우회 설정 실패';

  @override
  String get gadgetBypassDiagnose => '403 오류 및 미러 연결 확인';

  @override
  String get gadgetBypassDiagnosing => '진단 중...';

  @override
  String get gadgetBypassW00g => '클라이언트 서버 (w00g)';

  @override
  String get gadgetBypassEndpointProbe => '미러 엔드포인트';

  @override
  String get gadgetBypassKcsapi => '게임 데이터 API (kcsapi)';

  @override
  String get gadgetBypassReachable => '연결 가능';

  @override
  String get gadgetBypassUnreachable => '연결 불가';

  @override
  String get resourceTrendChart => '자원 추이 (최근 100개 기록)';

  @override
  String get steel => '강재';

  @override
  String get bauxite => '보크사이트';

  @override
  String get noExpeditionRecords => '원정 기록이 없습니다';

  @override
  String get expeditionIncomeChart => '원정 수익 통계 (최근 7일)';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhHant => '繁體中文';

  @override
  String get langJa => '日本語';

  @override
  String get node => '지점';

  @override
  String get friend => '아군';

  @override
  String get enemy => '적군';

  @override
  String get drop => '드롭';

  @override
  String get inExpedition => '원정 중';

  @override
  String get unknownProgress => '진행도 알 수 없음';

  @override
  String get waitingForPortDataDescription =>
      '게임에서 모항에 진입하거나 게임 페이지를 새로고침하면 자동으로 갱신됩니다';

  @override
  String get fleetNotFormed => '미편성';

  @override
  String get fleetStandby => '모항 대기';

  @override
  String get shipsCount => '척';

  @override
  String get noValue => '없음';

  @override
  String get lineOfSight => '색적';

  @override
  String get averageCondition => '최저 컨디션';

  @override
  String get moraleRecoveryCountdown => '회복까지 남은 시간';

  @override
  String get moraleRecovered => '회복 완료';

  @override
  String get toggleMoraleMetric => '눌러서 최저 컨디션과 회복까지 남은 시간 전환';

  @override
  String get losDetails => '색적 상세';

  @override
  String get airPowerDetails => '제공 상세';

  @override
  String get minimumValue => '최소';

  @override
  String get maximumValue => '최대';

  @override
  String get withoutBonus => '숙련도 보정 없음';

  @override
  String get showAirPowerDetails => '눌러서 제공 상세 보기';

  @override
  String get unknownShipType => '알 수 없는 함종';

  @override
  String get needsSupply => '보급 필요';

  @override
  String get equipmentDataWaiting => '장비 데이터 갱신 대기 중';

  @override
  String get highSpeed => '고속';

  @override
  String get lowSpeed => '저속';

  @override
  String get unknownEquipment => '알 수 없는 장비';

  @override
  String get noAdditionalStats => '장비 능력치 없음';

  @override
  String get fatigue => '컨디션';

  @override
  String get startupUpdateTitle => '새 버전이 있습니다';

  @override
  String get backgroundAudio => '백그라운드에서 소리 재생';

  @override
  String get backgroundAudioDesc => '켜면 앱이 백그라운드로 전환되어도 게임 소리를 계속 재생합니다.';

  @override
  String get backgroundGameRetention => '백그라운드에서 게임 유지';

  @override
  String get backgroundGameRetentionDesc =>
      '게임 실행 중 상시 알림을 표시하여 앱 전환 후 시스템이 세션을 종료할 가능성을 줄입니다. 배터리 소모가 늘어날 수 있습니다.';

  @override
  String get backgroundGameRetentionNotificationTitle => 'ヤハギ가 백그라운드에서 실행 중입니다';

  @override
  String get backgroundGameRetentionNotificationBody =>
      '게임 세션 유지 중 · 눌러서 게임으로 돌아가기';

  @override
  String get screenAwake => '화면 켜짐 유지';

  @override
  String get screenAwakeDesc =>
      '켜면 앱이 화면에 표시되는 동안 화면이 자동으로 꺼지지 않습니다. 배터리 소모가 늘어날 수 있습니다.';

  @override
  String get gameToolbar => '게임 도구 모음';

  @override
  String get toolbarAutoHide => '자동 숨기기';

  @override
  String get toolbarPersistent => '항상 표시';

  @override
  String get back => '뒤로';

  @override
  String get reload => '새로고침';

  @override
  String get home => '홈으로';

  @override
  String get enterDmm => 'DMM 로그인으로 이동';

  @override
  String get enableGameAudio => '게임 소리 켜기';

  @override
  String get disableGameAudio => '게임 소리 끄기';

  @override
  String get takeScreenshot => '스크린샷';

  @override
  String get screenshotSaving => '게임 스크린샷 저장 중…';

  @override
  String get fitGameScreen => '화면 크기에 맞추기';

  @override
  String get collapseToolbar => '도구 모음 접기';

  @override
  String get editDone => '편집 완료';

  @override
  String get retryWithSystemNetwork => '시스템 네트워크로 재시도';

  @override
  String get displayMode => '화면 방향';

  @override
  String get displayAuto => '자동';

  @override
  String get displayLandscape => '가로';

  @override
  String get displayPortrait => '세로';

  @override
  String get allRanks => '모든 평가';

  @override
  String battleFleetSummary(
    int friendAlive,
    int friendTotal,
    int enemyAlive,
    int enemyTotal,
  ) {
    return '아군 $friendAlive/$friendTotal　적군 $enemyAlive/$enemyTotal';
  }

  @override
  String dropLabel(String name) {
    return '드롭: $name';
  }

  @override
  String get item => '아이템';

  @override
  String get friendFinalStatus => '아군 최종 상태';

  @override
  String get enemyFinalStatus => '적군 최종 상태';

  @override
  String get enemyFleet => '적 함대';

  @override
  String airStateLabel(String label) {
    return '제공: $label';
  }

  @override
  String get postBattleWarningTitle => '대파 안전 경고';

  @override
  String get advanceWarningMissingHeadline => '응급수리 장비를 장착하지 않은 대파된 칸무스가 있습니다!';

  @override
  String get advanceWarningUnknownHeadline =>
      '대파된 칸무스의 응급수리 장비 장착 여부를 알 수 없습니다!';

  @override
  String get advanceWarningEquippedHeadline =>
      '대파된 칸무스가 응급수리 장비를 장착하고 있습니다. 남은 장비를 확인해 주세요.';

  @override
  String get advanceWarningEquippedBody =>
      '대파 상태에서 진격을 선택했습니다. 함선과 남은 응급수리 장비를 확인해 주세요.';

  @override
  String get advanceWarningMissing => '응급수리 장비 미장착';

  @override
  String get advanceWarningUnknown =>
      '응급수리 장비 장착 여부를 알 수 없습니다. 게임 내 장비를 확인해 주세요';

  @override
  String advanceWarningEquipped(String items) {
    return '장착: $items';
  }

  @override
  String get advanceWarningPersonnel => '응급수리요원';

  @override
  String get advanceWarningGoddess => '응급수리여신';

  @override
  String advanceWarningShipPosition(int fleet, int position) {
    return '제$fleet함대 · $position번함';
  }

  @override
  String get advanceWarningMuteSortie => '이번 출격에서는 다시 알리지 않기';

  @override
  String get postBattleWarningHeadline => '출격 함대에 대파된 칸무스가 있습니다!';

  @override
  String get postBattleWarningBody =>
      '대파 상태에서 진격을 선택했습니다! 다음 전투에 진입하지 않도록 즉시 조작을 중단해 주세요.';

  @override
  String get acknowledgeAndRetreat => '확인했습니다';

  @override
  String get postBattleWarningBanner =>
      '전투 후 안전 경고: 출격 함대에 대파된 칸무스가 있습니다! 퇴각해 주세요!';

  @override
  String get noActiveExpedition => '진행 중인 원정이 없습니다';

  @override
  String get noSortieWarnings => '출격 경고가 없습니다';

  @override
  String preSortieCriticalWarning(String fleetName) {
    return '$fleetName에 대파된 함선이 있습니다. 출격을 중단하세요!';
  }

  @override
  String preSortieSupplyWarning(String fleetName) {
    return '$fleetName에 보급하지 않은 칸무스가 있습니다';
  }

  @override
  String preSortieFatigueWarning(String fleetName) {
    return '$fleetName에 피로가 회복되지 않은 칸무스가 있습니다';
  }

  @override
  String preSortieMainEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 장비 부족 (일반 슬롯): $shipNames';
  }

  @override
  String preSortieExtraEquipmentWarning(String fleetName, String shipNames) {
    return '$fleetName 장비 부족 (보강증설 슬롯): $shipNames';
  }

  @override
  String get noPinnedQuests => '현재 진행 중인 임무가 없습니다';

  @override
  String get questsNeedSync => '임무 화면을 열어 정보를 동기화해 주세요';

  @override
  String get questAwaitingConfirmation => '목표 달성 (확인 대기)';

  @override
  String get waitingQuestData => '임무 데이터 대기 중';

  @override
  String get waitingQuestDataDesc => '게임 내 임무 목록을 열면 수락한 임무가 자동으로 동기화됩니다';

  @override
  String get diagnosticsAndAbout => '진단 및 앱 정보';

  @override
  String get safetyBoundary => '안전상 제한';

  @override
  String get applyingNetworkSettings => '네트워크 설정 적용 중…';

  @override
  String networkSettingsApplied(String message) {
    return '네트워크 설정을 적용했습니다: $message';
  }

  @override
  String get clearingProxy => '앱 내 프록시 해제 중…';

  @override
  String get systemNetworkRestored => '시스템 네트워크로 복원했습니다.';

  @override
  String screenshotSaved(String path) {
    return '게임 스크린샷을 갤러리에 저장했습니다: $path';
  }

  @override
  String get screenshotFailed => '게임 스크린샷을 저장하지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String startupUpdateMessage(String version) {
    return 'ヤハギ $version이(가) 출시되었습니다.';
  }

  @override
  String get gameStatusError => '게임 상태 오류';

  @override
  String get gameStatusErrorDesc =>
      '웹 페이지 또는 데이터 수집 상태에 이상이 있습니다. 설정에서 진단 정보를 확인해 주세요.';

  @override
  String get browserOnlyCaptureOff => '브라우저 전용 모드 · 데이터 수집 꺼짐';

  @override
  String get browserOnlyCaptureOffDesc =>
      '게임 페이지는 계속 실행되며 함대, 임무, 전투 정보 갱신은 중지됩니다.';

  @override
  String capturedCount(int count) {
    return '$count건 수집됨';
  }

  @override
  String get waitingKcsapi => '/kcsapi/ 응답 대기 중';

  @override
  String get ignoredNonTargetMessage => '대상이 아닌 메시지를 무시했습니다';

  @override
  String get readOnlyNoActions => '읽기 전용';

  @override
  String get readOnlyNoActionsDesc =>
      '클릭, 보급, 편성, 출격, 임무 보상 수령을 자동으로 실행하지 않습니다.';

  @override
  String get noCookieRead => 'Cookie를 읽지 않음';

  @override
  String get noCookieReadDesc =>
      'JS 브리지는 API 경로, 민감한 매개변수를 제외한 요청 정보와 응답 등의 게임 데이터를 수집하며 Cookie는 읽지 않습니다.';

  @override
  String get browserIdle => '웹 페이지 대기 중';

  @override
  String get browserLoading => '웹 페이지 로드 중';

  @override
  String get browserReady => '웹 페이지 준비 완료';

  @override
  String get browserFailed => '웹 페이지 로드 실패';

  @override
  String get capturePreparing => '게임 API 수집 준비 중';

  @override
  String get captureReady => '수집 준비 완료';

  @override
  String get captureActive => '게임 API 수집 중';

  @override
  String get captureUnsupported => '현재 WebView는 프레임 간 데이터 수집을 지원하지 않습니다';

  @override
  String get captureFailed => '게임 API 수집 시작 실패';

  @override
  String get captureCheckingDesc => 'Android WebView의 데이터 수집 지원 여부를 확인 중입니다.';

  @override
  String get captureReadyDesc =>
      '/kcsapi/ 응답을 기다리고 있습니다. 게임은 정상적으로 조작할 수 있습니다.';

  @override
  String get portCaptureVerified => '모항 API 검증 완료';

  @override
  String get captureReceived => '게임 API를 수신했습니다.';

  @override
  String captureLatest(String path) {
    return '최근 수집: $path';
  }

  @override
  String get captureUnsupportedDesc =>
      '게임은 실행할 수 있습니다. 이 기기에서는 웹 페이지 열람만 지원합니다.';

  @override
  String get captureFailedDesc => '게임은 실행할 수 있습니다. 페이지를 새로고침한 후 다시 시도해 주세요.';

  @override
  String networkApplyFailed(String code, String message) {
    return '설정 실패 [$code]: $message';
  }

  @override
  String networkRestoreFailed(String code, String message) {
    return '복원 실패 [$code]: $message';
  }

  @override
  String get tcpConnection => 'TCP 연결';

  @override
  String get gameService => '게임 서비스';

  @override
  String get externalNetwork => 'Google (외부 네트워크)';

  @override
  String get statusUnknown => '알 수 없음';

  @override
  String get statusSuccess => '성공';

  @override
  String get statusFailed => '실패';

  @override
  String get statusSkipped => '건너뜀';

  @override
  String get formula33 => '33식';

  @override
  String fatigueValue(int value) {
    return '컨디션 $value';
  }

  @override
  String get fcdMapSectionTitle => '데이터 업데이트';

  @override
  String get fcdMapDataTitle => '전투 예측 데이터';

  @override
  String fcdMapDataVersion(String version) {
    return '데이터 버전: $version';
  }

  @override
  String fcdMapLastChecked(String time) {
    return '최근 확인: $time';
  }

  @override
  String get fcdMapNeverChecked => '최근 확인: 확인한 적 없음';

  @override
  String fcdMapSource(String source) {
    return '업데이트 출처: $source';
  }

  @override
  String get fcdMapAttribution => '데이터 출처: poi FCD (MIT)';

  @override
  String get fcdMapCheckUpdates => '전투 예측 데이터 업데이트 확인';

  @override
  String get fcdMapUpToDate => '전투 예측 데이터가 최신 버전입니다.';

  @override
  String fcdMapUpdated(String oldVersion, String newVersion) {
    return '전투 예측 데이터를 $oldVersion에서 $newVersion(으)로 업데이트했습니다. 즉시 적용되었습니다.';
  }

  @override
  String get fcdMapNetworkError => '데이터 업데이트 서버에 연결하지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get fcdMapValidationError => '다운로드한 데이터를 검증하지 못해 현재 버전을 유지했습니다.';

  @override
  String get fcdMapStorageError => '데이터를 저장하지 못해 현재 버전을 유지했습니다.';

  @override
  String get questCatalogDataTitle => '임무 데이터';

  @override
  String questCatalogDataVersion(String version) {
    return '데이터 버전: $version';
  }

  @override
  String get questCatalogNeverChecked => '최근 확인: 확인한 적 없음';

  @override
  String questCatalogLastChecked(String time) {
    return '최근 확인: $time';
  }

  @override
  String get questCatalogCheckUpdates => '임무 데이터 업데이트 확인';

  @override
  String get questCatalogUpToDate => '임무 데이터가 최신 버전입니다.';

  @override
  String questCatalogUpdated(String oldVersion, String newVersion) {
    return '임무 데이터를 $oldVersion에서 $newVersion(으)로 업데이트했습니다. 즉시 적용되었습니다.';
  }

  @override
  String get questCatalogNetworkError =>
      '임무 데이터 업데이트 서버에 연결하지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get questCatalogValidationError =>
      '다운로드한 임무 데이터를 검증하지 못해 현재 버전을 유지했습니다.';

  @override
  String get questCatalogStorageError => '임무 데이터를 저장하지 못해 현재 버전을 유지했습니다.';

  @override
  String get gameFrameRateTitle => '게임 프레임 속도';

  @override
  String get gameFrameRateAutomatic => '자동';

  @override
  String get gameFrameRateStable60 => '60 FPS';

  @override
  String get gameFrameRateStable60Desc => '항상 60 FPS로 실행하며 자동으로 낮추지 않습니다.';

  @override
  String get gameFrameRateStable30 => '30 FPS';

  @override
  String get gameFrameRateStable30Desc => '항상 30 FPS로 실행하여 배터리 소모와 발열을 줄입니다.';

  @override
  String get gameFrameRateHighRefresh => '높은 주사율';

  @override
  String get gameFrameRateHighRefreshDesc =>
      '60 FPS 제한을 해제하고 화면 주사율에 맞춰 실행합니다. 배터리 소모와 발열이 늘어날 수 있습니다.';

  @override
  String get gameFrameRateHighRefreshDialogTitle => '높은 주사율 모드를 켤까요?';

  @override
  String get gameFrameRateHighRefreshDialogBody =>
      '게임의 실행 프레임 속도가 변경됩니다. 배터리 소모와 발열이 늘거나 애니메이션에 이상이 생길 수 있으며, 계정에 대한 알려지지 않은 위험도 있습니다. 결과는 사용자가 책임집니다.';

  @override
  String get gameFrameRateHighRefreshDialogConfirm => '위험을 이해하고 켜기';

  @override
  String get gameFrameRateAutomaticDesc =>
      '최대 60 FPS로 실행합니다. 불안정한 상태가 지속되거나 시스템 절전 모드가 켜져 있거나 기기가 과열되면 자동으로 30 FPS로 낮춥니다.';

  @override
  String get gameFrameRateUnsupported =>
      '현재 Android WebView는 프레임 속도 조정을 지원하지 않아 게임의 원래 프레임 속도를 유지합니다.';

  @override
  String get gameRenderingModeTitle => '게임 렌더링 모드';

  @override
  String get gameRenderingModeStandard => '경량 모드';

  @override
  String get gameRenderingModeStandardDesc =>
      'Flutter PlatformView + Texture Layer + WebGL. 일부 합성 부하를 줄이지만 기기에 따라 화면 표시나 터치 호환 문제가 생길 수 있습니다.';

  @override
  String get gameRenderingModeCompatibility => '균형 모드';

  @override
  String get gameRenderingModeCompatibilityDesc =>
      'Flutter PlatformView + Hybrid Composition + WebGL. 게임 성능과 기기 호환성을 함께 고려합니다.';

  @override
  String get gameRenderingModeCanvas => '호환 모드';

  @override
  String get gameRenderingModeCanvasDesc =>
      'Flutter PlatformView + Hybrid Composition + Canvas. WebGL을 우회하여 GPU / WebGL 호환 문제 해결을 우선합니다. 화면 성능이 낮아질 수 있습니다.';

  @override
  String get gameRenderingModeNativeActivity => '네이티브 독립 렌더링 (권장)';

  @override
  String get gameRenderingModeNativeActivityDesc =>
      'Activity Direct WebView + WebGL. 이론적으로 합성 부하가 더 낮고 네이티브 호환성이 더 좋습니다.';

  @override
  String get gameRenderingModeConfirmTitle => '게임 렌더링 모드를 전환할까요?';

  @override
  String get gameRenderingModeConfirmMessage =>
      '렌더링 모드를 전환하면 앱이 자동으로 다시 시작되며 게임 페이지를 다시 불러옵니다. 진행 중인 조작을 먼저 마쳐 주세요.';

  @override
  String get gameRenderingModeBattleWarning =>
      '전투 중일 가능성이 감지되었습니다. 지금 전환하면 현재 전투 페이지가 중단될 수 있으니 전투를 마친 후 전환해 주세요.';

  @override
  String get gameRenderingModeChanging => '게임 페이지 재구성 중…';

  @override
  String get gameRenderingModeApplied => '렌더링 모드를 전환했습니다.';

  @override
  String get gameRenderingModeFailed =>
      '전환하지 못했습니다. 기존 설정을 유지하거나 안전한 모드로 복원했습니다.';

  @override
  String get nativeGameSurfaceSwitchRenderingModeHint =>
      '현재 기기는 이 모드와 호환되지 않습니다. 왼쪽 메뉴를 스크롤하여 [설정 - 게임 실행]에서 렌더링 모드를 전환해 주세요.';

  @override
  String nativeGameSurfacePageInitializationFailed(
    String stage,
    String errorType,
  ) {
    return '게임 페이지 초기화 실패 [$stage]: $errorType';
  }

  @override
  String get senka => '전과';

  @override
  String get ownedInventory => '보유 목록';

  @override
  String get improvement => '개수';

  @override
  String get briefing => '요약';

  @override
  String get check => '점검';

  @override
  String get restoreDefaultOrder => '기본 정렬 복원';

  @override
  String get sortAscending => '오름차순';

  @override
  String get sortDescending => '내림차순';

  @override
  String sortPriority(int priority) {
    return '우선순위 $priority';
  }

  @override
  String get sortLockedState => '잠김';

  @override
  String get sortTemporaryState => '임시 정렬';

  @override
  String get sortHeaderHint => '눌러서 정렬 전환 · 길게 누르거나 Shift+Enter로 고정';

  @override
  String get sortHeaderLockedHint =>
      '눌러서 정렬 방향 전환 · 길게 누르거나 Shift+Enter로 고정 해제';

  @override
  String get sortLockAction => '다음 우선순위로 고정';

  @override
  String get sortUnlockAction => '현재 정렬 고정 해제';

  @override
  String get settingsTabScreen => '외관 및 배치';

  @override
  String get settingsTabSound => '소리';

  @override
  String get settingsTabBattle => '출격 및 전투';

  @override
  String get settingsTabNotification => '알림 및 리마인더';

  @override
  String get settingsTabNetwork => '네트워크 및 연결';

  @override
  String get settingsTabData => '데이터 관리';

  @override
  String get settingsTabAboutSupport => '정보 및 지원';

  @override
  String get notificationSectionSystem => '시스템 알림 상태';

  @override
  String get notificationSectionSystemDesc =>
      '알림 및 정확한 알람 권한을 허용하면 화면이 잠겨 있거나 앱이 백그라운드에 있을 때에도 원정·입거 알림 등을 제때 받을 수 있으며, 시스템 절전 정책에 따른 지연을 줄일 수 있습니다. 해당 항목을 누르면 시스템 설정으로 이동합니다.';

  @override
  String get notificationPermissionGranted => '알림 권한 허용됨';

  @override
  String get notificationPermissionDenied => '알림 권한 허용 안 됨';

  @override
  String get notificationExactAlarmGranted => '정확한 알람 허용됨';

  @override
  String get notificationExactAlarmDenied => '정확한 알람이 허용되지 않아 절전 호환 모드를 사용합니다';

  @override
  String get notificationChannelsEnabled => '알림 채널 사용 가능';

  @override
  String get notificationChannelsDisabled => '시스템에서 알림 채널을 껐습니다';

  @override
  String get notificationSectionGeneral => '전체 알림 서비스';

  @override
  String get notificationEnableMaster => '알림 서비스 활성화';

  @override
  String get notificationSound => '알림 소리';

  @override
  String get notificationVibration => '진동 알림';

  @override
  String get notificationSectionOngoing => '백그라운드 상시 진행 상황';

  @override
  String get notificationOngoingLive => '상시 실시간 진행률 카드';

  @override
  String get notificationProgress => '진행 막대';

  @override
  String get notificationPercent => '백분율';

  @override
  String get notificationCountdown => '실시간 남은 시간';

  @override
  String get notificationSectionTypes => '알림 유형 및 시점';

  @override
  String get notificationExpedition => '원정';

  @override
  String get notificationRepair => '입거';

  @override
  String get notificationAnchorage => '정박지';

  @override
  String get notificationConstruction => '건조';

  @override
  String get notificationMorale => '피로도 / 반짝이';

  @override
  String get notificationPunctual => '완료 시각';

  @override
  String get notificationPreempt30s => '30초 전';

  @override
  String get notificationPreempt60s => '60초 전';

  @override
  String get notificationPreempt120s => '2분 전';

  @override
  String get notificationRepairPunctual => '완료 시각';

  @override
  String get notificationAnchorage20m => '20분 경과 후 첫 수리';

  @override
  String get notificationAnchorageFull => '모두 수리 완료';

  @override
  String get notificationAnchorageBoth => '두 시점 모두 알림';

  @override
  String get frameRateSettingsSection => '프레임 속도 설정';

  @override
  String get battleAlertsSection => '전투 알림';

  @override
  String get battleDamageVibration => '전투 손상 진동 알림';

  @override
  String get battleDamageVibrationDesc =>
      '아군 칸무스가 전투 중 중파 또는 대파 상태가 되는 순간 진동으로 알립니다.';

  @override
  String get battleStatusEffectsSection => '전투 상태 효과';

  @override
  String get battleStatusEffectsEnabled => '상태 효과 활성화';

  @override
  String get battleStatusEffectsEnabledDesc =>
      '손상 점멸, 손상 진동, 사기 반짝임을 함께 켜거나 끕니다.';

  @override
  String get battleEffectDisplayScope => '화면 표시 범위';

  @override
  String get battleEffectDisplayScopeDesc =>
      '손상 점멸과 사기 반짝임을 표시할 칸무스 화면을 선택합니다.';

  @override
  String get battleEffectScopePredictionOnly => '전투 예측만';

  @override
  String get battleEffectScopeFleetOnly => '함대 편성만';

  @override
  String get battleEffectScopeAll => '전체';

  @override
  String get battleDamagePulse => '손상 점멸';

  @override
  String get battleDamagePulseDesc => '현재 HP의 손상 단계에 따라 초상화 테두리가 점멸합니다.';

  @override
  String get battleDamageVibrationEffect => '손상 진동';

  @override
  String get battleDamageVibrationEffectDesc =>
      '아군 칸무스가 전투 중 선택한 손상 상태가 되는 순간 진동으로 알립니다.';

  @override
  String get battleMoraleSparkle => '사기 반짝임 효과';

  @override
  String get battleMoraleSparkleDesc =>
      'Cond ≥ 50일 때 칸무스 초상화 주변에 점멸하거나 계속 빛나는 별을 표시합니다. 피로도 표정과 피로 경고에는 영향을 주지 않습니다.';

  @override
  String get battleMoraleSparkleBlinking => '점멸';

  @override
  String get battleMoraleSparkleSteady => '계속 켜짐';

  @override
  String get battleEffectOff => '끄기';

  @override
  String get battleEffectMinorOnly => '소파만';

  @override
  String get battleEffectModerateOnly => '중파만';

  @override
  String get battleEffectHeavyOnly => '대파만';

  @override
  String get battleEffectAll => '모두 켜기';

  @override
  String get battlePredictionSection => '전투 예측';

  @override
  String get battleEnemyPreviewPortraits => '전투 전 적군 일러스트';

  @override
  String get battleEnemyPreviewPortraitsDesc => '전투 예측에 전투 전 적군 일러스트를 표시합니다.';

  @override
  String get battleLastFormationHint => '이전에 선택한 진형 표시';

  @override
  String get battleLastFormationHintDesc =>
      '출격 지점에 도달하면 전투 예측에 해당 지점에서 이전에 사용한 진형을 표시합니다.';

  @override
  String get battleEnemyPreviewPosition => '전투 전 적 함대 예측 위치';

  @override
  String get battleEnemyPreviewPositionDesc =>
      '전투 전 적 함대 예측을 아군 HP 막대 위 또는 아래에 표시합니다.';

  @override
  String get battleEnemyPreviewPositionAbove => '위';

  @override
  String get battleEnemyPreviewPositionBelow => '아래';

  @override
  String get battleSectionOrder => '정보 영역 순서';

  @override
  String get battleSectionOrderDescription => '정보 영역의 표시 순서를 조정합니다';

  @override
  String get battleSectionOrderAdjust => '조정';

  @override
  String get battleSectionOrderHint => '위아래 화살표를 눌러 조정하면 자동으로 저장됩니다';

  @override
  String get battleSectionSortieMap => '해역 미니맵';

  @override
  String get battleSectionEnemyPreview => '적군 예측';

  @override
  String get battleSectionPredictionResult => '예측 결과';

  @override
  String get battleSectionOrderRestoreDefault => '기본값 복원';

  @override
  String get battleSectionOrderSaveFailed => '저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String battleSectionOrderMoveUp(String section) {
    return '$section 위로 이동';
  }

  @override
  String battleSectionOrderMoveDown(String section) {
    return '$section 아래로 이동';
  }

  @override
  String battleLastFormation(String formation) {
    return '이전: $formation';
  }

  @override
  String get improvementDatasetTitle => '개수 계획 데이터';

  @override
  String improvementDatasetVersion(String version) {
    return '데이터 버전 $version';
  }

  @override
  String get improvementDatasetNeverChecked => '직접 확인한 적 없음';

  @override
  String improvementDatasetLastChecked(String time) {
    return '최근 확인 $time';
  }

  @override
  String get improvementDatasetManualUpdate => '개수 데이터 직접 업데이트';

  @override
  String improvementDatasetUpToDate(String version) {
    return '최신 데이터를 사용 중입니다 ($version)';
  }

  @override
  String improvementDatasetUpdated(String oldVersion, String newVersion) {
    return '개수 데이터를 $oldVersion에서 $newVersion(으)로 업데이트하고 즉시 화면을 갱신했습니다.';
  }

  @override
  String improvementDatasetNetworkError(String version) {
    return '네트워크 연결에 실패하여 로컬 데이터($version)를 계속 사용합니다.';
  }

  @override
  String improvementDatasetValidationError(String version) {
    return '원격 데이터를 검증하지 못해 로컬 데이터($version)를 유지했습니다.';
  }

  @override
  String improvementDatasetStorageError(String version) {
    return '데이터를 저장하지 못해 로컬 데이터($version)를 유지했습니다.';
  }

  @override
  String get networkValidationHostEmpty => '주소를 입력해 주세요';

  @override
  String get networkValidationControlCharacter => '줄바꿈 또는 제어 문자를 포함할 수 없습니다';

  @override
  String get networkValidationHttpScheme => 'http://를 제외한 서버 주소만 입력해 주세요.';

  @override
  String get networkValidationSocksScheme => 'socks://를 제외한 서버 주소만 입력해 주세요.';

  @override
  String get networkValidationScheme => '주소에서 프로토콜 접두사를 제외해 주세요';

  @override
  String get networkValidationPath => '경로를 포함할 수 없습니다';

  @override
  String get networkValidationCredentials => '사용자 이름이나 비밀번호를 포함할 수 없습니다';

  @override
  String get networkValidationIpv6 => 'IPv6 주소 형식이 잘못되었습니다 (허용되지 않는 문자 포함)';

  @override
  String get networkValidationPortEmpty => '포트를 입력해 주세요';

  @override
  String get networkValidationPortDecimal => '포트에 소수를 사용할 수 없습니다';

  @override
  String get networkValidationPortNegative => '포트에 음수를 사용할 수 없습니다';

  @override
  String get networkValidationPortZero => '포트는 0일 수 없습니다';

  @override
  String get networkValidationPortInteger => '포트는 정수여야 합니다';

  @override
  String get networkValidationPortRange => '포트는 1부터 65535까지 입력할 수 있습니다';

  @override
  String get gadgetBypassRestricted => '제한됨';

  @override
  String get networkProxyOperationBusy => '프록시 설정을 적용 중입니다';

  @override
  String get networkUnknownProxyMode => '알 수 없는 프록시 모드';

  @override
  String get shipGirl => '칸무스';

  @override
  String get equipment => '장비';

  @override
  String get inventoryTypeSuffix => '종';

  @override
  String get inventoryFilterResults => '필터 결과 ';

  @override
  String get inventoryOwned => '보유';

  @override
  String get inventoryUnowned => '미보유';

  @override
  String unownedShipSummary(int count, int excluded) {
    return '$count척 표시 · $excluded척 제외';
  }

  @override
  String get unownedShipExcludedLabel => '제외됨';

  @override
  String get unownedShipReminderHint =>
      '체크하지 않은 칸무스를 획득하면 알림과 진동으로 알려줍니다. 체크한 칸무스는 알리지 않습니다.';

  @override
  String get clearNewShipExclusions => '제외 목록 초기화';

  @override
  String get resetFilter => '필터 초기화';

  @override
  String unownedEquipmentSummary(int count) {
    return '미보유 장비 $count개 표시';
  }

  @override
  String get otherType => '기타';

  @override
  String newShipFallbackName(int id) {
    return '칸무스 No.$id';
  }

  @override
  String get newShipAlertTitle => '미보유 칸무스 발견';

  @override
  String newShipAlertBody(String names) {
    return '$names · 잠금 설정을 잊지 마세요';
  }

  @override
  String get acknowledge => '확인';

  @override
  String get shipName => '함명';

  @override
  String get shipType => '함종';

  @override
  String get level => '레벨';

  @override
  String get armor => '장갑';

  @override
  String get luck => '운';

  @override
  String get evasion => '회피';

  @override
  String get lockedStatus => '잠금';

  @override
  String get equipmentName => '장비명';

  @override
  String get equipmentTotalRemaining => '총수 (남은 수)';

  @override
  String get equipmentImprovementProficiency => '개수 / 숙련도';

  @override
  String get equipmentOfficialId => '공식 ID';

  @override
  String get equipmentInstanceId => '인스턴스 ID';

  @override
  String get equipmentUsage => '장착 상태';

  @override
  String get highSpeedPlus => '고속+';

  @override
  String get all => '전체';

  @override
  String get equipmentMainGun => '주포';

  @override
  String get equipmentSecondaryGun => '부포 / 고각포';

  @override
  String get equipmentMachineGun => '기총';

  @override
  String get equipmentTorpedo => '어뢰 / 특수잠항정';

  @override
  String get equipmentCarrierAircraft => '함재기';

  @override
  String get equipmentSeaplane => '수상기';

  @override
  String get equipmentLandBasedAircraft => '육상기';

  @override
  String get equipmentRadar => '전탐';

  @override
  String get equipmentLandingTransport => '상륙 / 수송';

  @override
  String get equipmentSupport => '보조 / 기타';

  @override
  String get questAll => '전체 임무';

  @override
  String get chineseTranslation => '중국어 번역';

  @override
  String get searchQuest => '임무 검색';

  @override
  String get filterQuest => '임무 필터';

  @override
  String get searchQuestHint => '번호, 임무명, 설명, 보상 검색 · 공백으로 구분한 키워드 중 하나 이상 포함';

  @override
  String get questAvailable => '미수락';

  @override
  String get questAcceptedOnly => '수락한 임무만 (보상 수령 대기 포함)';

  @override
  String get questClaimable => '보상 수령 대기';

  @override
  String get questInferredCompleted => '완료 추정';

  @override
  String get questStateUnknown => '상태 알 수 없음';

  @override
  String get questFilterHelp =>
      '해금됨에는 미수락·진행 중·보상 수령 대기가 포함됩니다. 미해금에는 상태 불명이 포함되며, 완료에는 보상 수령 대기와 완료 추정이 포함됩니다.';

  @override
  String get questNoResults => '조건에 맞는 임무가 없습니다';

  @override
  String get questNoResultsHint => '검색 내용을 바꾸거나 필터를 지워 보세요.';

  @override
  String questResultsCount(int count) {
    return '총 $count개 임무';
  }

  @override
  String get clear => '지우기';

  @override
  String get done => '완료';

  @override
  String get clearAll => '모두 지우기';

  @override
  String get questType => '임무 유형';

  @override
  String get allTypes => '모든 유형';

  @override
  String get questFormation => '편성';

  @override
  String get questSortie => '출격';

  @override
  String get questExercise => '연습';

  @override
  String get questSupplyRepair => '보급 / 입거';

  @override
  String get questFactory => '공창';

  @override
  String get questRemodeling => '개장';

  @override
  String get questPeriod => '임무 주기';

  @override
  String get allPeriods => '모든 주기';

  @override
  String get questSeasonal => '분기';

  @override
  String get questYearly => '연간';

  @override
  String get unlockStatus => '해금 상태';

  @override
  String get allStatuses => '모든 상태';

  @override
  String get questUnlocked => '해금됨';

  @override
  String get questLocked => '미해금';

  @override
  String get noDescription => '설명 없음';

  @override
  String get completionConditions => '완료 조건';

  @override
  String get questRelations => '임무 관계';

  @override
  String get prerequisiteQuests => '선행 임무';

  @override
  String get followingQuests => '후속 임무';

  @override
  String get notCompleted => '미완료';

  @override
  String get gameResourceCacheTitle => '게임 리소스 로컬 캐시';

  @override
  String get gameResourceCacheDesc =>
      '리소스는 艦隊これくしょん 공식 서버에서 받습니다. 캐시는 언제든 삭제할 수 있습니다.';

  @override
  String get gameResourceCacheNone => '임시 캐시';

  @override
  String get gameResourceCacheNoneDesc =>
      '미리 다운로드하지 않고 플레이 중 필요에 따라 캐시합니다. 최대 7일 및 2 GB까지 보관하며, 기간이나 용량을 초과하면 자동으로 정리합니다.';

  @override
  String get gameResourceCacheLight => '경량 캐시';

  @override
  String get gameResourceCacheLightDesc =>
      '시작 파일, 자주 쓰는 UI, 보유 칸무스 일러스트 및 장비 리소스를 캐시합니다.';

  @override
  String get gameResourceCacheFull => '로컬 캐시';

  @override
  String get gameResourceCacheFullDesc =>
      '기본 리소스(약 5.72 GB)를 미리 다운로드합니다. 완료를 기다리지 않고 다운로드 중에도 플레이할 수 있습니다. 새로운 콘텐츠는 플레이 중 자동으로 캐시합니다.';

  @override
  String get gameResourceCacheStart => '다운로드 시작';

  @override
  String get gameResourceCachePause => '다운로드 일시 정지';

  @override
  String get gameResourceCacheResume => '다운로드 계속';

  @override
  String get gameResourceCacheCheck => '무결성 검사';

  @override
  String get gameResourceCacheRepair => '누락 파일 받기 / 복구';

  @override
  String get gameResourceCacheClear => '로컬 캐시 삭제';

  @override
  String get gameResourceCacheIntegrityComplete => '현재 캐시가 완전합니다';

  @override
  String get gameResourceCacheMissing => '누락';

  @override
  String get gameResourceCacheDamaged => '손상';

  @override
  String get gameResourceCacheOutdated => '검사 대기';

  @override
  String get gameResourceCacheItems => '개';

  @override
  String gameResourceCacheStoredSize(String size) {
    return '$size 캐시됨';
  }

  @override
  String gameResourceCacheIntegritySummary(
    int missing,
    int damaged,
    int pending,
  ) {
    return '누락 $missing개 · 손상 $damaged개 · 검사 대기 $pending개';
  }

  @override
  String get gameResourceCachePendingRetained =>
      '검사 대기 중인 리소스는 로컬에 유지되며 자동으로 삭제하지 않습니다.';

  @override
  String get gameResourceCacheDownloadConfirmTitle => '캐시를 다운로드할까요?';

  @override
  String get gameResourceCacheDownloadConfirmDesc =>
      '공식 서버에서 선택한 모드의 리소스를 일괄 다운로드합니다. 언제든 일시 정지하고 계속할 수 있습니다.';

  @override
  String get gameResourceCacheMobileConfirmDesc =>
      '현재 모바일 네트워크를 사용 중입니다. 계속하면 모바일 데이터가 사용됩니다. 이번 다운로드를 허용할까요?';

  @override
  String get gameResourceCacheWaitingForWifi =>
      'Wi-Fi 연결 대기 중입니다. 연결되면 자동으로 다운로드를 계속합니다.';

  @override
  String get gameResourceCacheClearConfirmTitle => '게임 리소스 캐시를 삭제할까요?';

  @override
  String get gameResourceCacheClearConfirmDesc =>
      '다운로드한 게임 리소스를 삭제합니다. 모드 설정은 유지됩니다.';

  @override
  String get gameResourceCacheCapacityBlocked =>
      '저장 공간이 부족하거나 게임 리소스 로컬 캐시가 50 GB 한도에 도달했습니다.';

  @override
  String get gameResourceCacheActionFailed =>
      '캐시 작업을 완료하지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get gameResourceCacheUnsupported =>
      '현재 Android WebView는 게임 리소스 로컬 캐시를 지원하지 않습니다. WebView를 업데이트해 주세요.';

  @override
  String get gameResourceCacheUnavailable =>
      '로컬 캐시 초기화 또는 정리에 실패했습니다. 저장 공간을 확인하고 앱을 다시 시작해 주세요. 게임 페이지 이용에는 영향을 주지 않습니다.';

  @override
  String get gameResourceCacheManifestFailed =>
      '사전 로드 리소스 목록을 불러오지 못했습니다. 게임에 진입한 후 다시 시도해 주세요.';

  @override
  String get confirmGameRefreshTitle => '게임을 새로고침할까요?';

  @override
  String get gameRefreshDialogDescription =>
      '게임을 새로고침할까요?\n\n[게임 페이지 새로고침]은 브라우저 새로고침과 같습니다.\n[게임 다시 불러오기]는 게임 프레임 부분만 다시 불러오므로 보통 더 빠르지만, 고양이 오류나 네트워크 오류가 발생할 수 있습니다. 위험은 사용자가 부담합니다.';

  @override
  String get refreshGamePage => '게임 페이지 새로고침';

  @override
  String get reloadGame => '게임 다시 불러오기';

  @override
  String get frameRefreshShortcutLabel => '프레임 새로고침';

  @override
  String get frameRefreshShortcutConfirmTitle => '게임 프레임을 새로고침할까요?';

  @override
  String get frameRefreshShortcutConfirmDescription =>
      '게임 프레임만 다시 불러오면 보통 더 빠르지만 고양이 오류나 네트워크 오류가 발생할 수 있습니다. 위험은 사용자가 부담합니다.';

  @override
  String get frameRefreshShortcutSkipConfirmation => '다시 묻지 않기';

  @override
  String get frameRefreshShortcutConfirmAction => '새로고침';

  @override
  String get gameFrameNotFound => '게임 프레임을 찾지 못했습니다. 게임에 진입한 후 다시 시도해 주세요.';

  @override
  String get gameHtmlWrapNotFound => '게임 본체를 찾지 못했습니다. 페이지를 불러온 후 다시 시도해 주세요.';

  @override
  String get gameFrameReloadBlocked => '게임 프레임을 다시 불러오지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get gameFrameReloadUnsupported =>
      '이 기기의 Android WebView가 오래되어 하위 프레임 주입을 지원하지 않습니다.';

  @override
  String get logbookResourceDrop => '자원 드롭';

  @override
  String get logbookItemDrop => '아이템 드롭';

  @override
  String get logbookResourceNode => '자원 지점';

  @override
  String get logbookFriendFormation => '아군 진형';

  @override
  String get logbookEnemyFormation => '적군 진형';

  @override
  String get logbookAirSuperiority => '제공 상태';

  @override
  String get airSuperiorityParity => '항공 균형';

  @override
  String get airSuperioritySecured => '제공권 확보';

  @override
  String get airSuperiorityAdvantage => '항공 우세';

  @override
  String get airSuperiorityDisadvantage => '항공 열세';

  @override
  String get airSuperiorityLost => '제공권 상실';

  @override
  String get logbookHeavyDamageShips => '대파된 칸무스';

  @override
  String get gameConnectorTitle => '게임 연결';

  @override
  String get gameConnectorYahagi => 'Yahagi 연결';

  @override
  String get gameConnectorYahagiDesc => '현재 DMM 공식 로그인 페이지를 사용합니다.';

  @override
  String get gameConnectorOoi => 'OOI 연결 (실험적)';

  @override
  String get gameConnectorOoiDesc =>
      'ooi.moe 로그인 페이지를 그대로 엽니다. 모드 1, 3, 4 중 직접 선택하세요.';

  @override
  String get gameConnectorConfirmTitle => '게임 연결을 전환할까요?';

  @override
  String get gameConnectorOoiRisk =>
      '계정 인증 정보가 서드파티 사이트 ooi.moe로 전송됩니다. Yahagi는 계정이나 비밀번호를 읽거나 저장하거나 자동 입력하지 않습니다.';

  @override
  String get gameConnectorActiveWarning =>
      '전환하면 현재 게임 페이지가 중단되고 선택한 로그인 페이지로 이동합니다.';

  @override
  String get gameConnectorApplied => '게임 연결을 전환했습니다.';

  @override
  String get gameConnectorSaveFailed => '연결 선택을 저장하지 못했습니다. 현재 연결은 유지됩니다.';

  @override
  String get gameConnectorNavigationFailed =>
      '연결은 저장했지만 로그인 페이지를 열지 못했습니다. 다시 시도해 주세요.';

  @override
  String get kcwikiReportSection => 'KCWiki 데이터 기여';

  @override
  String get kcwikiReportTitle => 'KCWiki 데이터 수집 돕기';

  @override
  String get kcwikiReportDisabledDesc =>
      '기본값은 꺼짐입니다. 끄면 데이터를 수집·패키징·전송하지 않으며 게임과 로컬 기능에도 영향을 주지 않습니다.';

  @override
  String get kcwikiReportEnabledDesc =>
      '켜져 있습니다. 분기 조건, 임무 선행 조건, 전투, 우군, 기지항공대/공습 및 개수 데이터만 보냅니다.';

  @override
  String get kcwikiReportConfirmTitle => 'KCWiki 데이터 기여를 켤까요?';

  @override
  String get kcwikiReportConfirmDesc =>
      '켜면 앱이 설정된 HTTPS 주소로 분기 조건, 임무 선행 조건, 전투, 우군, 기지항공대/공습 및 개수 기록을 보냅니다. 로그인 토큰, Cookie, 요청 헤더는 보내지 않으며 업로드에 실패해도 게임 기능을 차단하지 않습니다.';

  @override
  String get kcwikiReportUnavailable =>
      '이 버전에는 안전한 HTTPS 보고 주소가 설정되지 않아 데이터 기여를 켤 수 없습니다.';

  @override
  String get kcwikiReportEnable => '자발적으로 켜기';

  @override
  String get kcwikiReportSaveFailed =>
      'KCWiki 데이터 기여 설정을 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String kcwikiReportCaptureFailed(String error) {
    return 'KCWiki 데이터 수집 전환 실패: $error';
  }

  @override
  String get kcwikiReportWaiting => '켜져 있습니다. 기여할 데이터를 기다리고 있습니다.';

  @override
  String kcwikiReportProcessing(String module, String time) {
    return '업로드 중: $module · $time';
  }

  @override
  String kcwikiReportParseRecovered(String time) {
    return '대용량 데이터 분석 시간 초과에서 복구되어 후속 데이터 처리를 계속합니다 · $time';
  }

  @override
  String kcwikiReportFailureHttp(String status) {
    return 'HTTP $status';
  }

  @override
  String get kcwikiReportFailureTimeout => '연결 시간 초과';

  @override
  String get kcwikiReportFailureNetwork => '네트워크 오류';

  @override
  String get kcwikiReportFailureBodyTooLarge => '1회 데이터 크기 한도 초과';

  @override
  String get kcwikiReportFailureQueueFull => '로컬 대기열 가득 참';

  @override
  String get kcwikiReportFailureLocal => '로컬 처리 실패';

  @override
  String kcwikiReportCounters(int succeeded, int failed, int dropped) {
    return '성공 $succeeded · 실패 $failed · 폐기 $dropped';
  }

  @override
  String kcwikiReportLastSuccess(
    String module,
    String time,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '최근 업로드 성공: $module · $time · 성공 $succeeded · 실패 $failed · 폐기 $dropped';
  }

  @override
  String kcwikiReportLastFailure(
    String module,
    String status,
    String time,
    int succeeded,
    int failed,
    int dropped,
  ) {
    return '최근 업로드 실패: $module ($status) · $time · 성공 $succeeded · 실패 $failed · 폐기 $dropped';
  }

  @override
  String get landBaseBrief => '기지항공대 요약';

  @override
  String get landBaseNoData => '데이터 없음';

  @override
  String landBaseAreaFallback(int areaId) {
    return '해역 $areaId';
  }

  @override
  String landBaseUnitCount(int count) {
    return '항공대 $count개';
  }

  @override
  String get landBaseRange => '행동 반경';

  @override
  String get landBaseActionSortie => '출격';

  @override
  String get landBaseActionAirDefense => '방공';

  @override
  String get landBaseActionRest => '휴식';

  @override
  String get landBaseActionRetreat => '퇴피';

  @override
  String get landBaseMissingPlanes => '기체 부족';

  @override
  String get landBaseRelocating => '배치 전환 중';

  @override
  String get senkaInfoTab => '전과 정보';

  @override
  String get senkaCalendarTab => '전과 달력';

  @override
  String get senkaCalculatorTab => '전과 계산';

  @override
  String get senkaSaveFailedWarning => '전과 데이터를 저장하지 못했습니다. 다시 시작하면 사라질 수 있습니다';

  @override
  String get senkaLatestRanking => '최근 랭킹 전과';

  @override
  String get senkaTarget => '목표 전과';

  @override
  String senkaGap(String value) {
    return '목표까지 전과 $value 남음';
  }

  @override
  String senkaOver(String value) {
    return '목표보다 전과 $value 초과';
  }

  @override
  String get senkaPlannedEo => '예정 EO';

  @override
  String get senkaPlannedQuest => '예정 임무';

  @override
  String get senkaDailyRequired => '일일 필요량';

  @override
  String get senkaTodayRemaining => '오늘 남은 양';

  @override
  String get senkaUnsettledDelta => '집계 이후 증가분';

  @override
  String get senkaAvailableDaysIncludingToday => '남은 일수 (오늘 포함)';

  @override
  String get senkaProjected => '예상 전과';

  @override
  String get senkaUnit => '전과';

  @override
  String senkaInputTitle(String label) {
    return '$label 입력';
  }

  @override
  String get senkaInvalidNumber => '올바른 숫자를 입력해 주세요';

  @override
  String get senkaPlannedEoReward => '예정 EO 전과 보상';

  @override
  String get senkaPlannedQuestReward => '예정 임무 전과 보상';

  @override
  String get senkaTotal => '합계';

  @override
  String get senkaEoRewards => 'EO 전과 보상';

  @override
  String get senkaQuarterlyQuests => '분기 전과 임무';

  @override
  String get senkaAnnualQuests => '연간 전과 임무';

  @override
  String get senkaOneTimeQuests => '단발 전과 임무';

  @override
  String get senkaRewardLegend =>
      '노란색＋✕: 보류 (예상 전과 제외), 초록색＋✓: 완료 예정 (예상 전과 포함), 회색＋○: 완료 (중복 계산 안 함).';

  @override
  String get senkaRewardDeferred => '보류';

  @override
  String get senkaRewardPlanned => '완료 예정 (예상 포함)';

  @override
  String get senkaRewardCompleted => '완료';

  @override
  String senkaCalendarTitle(int year, int month) {
    return '$year년 $month월 전과 달력';
  }

  @override
  String senkaCalendarSummary(String recorded, String base) {
    return '이번 달 기록 $recorded · 이번 달 기본 전과 $base';
  }

  @override
  String get senkaExperience => '경험치';

  @override
  String get senkaQuest => '임무';

  @override
  String senkaCalendarCell(int year, int month, int day, String value) {
    return '$year년 $month월 $day일, 전과 $value';
  }

  @override
  String get senkaServer => '소속 서버';

  @override
  String get senkaRanking => '전과 순위';

  @override
  String get senkaRank => '순위';

  @override
  String senkaUpdated(String time) {
    return '갱신: $time';
  }

  @override
  String get senkaOrder => '순위';

  @override
  String get senkaChange => '변동';

  @override
  String get senkaCurrent => '현재';

  @override
  String get senkaSortieStats => '출격 해역 통계';

  @override
  String get senkaLatestRecord => '최근 기록';

  @override
  String get senkaMonthSorties => '이번 달 출격';

  @override
  String get senkaBossArrivals => 'Boss 도달';

  @override
  String get senkaSWins => 'S 승리';

  @override
  String get senkaMonth => '이번 달';

  @override
  String get senkaToday => '오늘';

  @override
  String get senkaShowHiddenAreas => '숨긴 해역 표시';

  @override
  String get senkaShowHidden => '숨긴 항목 표시';

  @override
  String get senkaArea => '해역';

  @override
  String get senkaBoss => 'Boss';

  @override
  String get senkaSorties => '출격';

  @override
  String get senkaResult => 'S / A';

  @override
  String get senkaActions => '작업';

  @override
  String senkaFavoriteArea(String map) {
    return '해역 $map 즐겨찾기';
  }

  @override
  String senkaHideArea(String map) {
    return '해역 $map 숨기기';
  }

  @override
  String get senkaUnknownServer => '알 수 없는 서버';

  @override
  String get toolbox => '도구 상자';

  @override
  String get fleetExport => '데이터 내보내기';

  @override
  String get otherTools => '기타';

  @override
  String get noro6 => 'noro6';

  @override
  String get jervis => 'Jervis';

  @override
  String get exportToNoro6 => 'noro6로 내보내기';

  @override
  String get exportToNoro6Mirror => 'noro6로 내보내기 (중국 미러)';

  @override
  String get exportToJervis => 'Jervis로 내보내기';

  @override
  String get eventLandBasesOnly => '이벤트 해역의 기지항공대만 내보내기';

  @override
  String get landBaseExportLimitHint =>
      'DeckBuilder는 한 번에 최대 3개 항공대를 지원합니다. 필터를 끄면 수집한 순서대로 처음 3개 항공대를 내보냅니다.';

  @override
  String get fleetExportText => '함대 내보내기 텍스트';

  @override
  String get deckBuilderV4 => 'DeckBuilder v4';

  @override
  String get refreshExportText => '새로고침';

  @override
  String get copyExportText => '텍스트 복사';

  @override
  String get openInSystemBrowser => '시스템 기본 브라우저로 열기';

  @override
  String get otherToolsComingSoon => '다른 기능은 개발 중입니다';

  @override
  String get otherToolsHint => '추가 보조 도구가 이곳에 모입니다.';

  @override
  String get waitingForPortData => '모항 데이터 대기 중';

  @override
  String get externalFleetToolOpenFailed =>
      '외부 함대 도구를 열 수 없습니다. 브라우저가 설치되어 있는지 확인해 주세요.';

  @override
  String get fleetExportCopied => '함대 내보내기 텍스트를 복사했습니다.';

  @override
  String get fleetExportCopyFailed => '복사하지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String equipmentCompatibilitySummary(int owned, int all) {
    return '장착 가능: 보유 $owned / 전체 $all';
  }

  @override
  String equipmentCompatibilityOwnedTab(int count) {
    return '보유 칸무스 $count';
  }

  @override
  String equipmentCompatibilityAllTab(int count) {
    return '전체 칸무스 $count';
  }

  @override
  String equipmentCompatibilityOwnedCompact(int count) {
    return '보유 $count';
  }

  @override
  String equipmentCompatibilityAllCompact(int count) {
    return '전체 $count';
  }

  @override
  String get equipmentCompatibilitySelectShipType => '함종 선택';

  @override
  String get equipmentCompatibilitySearchHint => '칸무스 검색';

  @override
  String get equipmentCompatibilityAllSlots => '모든 슬롯';

  @override
  String get equipmentCompatibilityRegularSlot => '일반 슬롯';

  @override
  String get equipmentCompatibilityExpansionSlot => '보강증설 슬롯';

  @override
  String get equipmentCompatibilityBothSlots => '일반 슬롯＋보강증설 슬롯';

  @override
  String equipmentCompatibilityExpansionRequirement(int level) {
    return '보강증설 슬롯에 ★+$level 필요';
  }

  @override
  String equipmentCompatibilityOwnedLevels(String levels) {
    return 'Lv.$levels';
  }

  @override
  String equipmentCompatibilityFleetNumbers(String numbers) {
    return '제$numbers함대';
  }

  @override
  String get equipmentCompatibilityEmpty => '조건에 맞는 칸무스가 없습니다';

  @override
  String equipmentCompatibilityOfficialId(int id) {
    return '장비 ID $id';
  }

  @override
  String equipmentCompatibilityOwnedCount(int count) {
    return '보유 수 $count';
  }

  @override
  String equipmentCompatibilityRegularCount(int count) {
    return '일반 슬롯 $count';
  }

  @override
  String equipmentCompatibilityExpansionCount(int count) {
    return '보강증설 슬롯 $count';
  }

  @override
  String get equipmentCompatibilitySource => '규칙 출처: 게임 공식 마스터 데이터';

  @override
  String get equipmentCompatibilityRulesWaiting => '장비 규칙 데이터 갱신 대기 중';

  @override
  String get equipmentCompatibilityEmptyOwned => '장착 가능한 칸무스를 보유하고 있지 않습니다';

  @override
  String get equipmentCompatibilityEmptyAll => '장착 가능한 칸무스 형태를 찾지 못했습니다';

  @override
  String equipmentCompatibilityCategory(String category) {
    return '분류: $category';
  }

  @override
  String equipmentCompatibilityShipClassId(int id) {
    return '함급 #$id';
  }

  @override
  String get shipEquipmentCompatibilitySelectCategory => '장비 분류 선택';

  @override
  String get shipEquipmentCompatibilitySearchTitle => '장비 검색';

  @override
  String get shipEquipmentCompatibilitySearchHint => '장비명 입력';

  @override
  String shipEquipmentCompatibilityOwnedCount(int count) {
    return '보유 X$count';
  }

  @override
  String get shipEquipmentCompatibilityEmpty => '장착 가능한 장비를 찾지 못했습니다';

  @override
  String get equipmentDevelopment => '장비 개발';

  @override
  String get development => '개발';

  @override
  String get developmentCommandTitle => '개발 지휘대';

  @override
  String get developmentWorkbenchTitle => '개발 작업대';

  @override
  String get developmentCalculator => '개발 계산기';

  @override
  String get developmentFormula => '개발 레시피';

  @override
  String get developmentOutputProbability => '개발 확률';

  @override
  String get developmentFinalProbability => '최종 확률';

  @override
  String get developmentAvailableRecipes => '사용 가능한 레시피';

  @override
  String get developmentPoolType => '개발 풀 유형';

  @override
  String get developmentSelectSecretary => '비서함 유형 선택';

  @override
  String get developmentOtherSecretaryGroup => '기타';

  @override
  String get developmentEquipmentType => '유형';

  @override
  String get developmentSecretary => '비서함';

  @override
  String get developmentFuelShort => '연료';

  @override
  String get developmentAmmoShort => '탄약';

  @override
  String get developmentSteelShort => '강재';

  @override
  String get developmentBauxiteShort => '보크';

  @override
  String get developmentOutputRate => '개발 확률';

  @override
  String get developmentEquipment => '장비';

  @override
  String get developmentCurrentFlagship => '현재 기함';

  @override
  String get developmentUseFlagship => '현재 기함 사용';

  @override
  String get developmentFlagshipUnsupported =>
      '현재 기함에 맞는 개발 풀이 없어 기존 선택을 유지했습니다';

  @override
  String get developmentSelectPool => '비서함 유형';

  @override
  String get developmentCurrentRecipe => '현재 레시피';

  @override
  String get developmentTargetEquipment => '목표 장비';

  @override
  String get developmentChooseTarget => '목표 장비 선택';

  @override
  String get developmentSearchEquipment => '장비 검색';

  @override
  String get developmentSearchHint => '장비명 또는 ID 입력';

  @override
  String get developmentAllTypes => '모든 유형';

  @override
  String get developmentTargetDrops => '목표 장비';

  @override
  String get developmentOtherDrops => '기타 장비';

  @override
  String get developmentInsufficient => '자원 부족';

  @override
  String get developmentReplaced => '대체된 장비';

  @override
  String get developmentRecommendations => '추천 레시피';

  @override
  String get developmentNoTargets => '목표 장비를 선택하면 추천 레시피를 표시합니다';

  @override
  String get developmentNoResults => '모든 목표 장비를 개발할 수 있는 레시피가 없습니다';

  @override
  String get developmentTargetRate => '목표 장비 확률';

  @override
  String get developmentFailureRate => '실패 확률';

  @override
  String get developmentTotalResources => '총 자원';

  @override
  String get developmentApplyRecipe => '레시피 적용';

  @override
  String get developmentDataError => '장비 개발 데이터를 불러오지 못했습니다';

  @override
  String get developmentRetry => '재시도';

  @override
  String developmentSelectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get developmentPoolBauxite => '보크사이트 계열';

  @override
  String get developmentPoolAmmunition => '탄약 계열';

  @override
  String get developmentPoolFuelSteel => '연료·강재 계열';

  @override
  String get battlePredictionUnconfirmed =>
      '미확인 데이터: HP와 예측은 참고용입니다. 게임 화면을 기준으로 확인해 주세요.';

  @override
  String get mouseWheelCompatibility => '외장 마우스 휠 호환';

  @override
  String get mouseWheelCompatibilityDescription =>
      '외장 마우스의 휠이 게임에서 작동하지 않으면 켜 보세요. 즉시 적용되며 마우스 클릭과 터치도 계속 사용할 수 있습니다.';

  @override
  String get mouseWheelCompatibilitySaveFailed => '설정을 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get hdMode => 'HD 모드';

  @override
  String get hdModeDescription =>
      '큰 화면 기기에 최적화된 UI를 사용합니다 (8인치 이상 권장). 작은 화면 기기에서 강제로 켜면 화면 표시 오류, 레이아웃 넘침, 앱 종료 등이 발생할 수 있습니다.';

  @override
  String get hdBottomLayout => 'HD 하단 레이아웃';

  @override
  String get hdSplit => '1×1 두 개';

  @override
  String get hdWide => '1×2 한 개';

  @override
  String get hdLeftModule => '왼쪽 패널';

  @override
  String get hdRightModule => '오른쪽 패널';

  @override
  String get hdWideModule => '전체 너비 패널';

  @override
  String get hdCustomize => '레이아웃 편집';

  @override
  String get hdEditHint =>
      '핸들을 길게 눌러 순서를 바꾸거나 하단으로 옮기세요. 기존 패널 위에 놓으면 위치를 맞바꿉니다. 체크하면 표시하고 해제하면 숨깁니다.';

  @override
  String get hdHalfWidth => '절반 너비 1×1';

  @override
  String get hdFullWidth => '전체 너비 1×2';

  @override
  String get hdDropArea => '기능 패널 배치 영역';

  @override
  String get workspaceMenuPosition => '메뉴 위치';

  @override
  String get workspaceMenuPositionDesc => '위를 선택하면 게임 화면 바로 아래에 표시됩니다.';

  @override
  String get menuPositionTop => '위';

  @override
  String get menuPositionBottom => '아래';

  @override
  String get menuPositionLeft => '왼쪽';

  @override
  String get menuPositionRight => '오른쪽';

  @override
  String get topNoticeSectionTitle => '상단 메시지 알림';

  @override
  String get topNoticeEnabledTitle => '상단 알림';

  @override
  String get topNoticeEnabledSubtitle =>
      '상단의 「ヤハギ」 오른쪽에 개발, 개수, 출격 전 점검 및 임무 완료 알림을 표시합니다';

  @override
  String get topNoticeDurationTitle => '알림 표시 시간';

  @override
  String get topNoticeDurationSubtitle =>
      '알림 팝업이 표시된 후 조작하지 않으면 자동으로 닫히기까지의 시간';

  @override
  String get topNoticeDuration5s => '5초 (기본값)';

  @override
  String get topNoticeDuration10s => '10초';

  @override
  String get topNoticeDuration15s => '15초';

  @override
  String questCompletionSingleNotice(String title) {
    return '임무 달성: $title';
  }

  @override
  String questCompletionMultiNotice(int count) {
    return '임무 $count개를 달성했습니다. 임무 화면을 확인해 주세요';
  }

  @override
  String questPendingConfirmationSingleNotice(String title) {
    return '임무 목표 달성 (게임 확인 대기): $title';
  }

  @override
  String questPendingConfirmationMultiNotice(int count) {
    return '임무 $count개 목표 달성 (게임 확인 대기)';
  }

  @override
  String noticeDevSuccess(String name) {
    return '$name 개발 성공';
  }

  @override
  String get noticeDevFailed => '장비 개발 실패';

  @override
  String get noticeDevFailedPenguin => '장비 개발 실패';

  @override
  String get noticeDevSlotFailed => '개발 실패';

  @override
  String get noticeDevDefaultName => '새 장비';

  @override
  String get noticeEquipImproveSuccess => '장비 개수 성공';

  @override
  String get noticeEquipImproveFailed => '장비 개수 실패';

  @override
  String get noticeModFailed => '근대화개수 실패';

  @override
  String get noticeModSuccess => '근대화개수 성공';

  @override
  String noticeModSuccessDetail(String stats) {
    return '근대화개수 성공: $stats';
  }

  @override
  String get noticeModSuccessMaxCap => '근대화개수 성공 (능력치 상한 도달)';

  @override
  String get statFirepower => '화력';

  @override
  String get statTorpedo => '뇌장';

  @override
  String get statAntiAir => '대공';

  @override
  String get statArmor => '장갑';

  @override
  String get statLuck => '운';

  @override
  String get statHp => '내구';

  @override
  String get statAsw => '대잠';

  @override
  String noticeMarriageLuck(String arrow, int delta, int remaining) {
    return '결혼 운 상승: 운 $arrow +$delta / +$remaining';
  }

  @override
  String noticeMarriageLuckMax(String arrow, int delta) {
    return '결혼 운 상승: 운 $arrow +$delta / MAX';
  }

  @override
  String noticePracticeExp(int sExp, int aExp) {
    return '연습 경험치 (약): S 승리 $sExp · A 승리 $aExp';
  }

  @override
  String noticePracticeExpCtBonus(int sExp, int aExp, String bonus) {
    return '연습 경험치 (약): S 승리 $sExp · A 승리 $aExp (연습순양함 +$bonus)';
  }

  @override
  String get noticeSortieShipFull =>
      '모항 함선 보유 한도에 도달했습니다! 출격해도 새 칸무스를 획득할 수 없습니다';

  @override
  String noticeSortieShipLow(int count) {
    return '함선 여유 공간이 $count척 남았습니다. 모항 용량을 확인해 주세요';
  }

  @override
  String get noticeSortieItemFull => '장비 보유 한도에 도달했습니다! 출격해도 새 장비를 획득할 수 없습니다';

  @override
  String noticeSortieItemLow(int count) {
    return '장비 여유 공간이 $count개 남았습니다. 모항 용량을 확인해 주세요';
  }

  @override
  String get noticeSortieShipAndItemFull =>
      '함선과 장비 보유 한도에 도달했습니다! 출격해도 새 칸무스와 장비를 획득할 수 없습니다';

  @override
  String noticeSortieShipAndItemLow(int shipCount, int itemCount) {
    return '함선 여유 $shipCount척 · 장비 여유 $itemCount개. 모항 용량을 확인해 주세요';
  }

  @override
  String get noticeSortieExpansionSlotUnused => '함대에 미사용 보강증설 슬롯이 있습니다';

  @override
  String noticePreSortieCheckFailed(String reasons) {
    return '출격 전 점검 미통과: $reasons';
  }

  @override
  String get noticeSortieReasonUnresupplied => '보급 미완료';

  @override
  String get noticeSortieReasonFatigue => '칸무스 피로 (노란 얼굴 / 빨간 얼굴)';

  @override
  String get noticeSortieReasonMainSlot => '일반 장비 슬롯 미장착';

  @override
  String get noticeSortieReasonExpansionSlot => '보강증설 슬롯 미사용';

  @override
  String get lockUi => '화면 잠금';

  @override
  String get unlockUi => '화면 잠금 해제';

  @override
  String get uiLockedToast => '화면을 잠갔습니다. 레이아웃 편집은 비활성화되며 기능 전환은 계속 사용할 수 있습니다';

  @override
  String get uiUnlockedToast => '화면 잠금을 해제했습니다';

  @override
  String get uiLockTitle => '화면 레이아웃 잠금';

  @override
  String get uiLockDesc =>
      '잠그면 카드 및 상단 자원을 길게 눌러 편집하거나 탐색 메뉴를 드래그하여 정렬할 수 없습니다. 기능 페이지는 계속 전환할 수 있습니다';

  @override
  String get filterVisibleItems => '표시 항목 필터';

  @override
  String get selectHeaderVisibleItems => '상단 표시 항목 선택';

  @override
  String get expCalculator => '경험치 계산';

  @override
  String get expCalcShip => '칸무스';

  @override
  String get expCalcCurrentLevel => '현재 레벨';

  @override
  String get expCalcTargetLevel => '목표 레벨';

  @override
  String get expCalcMap => '해역';

  @override
  String get expCalcRank => '평가';

  @override
  String get expCalcBaseExp => '기본 경험치';

  @override
  String get expCalcFlagship => '기함';

  @override
  String get expCalcMvp => 'MVP';

  @override
  String get expCalcMapExp => '해역 경험치';

  @override
  String get expCalcRemainExp => '남은 경험치';

  @override
  String get expCalcBattle => '전투';

  @override
  String get expCalcEmptyTrackList => '육성 추적 계획이 없습니다. 위의 ＋를 눌러 추가하세요';

  @override
  String get expCalcBaseExpHelpTitle => '주요 해역 기본 경험치 참고';

  @override
  String get expCalcTrackAdded => '경험치 추적 목록에 추가했습니다';

  @override
  String get expCalcTrackDeleted => '경험치 추적 목록에서 제거했습니다';

  @override
  String get expCalcTrackLoadFailed => '추적 목록을 불러오지 못했습니다. 눌러서 다시 시도하세요';

  @override
  String get expCalcTrackSaveFailed => '추적 목록을 저장하지 못했습니다. 다시 시도해 주세요';

  @override
  String get expCalcFreeMode => '자유 계산 (칸무스 지정 없음)';

  @override
  String get expCalcAddNode => '전투 지점 추가 (연속 전투 누적)';

  @override
  String get expCalcRemoveNode => '지점 제거';

  @override
  String get expCalcRouteTotal => '출격 1회 총 경험치';

  @override
  String get expCalcNodePoint => '지점';

  @override
  String get expCalcRouteSummary => '출격 해역 경로';

  @override
  String get expCalcAddTrack => '실시간 추적 목록에 추가';

  @override
  String get expCalcCompletedTag => '0회 (달성 완료)';

  @override
  String get expCalcCardView => '카드';

  @override
  String get expCalcTableView => '표';

  @override
  String get expCalcTrackListTitle => '육성 추적 목록';

  @override
  String get expCalcAutoSyncHint => '모항 데이터가 바뀌면 남은 경험치와 횟수를 자동으로 갱신합니다';

  @override
  String get expCalcDelete => '삭제';

  @override
  String get expCalcStep1Title => '1단계 · 칸무스와 목표 레벨';

  @override
  String get expCalcStep2Title => '2단계 · 출격 해역 지점 및 전술 경로 구성';

  @override
  String get expCalcResultHudTitle => '출격 경로 종합 계산 결과';

  @override
  String get expCalcTargetGapLabel => '레벨업에 필요한 경험치';

  @override
  String get expCalcTargetAlignHint => '목표 경험치는 경험치 표에 자동으로 맞춰집니다';

  @override
  String get expCalcRouteSummaryPrefix => '현재 경로 합계';

  @override
  String get expCalcCombatNodesSuffix => '개 전투 지점';

  @override
  String get expCalcAccumulatedExpLabel => '누적 경험치';

  @override
  String get customFontTitle => '화면 글꼴';

  @override
  String get customFontDescription =>
      '원하는 글꼴을 가져온 뒤 미리 보고 적용하세요. TTF, OTF를 지원하며 최대 32 MB입니다.';

  @override
  String get customFontDefault => '기본 글꼴 (시스템 글자 크기)';

  @override
  String get customFontImport => '글꼴 가져오기';

  @override
  String get customFontRestore => '기본값 복원';

  @override
  String get customFontPreviewTitle => '글꼴 미리보기';

  @override
  String get customFontApply => '글꼴 적용';

  @override
  String get customFontPreviewSample => '함대 정보 · 출격 기록 · 화면 설정';

  @override
  String get customFontPreviewNote => '적용하면 클라이언트 화면에 반영되며 다시 시작해도 유지됩니다.';

  @override
  String get customFontImportFailed =>
      '글꼴을 가져올 수 없습니다. 올바른 TTF 또는 OTF 파일을 선택하세요.';

  @override
  String get customFontSaveFailed => '글꼴 설정을 저장할 수 없습니다. 다시 시도하세요.';

  @override
  String get customFontUnsupported => '현재 플랫폼에서는 글꼴 가져오기를 지원하지 않습니다.';

  @override
  String get customFontTooLarge => '글꼴 파일은 32 MB를 초과할 수 없습니다.';

  @override
  String get customFontLoadLimit =>
      '메모리 사용량을 제한하기 위해 이번 실행에서 글꼴을 바꿀 수 있는 한도에 도달했습니다. 다른 글꼴을 적용하려면 앱을 다시 시작하세요. 미리보기는 계속 사용할 수 있습니다.';

  @override
  String get customFontPreviewFailed => '글꼴 미리보기를 생성할 수 없습니다. 다시 시도하세요.';

  @override
  String get customFontPreviewRetry => '미리보기 다시 시도';

  @override
  String get browserMenuMute => '음소거';

  @override
  String get browserMenuUnmute => '소리 켜기';

  @override
  String get browserMenuScreenshot => '스크린샷';

  @override
  String get browserMenuFit => '화면 맞춤';

  @override
  String get browserMenuFullscreen => '전체 화면';

  @override
  String get browserMenuHome => '홈';

  @override
  String get browserMenuDismissHint => '바깥을 눌러 닫기';

  @override
  String summaryFleetHeavy(int count) {
    return '대파 $count';
  }

  @override
  String summaryFleetMedium(int count) {
    return '중파 $count';
  }

  @override
  String summaryFleetMinMorale(int value) {
    return '최저 피로도 $value';
  }

  @override
  String summaryExpedition(int active, String time) {
    return '진행 중 $active/3 · 최근 $time';
  }

  @override
  String summaryRepair(int busy, int total, String time) {
    return '사용 중 $busy/$total · 최근 $time';
  }

  @override
  String summaryRepairBusy(int busy, int total) {
    return '사용 중 $busy/$total';
  }

  @override
  String summaryConstruction(int done, int building) {
    return '완료 $done · 건조 중 $building';
  }

  @override
  String summaryQuests(int done, int active) {
    return '완료 가능 $done · 진행 중 $active';
  }

  @override
  String summaryLandBase(int sortie, int defense) {
    return '출격 $sortie · 방공 $defense';
  }

  @override
  String summaryWarnings(int count) {
    return '경고 $count';
  }

  @override
  String get questQueryTitle => '임무 검색 및 필터';

  @override
  String questQueryScope(String scope) {
    return '검색 범위: $scope';
  }

  @override
  String questApplyQuery(int count) {
    return '임무 $count개 표시';
  }

  @override
  String get questAccepted => '수락함';

  @override
  String get questConditionsAndProgress => '조건 및 진행도';

  @override
  String get questSelectTask => '임무를 선택하여 완료 조건 확인';

  @override
  String get questBackToList => '임무 목록으로 돌아가기';

  @override
  String get questReturnToTarget => '대상 임무로 돌아가기';

  @override
  String get questNoPrerequisites => '데이터에 직접 선행 임무가 기재되어 있지 않습니다';

  @override
  String get questNoSuccessors => '데이터에 후속 임무가 기재되어 있지 않습니다';

  @override
  String get japaneseOriginal => '일본어 원문';

  @override
  String questQueryActive(int count) {
    return '검색 조건 $count개 적용 중';
  }

  @override
  String get settingsTabRuntime => '게임 실행';

  @override
  String get settingsGroupAppearance => '기본 외관';

  @override
  String get settingsGroupScreenAdaptation => '화면 맞춤';

  @override
  String get settingsGroupLayoutPosition => '배치 및 위치';

  @override
  String get settingsGroupContentCustomization => '표시 내용 설정';

  @override
  String get settingsGroupLayoutManagement => '배치 관리';

  @override
  String get settingsOtherModuleDisplay => '기타 모듈 표시';

  @override
  String get settingsEditInformationLayout => '정보 패널 배치 편집';

  @override
  String get settingsEditHdLayout => 'HD 배치 편집';

  @override
  String get settingsResetMenuOrder => '메뉴 순서 초기화';

  @override
  String get settingsResetCardOrder => '기능 카드 순서 초기화';

  @override
  String get settingsGroupPerformanceRendering => '성능 및 화면';

  @override
  String get settingsGroupSubtitles => '자막';

  @override
  String get settingsGroupScreenBackground => '화면 및 백그라운드 실행';

  @override
  String get settingsGroupInformationCapture => '게임 정보 읽기';

  @override
  String get settingsFrameRefreshConfirm => '프레임 새로고침 전 확인';

  @override
  String get settingsFrameRefreshConfirmDescription =>
      '상단에서 게임 프레임을 새로고침하기 전에 확인합니다.';

  @override
  String get settingsFrameRefreshConfirmSaveFailed =>
      '프레임 새로고침 확인 설정을 저장하지 못했습니다. 다시 시도하세요.';

  @override
  String get settingsGroupDebuff => '기믹 및 장갑 파쇄';

  @override
  String get settingsGroupShipStatusFeedback => '함선 상태 효과';

  @override
  String get settingsGroupSystemNotifications => '시스템 알림';

  @override
  String get settingsEnableSystemNotifications => '시스템 알림 사용';

  @override
  String get settingsSystemNotificationSound => '시스템 알림 소리';

  @override
  String get settingsSystemNotificationVibration => '시스템 알림 진동';

  @override
  String get settingsGroupDataUpdates => '자료 업데이트';

  @override
  String get settingsGroupDataSharingPrivacy => '데이터 공유 및 개인정보';

  @override
  String get settingsGroupClearLocalData => '로컬 데이터 정리';

  @override
  String get settingsGroupAccount => '계정 작업';

  @override
  String get settingsGroupDiagnosticsSupport => '진단 및 지원';

  @override
  String get settingsStatusEnabled => '켜짐';

  @override
  String get settingsStatusDisabled => '꺼짐';

  @override
  String get settingsFleetDisplayStandard => '일반 함대 카드';

  @override
  String get settingsFleetDisplayHd => 'HD 2열 함대 카드';

  @override
  String get briefingDisplayTitle => '브리핑 표시 방식';

  @override
  String get briefingDisplayDescription =>
      '접기 방식은 여러 모듈을 동시에 펼치고, 탭 방식은 상단 탭으로 모듈을 전환합니다. HD 모드에서는 적용되지 않습니다.';

  @override
  String get briefingDisplayAccordion => '접기 방식';

  @override
  String get briefingDisplayTabs => '탭 방식';

  @override
  String get briefingTabForecast => '예측';

  @override
  String get briefingTabFleet => '편성';

  @override
  String get briefingTabLandBase => '기지';

  @override
  String get briefingTabExpedition => '원정';

  @override
  String get briefingTabRepair => '입거';

  @override
  String get briefingTabConstruction => '건조';

  @override
  String get briefingTabQuests => '임무';

  @override
  String get briefingTabPreSortie => '점검';

  @override
  String get questProgressDataTitle => '임무 진행 데이터';

  @override
  String questProgressDataVersion(String version) {
    return '데이터 버전: $version';
  }

  @override
  String questProgressDataSource(String source) {
    return '출처: $source';
  }

  @override
  String get questProgressBundledSource => 'Poi (내장)';

  @override
  String get questProgressCheckUpdates => '임무 진행 데이터 업데이트 확인';

  @override
  String get questProgressChecking => '임무 진행 데이터 확인 중…';

  @override
  String get questProgressUpToDate => '임무 진행 데이터가 최신 버전입니다.';

  @override
  String questProgressUpdated(String oldVersion, String newVersion) {
    return '임무 진행 데이터를 $oldVersion에서 $newVersion(으)로 업데이트했습니다. 변경 사항이 즉시 적용됩니다.';
  }

  @override
  String get questProgressNetworkError =>
      '임무 진행 데이터 출처에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get questProgressValidationError =>
      '임무 진행 데이터를 검증할 수 없습니다. 현재 버전을 유지합니다.';

  @override
  String get questProgressStorageError =>
      '임무 진행 데이터를 저장할 수 없습니다. 현재 버전을 유지합니다.';
}
