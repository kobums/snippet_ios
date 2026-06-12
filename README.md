# Snippet (iOS)

> 표지·제목·작가를 가리고 **책 속 한 문장**만으로 책을 만나는 블라인드 북 큐레이션 앱의 iOS 네이티브 클라이언트.

마음에 들면 오른쪽, 별로면 왼쪽으로 스와이프합니다. 마음에 든 문장을 보관하면 그제서야 책 정보가 공개(Reveal)됩니다. SwiftUI로 구현한 iOS 17+ 네이티브 앱이며 외부 SDK 의존성이 없습니다.

> 같은 제품의 다른 구현체: 웹(`front/`, Next.js) · 백엔드(`back/`, Spring Boot) · Android(`snippet_android/`, Jetpack Compose) · 레거시 Flutter(`snippet_app/`).

## 주요 기능

- **블라인드 스와이프**: 한 문장만 보고 좌/우로 평가, 보관 시 책 정보 Reveal 연출
- **서재 관리**: 소장 / 대출 / 위시리스트, 독서 상태·진행도, 무한 스크롤
- **도서 검색**: 알라딘 API 검색, 바코드(ISBN) 스캔, 인기 도서
- **독서 기록**: 스니펫 / 독서일기 / 리뷰, 책별 그룹핑
- **독서 세션 타이머**: wall-clock 기반 시작·일시정지·재개·완료, 백그라운드 복구, 로컬 알림
- **OCR**: Vision 프레임워크로 카메라/사진에서 텍스트 추출(ko-KR + en-US)
- **통계·대시보드**: 월별/연간/카테고리별 집계, 독서 캘린더
- **공유**: `ImageRenderer` 기반 공유 카드 이미지 생성 → 시스템 공유 시트
- **홈 위젯**: App Group으로 "오늘의 스니펫"을 위젯에 표시
- **다크 모드**: 시맨틱 컬러 + 사용자 설정 저장
- **인증**: JWT 로그인/회원가입, 401 시 토큰 자동 갱신

## 기술 스택

| 영역 | 사용 기술 |
|------|-----------|
| UI | SwiftUI, iOS 17+, SF Pro, `.ultraThinMaterial` |
| 언어 | Swift 5 |
| 네트워킹 | `URLSession` + async/await + `Codable` (외부 HTTP 라이브러리 없음) |
| 상태 관리 | Observation(`@Observable`) + `@MainActor` |
| 인증 토큰 | Keychain(`KeychainTokenStore`) |
| 프로필·설정 | `UserDefaults` |
| OCR | Vision |
| 위젯 | WidgetKit + App Group |
| 푸시 | APNs 스캐폴딩 (Firebase는 선택, SPM 추가 필요) |

> 외부 SPM 의존성 없이 빌드/실행됩니다. (FCM은 선택적 — `FCM-SETUP.md` 참조)

## 아키텍처

```
Screen(SwiftUI View) → ViewModel(@Observable) → Service → APIClient → URLSession
```

- **`APIClient`**: 모든 요청에 `Authorization: Bearer {accessToken}` 자동 주입(토큰 없으면 생략). 401 수신 시 actor로 직렬화된 토큰 refresh 후 원 요청 1회 재시도하고, 재시도도 401이면 강제 로그아웃 브로드캐스트(`.snippetForceLogout`).
- **`TokenRefreshCoordinator`**: 동시 다발 401에서도 refresh를 한 번만 수행하도록 직렬화하는 actor.
- **`AuthSession` / `ThemeManager`**: 앱 전역 상태를 Environment로 주입.
- **날짜 처리**: 서버는 날짜를 문자열(LocalDateTime)로 주고받으며, 표시 직전 `APIDate` 헬퍼로 파싱.

## 프로젝트 구조

