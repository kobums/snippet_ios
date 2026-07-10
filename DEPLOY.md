# iOS 배포 (Fastlane)

SwiftUI 네이티브 앱을 TestFlight / App Store에 올리는 fastlane 설정입니다.
(Flutter가 아니므로 `flutter build`는 쓰지 않고 `gym`으로 직접 아카이브합니다.)

## 사전 준비 (최초 1회)

### 1. fastlane 설치
```bash
cd snippet_ios
bundle install        # Gemfile 기반, 권장
# 또는: brew install fastlane
```

### 2. App Store Connect API Key (snippet_app 것 그대로 재사용)
번들 ID가 `com.gowoobro.snippet`로 snippet_app과 **동일한 App Store 앱**이므로, snippet_app에서 쓰던 App Store Connect API Key(`.p8`)와 ID를 그대로 사용하면 됩니다.

- snippet_app은 `snippet_app/ios/fastlane/.env`(gitignore)에 `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH`를 넣어 썼습니다. 그 `.env`를 `snippet_ios/fastlane/.env`로 복사하면 fastlane이 자동 로드합니다.
- 또는 셸에 직접 export:

```bash
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ASC_KEY_PATH="$HOME/keys/AuthKey_XXXXXXXXXX.p8"
```

> 이 머신에는 원본 `.p8`/`.env`가 없습니다(커밋 금지 정책). snippet_app을 배포하던 곳(다른 머신·비밀번호 관리자·CI 시크릿)에서 가져오세요.

### 3. 서명 — ⚠️ Xcode 로그인 필수
`gym`은 Xcode 자동 서명(`-allowProvisioningUpdates`)으로 **배포 인증서·프로파일을 자동 생성**합니다. 이때 **Xcode에 Apple ID가 로그인돼 있어야** 합니다.

- **Xcode → Settings(⌘,) → Accounts** 에서 개발자 계정(팀 `M4VAR7JKUT`, Account Holder)으로 로그인
- 로그인 상태만 유지되면 `Apple Distribution` 인증서가 없어도 배포 시 자동 생성됨 (직접 만들 필요 없음)

> **왜 API 키로 서명 안 하나?** 재사용하는 App Store Connect API 키는 **업로드 권한만** 있고 클라우드 서명(인증서 생성) 권한이 없습니다. 그래서 `-authenticationKey*`로 서명을 시도하면 `Cloud signing permission error`가 납니다. 서명은 **Xcode 계정 세션**으로, 업로드는 **API 키**로 — 이렇게 역할이 나뉘어 있습니다. (Fastfile의 `signing_xcargs`는 의도적으로 `-allowProvisioningUpdates`만 사용)
>
> 로그인이 풀리면 `error: exportArchive No Accounts` / `No signing certificate "iOS Distribution" found` 가 납니다 → Xcode에 다시 로그인하세요.

팀이 여러 개면 `fastlane/Appfile`의 `team_id`/`itc_team_id`를 채웁니다.

## 버전 관리

버전은 `Snippet.xcodeproj/project.pbxproj`의 빌드 설정에 저장됩니다.
- `MARKETING_VERSION` → 표시 버전 (예: `1.0.0`)
- `CURRENT_PROJECT_VERSION` → 빌드 번호

각 lane이 자동으로 bump하므로 수동 수정은 필요 없습니다.

> **버전 연속성**: 이 앱은 snippet_app이 배포하던 것과 같은 App Store 앱입니다. snippet_app의 마지막 승인 버전이 `1.0.19`였기 때문에, App Store는 **그보다 높은 버전만** 받습니다. 네이티브 첫 TestFlight 빌드는 `1.0.20`으로 올렸습니다(2026-07-10 기준 build 34). `MARKETING_VERSION`은 항상 스토어의 마지막 버전보다 커야 하며, 실패한 빌드마다 빌드 번호가 올라가는 건 정상입니다(계속 증가만 하면 됨).

## 배포 명령

