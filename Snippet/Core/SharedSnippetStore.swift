import Foundation
import WidgetKit

// MARK: - SharedSnippetStore

/// 홈 화면 위젯과 공유하는 "오늘의 스니펫" 저장소.
///
/// 앱이 최신 카드 한 문장을 App Group UserDefaults에 기록하면,
/// 위젯 익스텐션이 같은 키로 읽어 표시한다.
/// App Group(`APIConfig.appGroupId`)이 아직 설정되지 않은 환경에서는 조용히 no-op이다.
/// (위젯 익스텐션 타깃 추가 절차는 `WIDGET-SETUP.md` 참조)
enum SharedSnippetStore {

    static let textKey = "snippet_text"
    static let tagKey = "snippet_tag"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: APIConfig.appGroupId)
    }

    /// 최신 스니펫을 저장하고 위젯 타임라인을 갱신한다.
    static func save(text: String, tag: String?) {
        guard let defaults else { return }
        defaults.set(text, forKey: textKey)
        defaults.set(tag ?? "", forKey: tagKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 표시할 스니펫이 없을 때 저장소를 비우고 위젯 타임라인을 갱신한다.
    /// (위젯은 값이 없으면 기본 안내 문구로 폴백한다)
    static func clear() {
        guard let defaults else { return }
        defaults.removeObject(forKey: textKey)
        defaults.removeObject(forKey: tagKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
