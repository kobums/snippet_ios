# Firebase iOS SDK 추가 및 FCM 설정 가이드

현재 코드베이스는 **APNs 기반 스캐폴딩** 상태입니다.  
Firebase SDK 없이도 빌드·실행이 가능하며, 아래 절차를 따라 FCM 토큰 방식으로 전환할 수 있습니다.

---

## 1. Xcode에서 Firebase iOS SDK 추가 (SPM)

1. Xcode 메뉴 **File > Add Package Dependencies...** 선택.
2. 검색창에 아래 URL 입력 후 **Add Package** 클릭.
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
3. 버전 규칙: **Up to Next Major** (현재 안정 버전 기준 `11.x.x`).
4. 추가할 라이브러리 체크:
   - `FirebaseCore` — 필수 (Firebase 초기화)
   - `FirebaseMessaging` — FCM 토큰 발급

> **주의**: `project.pbxproj`는 Xcode가 자동으로 수정합니다. 직접 편집하지 마세요.

---

## 2. GoogleService-Info.plist 추가

1. [Firebase 콘솔](https://console.firebase.google.com/) → 프로젝트 `snippet-164cd` → iOS 앱(`1:829461053187:ios:b1a197369c0bf3f311f336`) 선택.
2. **GoogleService-Info.plist** 다운로드.
3. Xcode에서 `Snippet` 타겟에 **드래그 앤 드롭** — "Add to targets: Snippet" 체크 확인.
4. 파일이 `.gitignore`에 포함되어 있는지 확인 (비밀 키 포함, 저장소 비커밋).

---

## 3. Push Notifications Capability 추가

1. Xcode → **Snippet** 타겟 → **Signing & Capabilities** 탭.
2. **+ Capability** 클릭 → `Push Notifications` 추가.
3. Xcode가 자동으로 entitlement 파일에 `aps-environment` 키를 추가합니다.

---

## 4. APNs 인증 키 설정 (Firebase 콘솔)

1. [Apple Developer 콘솔](https://developer.apple.com/) → **Certificates, Identifiers & Profiles** → **Keys** → `+`.
2. **Apple Push Notifications service (APNs)** 체크 → 생성 후 `.p8` 파일 다운로드.
3. Firebase 콘솔 → 프로젝트 설정 → **클라우드 메시징** → **APNs 인증 키** 업로드.
   - Key ID, Team ID 함께 입력.

---

## 5. 코드 전환 — **자동** (수정 불필요) ✅

`PushNotificationManager.swift`와 `AppDelegate.swift`는 이미 `#if canImport(FirebaseMessaging)` /
`#if canImport(FirebaseCore)` 조건부 컴파일로 작성되어 있습니다.
**SPM으로 Firebase SDK를 추가하면 아래가 코드 수정 없이 자동 활성화**됩니다:

- `AppDelegate.didFinishLaunchingWithOptions` → `FirebaseApp.configure()` 자동 호출
- `requestPermissionAndRegister()` → `Messaging.messaging().delegate = self` 자동 연결
- `apnsTokenReceived(_:)` → `Messaging.messaging().apnsToken = deviceToken` 자동 전달
- `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)` → FCM 토큰을 `POST /users/fcmtoken`에 자동 등록

> SDK가 없을 때는 APNs 토큰을 직접 서버에 등록하는 폴백으로 동작하므로, 지금도 빌드·실행에 문제가 없습니다.

남은 것은 SDK·plist·capability를 붙이는 일뿐입니다(1~4번 + 6번).

---

## 6. (선택) 빌드 확인

SDK 추가 후 클린 빌드하여 `canImport(FirebaseMessaging)` 경로가 컴파일되는지 확인합니다.
`GoogleService-Info.plist`가 없으면 `FirebaseApp.configure()`가 런타임에 경고/크래시하므로 2번을 반드시 완료하세요.

---

## 7. 전환 후 체크리스트

- [ ] Firebase SDK(FirebaseCore + FirebaseMessaging) SPM 추가됨
- [ ] `GoogleService-Info.plist`가 Snippet 타겟에 포함됨
- [ ] Push Notifications capability 추가됨
- [ ] APNs 인증 키가 Firebase 콘솔에 업로드됨
- [ ] (자동) `FirebaseApp.configure()` / `MessagingDelegate` 활성화 — `canImport` 처리됨
- [ ] FCM 토큰이 서버에 정상 등록됨 (`POST /users/fcmtoken`)
- [ ] 포그라운드 알림 표시 확인 (`willPresent` 델리게이트)
- [ ] 알림 탭 딥링크 라우팅 구현 (`snippet://` URL scheme, 04-platform.md §7 참고)

---

## 참고

- 04-platform.md §2 FCM 섹션 — Flutter 원본 로직 상세
- Flutter 원본 FCM 토큰 등록 위치: `lib/core/fcm_service.dart`, 호출 시점: `auth_provider.dart:84`
- 서버 엔드포인트: `POST /users/fcmtoken`, body: `{"fcmToken": "..."}`
