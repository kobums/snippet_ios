import Foundation

/// 앱 전역에서 재사용하는 기본 JSON 인코더/디코더.
///
/// `JSONDecoder`/`JSONEncoder`는 decode/encode 호출에 한해 thread-safe하므로 공유해도 안전하다.
/// 키 전략·날짜 전략 등 설정이 필요해지면 이 한 곳만 수정하면 모든 호출처에 일관 적용된다.
enum JSONCoding {
    static let decoder = JSONDecoder()
    static let encoder = JSONEncoder()
}
