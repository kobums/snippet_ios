# 독서 세션 Live Activity 설정 (ActivityKit)

독서 타이머 실행 중 **잠금화면 / 다이나믹 아일랜드**에 경과 시간을 실시간 표시하는 Live Activity입니다.
앱 코드(시작/갱신/종료 연동, `NSSupportsLiveActivities`)는 이미 들어가 있고,
**Xcode에서 위젯 익스텐션 타깃에 Live Activity 파일만 포함**하면 동작합니다.

> Live Activity UI는 위젯 익스텐션에서 렌더링됩니다. 위젯 익스텐션 타깃 자체를 추가하는 절차는
> `WIDGET-SETUP.md`와 동일하며, 여기서는 Live Activity 관련 추가 설정만 다룹니다.

## 이미 반영된 것 (코드)

- `Snippet/Features/ReadingSession/ReadingActivityAttributes.swift` — 공유 `ActivityAttributes` 타입
- `Snippet/Features/ReadingSession/ReadingActivityController.swift` — 시작/갱신/종료 래퍼
  (`ReadingTimer`의 start/pause/resume/prepareFinish/cancel/recover에 연동)
- `SnippetWidget/ReadingLiveActivity.swift` — 잠금화면 + 다이나믹 아일랜드 UI
- `Info.plist` ▸ `NSSupportsLiveActivities = YES`

전부 `#if canImport(ActivityKit)` + `@available(iOS 16.1, *)` 가드라, 타깃 미설정·구버전에서도
앱은 정상 빌드·동작하며 Live Activity만 표시되지 않습니다.

## 1. 위젯 익스텐션 타깃 준비

`WIDGET-SETUP.md` 1번 절차로 `SnippetWidget` 위젯 익스텐션 타깃을 추가합니다.
(이미 추가했다면 생략)

## 2. Live Activity 파일을 위젯 타깃 멤버로 추가

File Inspector ▸ Target Membership 에서 아래 파일을 체크합니다.

| 파일 | 앱 타깃(Snippet) | 위젯 타깃(SnippetWidgetExtension) |
|------|:---:|:---:|
| `Snippet/Features/ReadingSession/ReadingActivityAttributes.swift` | ✅ (자동) | ✅ **추가 체크** |
| `SnippetWidget/ReadingLiveActivity.swift` | ✖ | ✅ |
| `SnippetWidget/SnippetWidget.swift` | ✖ | ✅ |

> ⚠️ `ReadingActivityAttributes`는 **앱·위젯 두 프로세스에서 동일 타입으로 디코딩**되어야 하므로
> 반드시 양쪽 타깃 멤버여야 합니다. (`Snippet/` 하위라 앱 타깃엔 자동 포함되므로 위젯 타깃만 수동 체크)

## 3. 위젯 번들 등록 (이미 코드 반영됨)

`SnippetWidget/SnippetWidget.swift`의 `SnippetWidgetBundle`에 `ReadingLiveActivity()`가
iOS 16.1+ 조건으로 등록돼 있습니다. 별도 작업 불필요.

## 4. 동작 확인

1. 시뮬레이터/기기(iOS 16.1+)에서 책 상세 ▸ "독서 시작" → 타이머 시작
2. 앱을 백그라운드로 보내거나 잠금화면 확인 → "📚 책 제목 / 경과 타이머" Live Activity 표시
3. 일시정지 → 타이머 정지(정적 경과), 재개 → 다시 카운트
4. "독서 완료" 또는 포기 → Live Activity 즉시 사라짐

## 동작 흐름 요약

```
ReadingTimer.start()      → ReadingActivityController.start()      (running, 자동 카운트)
ReadingTimer.pause()      → ReadingActivityController.updatePaused() (정적 경과)
ReadingTimer.resume()     → ReadingActivityController.updateRunning()
ReadingTimer.prepareFinish/cancel() → ReadingActivityController.end()
ReadingTimer.recover()    → start() (+ paused면 updatePaused())     앱 재실행 복구
```

## 참고
- 시간 표시는 `ContentState.timerReferenceDate`(= 현재 - 누적경과) 기준 `Text(timerInterval:)`로 자동 갱신 — 1초 푸시 갱신 불필요.
- Live Activity는 `ActivityAuthorizationInfo().areActivitiesEnabled`가 true일 때만 시작됩니다(사용자가 설정에서 끌 수 있음).
