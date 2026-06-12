# 홈 화면 위젯 설정 (WidgetKit)

오늘의 스니펫 한 문장을 홈 화면에 표시하는 위젯입니다.
앱 코드(공유 저장소·타임라인 갱신)는 이미 들어가 있고, **Xcode에서 위젯 익스텐션 타깃만 한 번 추가**하면 동작합니다.

> 위젯 익스텐션은 별도 타깃이라 `Snippet/`(앱 자동 포함 그룹) 밖의 `SnippetWidget/`에 소스를 두었습니다. 그래서 앱 빌드에는 영향이 없습니다.

## 1. 위젯 익스텐션 타깃 추가

1. Xcode에서 `Snippet.xcodeproj` 열기
2. File ▸ New ▸ Target… ▸ **Widget Extension** 선택
3. Product Name: `SnippetWidget` / "Include Live Activity" 체크 해제 → Finish
4. 자동 생성된 `SnippetWidget/SnippetWidget.swift`(템플릿)는 삭제하고,
   저장소의 `SnippetWidget/SnippetWidget.swift`를 위젯 타깃 멤버로 추가
   (File Inspector ▸ Target Membership ▸ SnippetWidgetExtension 체크)

## 2. App Group 설정 (앱 ↔ 위젯 데이터 공유)

앱 타깃과 위젯 타깃 **둘 다**에 동일 App Group을 추가합니다.

1. 각 타깃 ▸ Signing & Capabilities ▸ **+ Capability** ▸ App Groups
2. 그룹 추가: `group.com.gowoobro.snippet`
   (앱 코드 `APIConfig.appGroupId`, 위젯 코드 `appGroupId` 와 동일해야 함)

## 3. 동작 확인

- 앱에서 스니펫 카드를 불러오면 `SharedSnippetStore.save(...)`가
  App Group UserDefaults(`snippet_text` / `snippet_tag`)에 기록하고
  `WidgetCenter.shared.reloadAllTimelines()`로 위젯을 갱신합니다.
- 홈 화면 ▸ 위젯 추가 ▸ Snippet ▸ Small/Medium 선택
- 위젯을 탭하면 앱이 열립니다(StaticConfiguration 기본 동작).

## 데이터 흐름 요약

```
SnippetViewModel.fetchSnippets()
        │  cards.first
        ▼
SharedSnippetStore.save(text, tag)   ← App Group UserDefaults 기록 + reloadAllTimelines()
        ▼
SnippetProvider.getTimeline()        ← 같은 App Group에서 읽기
        ▼
SnippetWidgetEntryView               ← 홈 화면 렌더링
```

## 참고
- 지원 패밀리: `systemSmall`, `systemMedium`
- 타임라인 정책 `.never` — 앱이 명시적으로 갱신(reloadAllTimelines)하는 방식