| 명령 | 동작 |
|------|------|
| `make beta` / `fastlane beta` | 현재 버전 그대로 빌드 → TestFlight 업로드 |
| `make ship` / `fastlane ship` | 빌드 번호 +1 → TestFlight 업로드 |
| `make release` / `fastlane release` | patch 버전 +1, 빌드 번호 +1 → App Store 업로드 (심사 제출은 수동) |
| `make promo` / `fastlane promo` | 프로모션 텍스트만 즉시 반영 |

## 릴리즈 노트

`fastlane/changelogs/{버전}.txt`가 있으면 그 내용을 그대로 사용합니다(수동 작성이 항상 우선).
파일이 없으면 `release` lane이 git log로 자동 생성합니다:

1. **커밋 범위**: 직전 릴리즈 태그(`v*`) 이후 커밋. 태그가 없으면(첫 자동 생성) 최근 30개 커밋. `chore/ci/build/release` 커밋은 제외.
2. **문구 작성**: `claude` CLI가 있으면 커밋 로그를 사용자 관점의 한국어 릴리즈 노트로 요약. 없거나 실패하면 커밋 제목에서 conventional prefix(`feat(ios):` 등)를 떼고 불릿으로 정리.
3. 생성 결과는 `fastlane/changelogs/{버전}.txt`로 저장 후 `fastlane/metadata/ko/release_notes.txt`로 복사해 업로드합니다. 빌드 시작 전 로그에 전문이 출력되니 마음에 안 들면 중단(Ctrl+C) 후 파일을 고치고 다시 실행하면 됩니다.
4. 업로드 성공 시 `v{버전}` git 태그를 자동 생성해 다음 릴리즈 노트의 범위 기준으로 씁니다. (원격에도 남기려면 `git push --tags`)

## 트러블슈팅 — 첫 배포에서 겪은 이슈 (해결 완료, 기록용)

snippet_app(Flutter)을 네이티브로 교체하는 첫 iOS 배포에서 아래 순서로 걸렸습니다. 모두 코드/설정에 반영돼 있어 재발하지 않지만, 유사 상황 참고용으로 남깁니다.

| 증상 (altool/xcodebuild 에러) | 원인 | 해결 |
|---|---|---|
| `No profiles for 'com.gowoobro.snippet' were found` | export 시 배포 프로파일 자동 생성 안 함 | `export_xcargs`에 `-allowProvisioningUpdates` 추가 |
| `ASC_ISSUER_ID` 관련 인증 실패 / 한글 플레이스홀더로 fastlane UTF-8 크래시 | `.env`의 Issuer ID 미입력 | `.env` 채움 + Fastfile `verify_asc_env!` 사전 검증 추가 |
| `option '-authenticationKeyID' may only be provided once` | `xcargs`+`export_xcargs` 양쪽에 인증 인자 → export에 중복 적용 | `export_xcargs`에만 인증 인자 |
| `Cloud signing permission error` / `No signing certificate "iOS Distribution"` | 재사용 API 키에 클라우드 서명(인증서 생성) 권한 없음 | API 키 서명 제거 → **Xcode 계정 세션** 서명 (`-allowProvisioningUpdates`만) |
| `error: exportArchive No Accounts` | Xcode 로그인 풀림 | Xcode → Settings → Accounts 재로그인 |
| `CFBundleShortVersionString [1.0.19] must contain a higher version` (90062) | 1.0.19가 이미 App Store 승인됨 | `MARKETING_VERSION`을 `1.0.20`으로 bump |
| `does not support ... devices supported by the previous app version` (90101) | 이전 버전은 iPhone+iPad(`1,2`), 네이티브는 iPhone(`1`)만 | `TARGETED_DEVICE_FAMILY = "1,2"` |
| `include all of the ... orientations to support iPad multitasking` (90474) | iPad 멀티태스킹은 4방향 필요, 앱은 세로 전용 | `Info.plist`에 `UIRequiresFullScreen = true` (멀티태스킹 opt-out, 세로 전용 유지) |

**핵심 교훈**: 같은 앱 등록을 이어받으므로 (1) 버전은 스토어 마지막보다 높게, (2) 기기 지원(`TARGETED_DEVICE_FAMILY`)은 이전 버전 이상으로 유지해야 하고, (3) 서명은 Xcode 로그인으로, 업로드는 API 키로 한다.
