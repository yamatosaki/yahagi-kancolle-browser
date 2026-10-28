# 소스 코드 빌드 및 검증

[简体中文](BUILDING.md) ｜ [English](BUILDING.en.md) ｜ 한국어

이 문서는 Android 클라이언트를 직접 빌드하거나 개발에 참여하려는 분을 위한 안내입니다. 이미 배포된 앱을 설치하려면 [GitHub Releases](https://github.com/yamatosaki/yahagi-kancolle-browser/releases)를 이용하세요. 기본 브랜치의 소스 코드는 배포된 설치 파일보다 앞서 있을 수 있습니다. 특정 배포 버전의 소스 코드가 필요하다면 릴리스 페이지에 연결된 태그를 선택하고, 해당 태그의 설정을 기준으로 빌드하세요.

## 개발 환경

현재 [CI 설정](.github/workflows/ci.yml)에서는 다음 환경을 사용합니다.

- Flutter **3.44.8 stable**. Dart는 Flutter에 포함되어 있으며, 버전 제약은 `pubspec.yaml`을 참고하세요.
- JDK **17**. Android 네이티브 테스트를 실행할 때는 `JAVA_HOME`이 JDK 17을 가리키도록 설정하세요.
- Android SDK, 명령줄 도구, 라이선스에 동의한 빌드 구성 요소. `compileSdk`와 NDK 버전은 Flutter SDK에 따라 결정됩니다. `android/app/build.gradle.kts`를 참고하세요.
- Git. APK 빌드에는 Python이 필요하지 않습니다. 전체 데이터 검사를 실행할 때는 Python 3과 Pillow가 추가로 필요합니다.

위 도구를 설치한 뒤 `flutter doctor -v`로 환경을 확인하세요. Android 라이선스는 `flutter doctor --android-licenses`로 확인하고 동의할 수 있습니다. 처음 빌드할 때는 Flutter, Pub, Gradle 및 Android 관련 의존성을 다운로드해야 합니다.

## 소스 코드 가져오기 및 debug 빌드

터미널에서 다음 명령을 실행하세요.

```sh
git clone https://github.com/yamatosaki/yahagi-kancolle-browser.git
cd yahagi-kancolle-browser
flutter pub get
flutter build apk --debug
```

생성된 설치 파일은 `build/app/outputs/flutter-apk/app-debug.apk`에 있습니다. 디버깅용 기기를 연결한 뒤 `flutter run`을 실행할 수도 있습니다.

debug 빌드는 로컬 환경에서 자동으로 생성되는 디버그 서명을 사용합니다. 유지 관리자의 서명 키, 계정 데이터, 게임 데이터베이스 또는 백업 파일은 필요하지 않습니다. Android SDK 경로와 같은 로컬 설정은 도구가 생성하며, 저장소에 커밋하면 안 됩니다.

필요한 리소스 스냅샷, 글꼴, Gradle Wrapper와 `pubspec.lock`은 저장소에 포함되어 있습니다. 자료 저장소를 추가로 복제하거나 수집 스크립트를 먼저 실행할 필요가 없습니다. 최초 설치에는 `flutter pub upgrade` 대신 `flutter pub get`을 사용하세요. 이 저장소의 빌드 대상은 Android이며, 서드 파티 iOS 이식판은 별도 프로젝트입니다.

자신의 키로 서명한 APK는 서명이 다른 공식 설치본을 덮어쓸 수 없습니다. 두 버전을 함께 설치하려면 [사용자화 가이드(English)](CUSTOMIZING.en.md)에 따라 application ID를 변경하세요. 기존 앱을 삭제한다면 필요한 기록을 먼저 내보내세요. 앱 삭제 시 로컬 데이터도 삭제됩니다. 이후 자신의 빌드를 업데이트할 때는 같은 키를 사용하고 버전 코드를 유지하거나 높이세요.

## GitHub Actions로 빌드

저장소를 Fork한 뒤 자신의 저장소에서 Actions를 활성화하세요. **Actions → CI → Run workflow**에서 기본 브랜치를 선택해 실행합니다. 전체 검사와 debug 빌드가 성공하면 실행 페이지의 Artifacts에서 `yahagi-debug-apk`를 내려받고 압축을 풀어 `app-debug.apk`를 얻을 수 있습니다. 산출물 보관 기간은 7일이며, 만료되면 다시 실행하세요. 실패하면 실행 로그를 확인하세요.

이 경로에는 유지 관리자의 서명 키가 필요하지 않으며, 디버그 서명 APK가 생성됩니다. 서명이 다른 공식 설치본을 덮어쓸 수 없습니다. Actions의 임시 실행 환경에서는 실행마다 다른 디버그 키가 생성될 수 있으므로 이전 실행의 APK를 덮어쓰는 업데이트도 보장되지 않습니다. 장기 사용이나 독립 배포에는 자신의 고정 release 키를 설정하는 편이 좋습니다.

## 검증 명령

저장소 루트에서 CI에 대응하는 검사를 실행하세요.

```sh
python -m pip install pillow
python -m unittest tool.test_check_repository_hygiene -v
python tool/check_repository_hygiene.py
python -m unittest tool.test_build_sortie_release tool.test_build_enemy_release tool.test_verify_data_release -v
dart run tool/verify_data_release.dart
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Android 네이티브 단위 테스트는 Windows PowerShell에서 다음과 같이 실행하세요.

```powershell
.\android\gradlew.bat -p android :app:testDebugUnitTest --console=plain
```

Linux 또는 macOS에서는 다음과 같이 실행하세요.

```sh
chmod +x android/gradlew
./android/gradlew -p android :app:testDebugUnitTest --console=plain
```

일부 통합 테스트는 로컬에만 보관된 원본 샘플을 사용합니다. 공개 저장소를 복제한 환경에 이 샘플이 없으면 해당 테스트는 건너뛰었다고 명시합니다. 공개된 합성 테스트에는 실제 계정이나 게임 API 덤프가 필요하지 않습니다. 로컬 통합 테스트를 실행하기 위해 원본 데이터를 저장소에 추가하지 마세요.

## release 서명

`flutter build apk`는 기본적으로 release 모드를 사용합니다. 이 모드에서는 직접 서명을 설정해야 합니다. 소스 코드가 빌드되는지 처음 확인할 때는 위의 `--debug` 명령을 사용하세요.

자신의 release 패키지를 만들려면 서명 설정 파일을 저장소 밖에 두고, 환경 변수 `YAHAGI_SIGNING_PROPERTIES`가 해당 파일을 가리키도록 설정하세요. 설정 필드는 `storeFile`, `storePassword`, `keyAlias`, `keyPassword`이며, 파일을 읽는 구체적인 로직은 `android/app/build.gradle.kts`에 있습니다. 설정을 마치면 `flutter build apk --release`를 실행할 수 있습니다.

키 생성 명령, 서명 설정 예시 및 운영체제별 환경 변수 설정은 [English 서명 안내](BUILDING.en.md#release-signing)를 참고하세요. release APK는 `build/app/outputs/flutter-apk/app-release.apk`에 생성됩니다. 같은 키와 비밀번호가 이후 업데이트에도 필요합니다.

키, 서명 설정, 로컬 SDK 설정, 설치 파일, 로그 및 기록 백업은 커밋하면 안 됩니다. 서드 파티 코드와 리소스의 라이선스는 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES)를, 기여 규칙은 [기여 가이드](CONTRIBUTING.ko.md)를 참고하세요.

## 앱 사용자화

주요 소스 파일, 재빌드가 필요 없는 콘텐츠 사용자화, 독립 배포 시 확인할 업데이트 주소와 통계 설정은 [사용자화 가이드(English)](CUSTOMIZING.en.md)를 참고하세요.