```
snippet_ios/
├── Snippet/
│   ├── App/             # 앱 진입점 (SnippetApp, RootView, AppDelegate)
│   ├── Core/
│   │   ├── Auth/        # AuthSession, KeychainTokenStore
│   │   ├── Network/     # APIClient, Endpoint, Services/, TokenRefreshCoordinator
│   │   ├── Models/      # Codable DTO, APIDate
│   │   └── SharedSnippetStore.swift   # 위젯 공유(App Group)
│   ├── DesignSystem/    # 브랜드 토큰, 공용 컴포넌트
│   ├── Features/        # 도메인별 화면
│   │   ├── Snippet/     # 블라인드 스와이프 + 보관함 + Reveal
│   │   ├── Library/     # 서재, 검색, 바코드, 인기 도서, 책 상세
│   │   ├── Dashboard/   # 통계, 독서 캘린더
│   │   ├── Records/     # 독서 기록(스니펫/일기/리뷰), 세션 목록
│   │   ├── ReadingSession/  # 세션 타이머, 완료, 로컬 알림
│   │   ├── OCR/         # 카메라/사진 → Vision 텍스트 추출
│   │   ├── Share/       # 공유 카드 렌더링
│   │   ├── Push/        # 푸시 알림 관리
│   │   ├── Profile/     # 프로필, 테마, 건의하기
│   │   └── Auth/        # 로그인, 회원가입, 스플래시
│   └── Resources/       # Assets.xcassets
├── SnippetWidget/       # 홈 화면 위젯 익스텐션
├── FCM-SETUP.md         # Firebase/FCM 연동 가이드 (선택)
└── WIDGET-SETUP.md      # 위젯 익스텐션·App Group 설정 가이드
```

> Xcode의 `PBXFileSystemSynchronizedRootGroup` 방식을 사용하므로 `Snippet/` 하위에 추가한 파일은 자동으로 타깃에 포함됩니다.

## 요구 사항

- Xcode 16+
- iOS 17.0 이상
- 백엔드 API(`back/`)가 실행 중이어야 전체 기능 사용 가능

## 빌드 & 실행

Xcode에서 `Snippet.xcodeproj`를 열고 시뮬레이터를 선택해 실행하거나, CLI로 빌드합니다.

```bash
xcodebuild build \
  -project Snippet.xcodeproj \
  -target Snippet \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO
```

API Base URL은 `Snippet/Core/Network/APIConfig.swift`에서 빌드 구성별로 설정합니다.

- `DEBUG`: 로컬/개발 서버
- `RELEASE`: 운영 서버

## 선택적 설정

| 기능 | 가이드 | 비고 |
|------|--------|------|
| 홈 위젯 | `WIDGET-SETUP.md` | App Group(`group.com.gowoobro.snippet`) 구성 필요 |
| 푸시(FCM) | `FCM-SETUP.md` | 미설정 시 APNs 토큰 직접 등록 폴백으로 동작 |

## 주요 API

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/snippets/cards` | 스와이프용 카드 조회 |
| POST | `/api/snippets/archive` | 좋아요한 스니펫 보관 |
| GET | `/api/books/search` | 알라딘 도서 검색 |
| GET/POST/PATCH | `/api/userbooks` | 사용자 서재 관리 |
| GET/POST | `/api/records` | 독서 기록 |
| GET/POST | `/api/readingsessions` | 독서 세션 |
| POST | `/api/auth/login`, `/register`, `/refresh` | 인증 |
| POST | `/api/ocr` | OCR 텍스트 추출 |

> API URL 컨벤션: 하이픈(`-`) 미사용, camelCase 또는 소문자 연결 (예: `/api/userbooks`).

## 보안

- JWT 토큰은 Keychain에 저장합니다. (미서명 시뮬레이터 등 Keychain 불가용 환경에서만 UserDefaults로 폴백)
- 서명·APNs 키(`*.p8`, `*.p12`), 인증서, `GoogleService-Info.plist`, `*.env`/시크릿 설정은 `.gitignore`로 커밋이 차단되어 있습니다.
