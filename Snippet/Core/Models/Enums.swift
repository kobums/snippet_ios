import Foundation

/// 서재 구분. 서버 wire format: "wish" | "have" | "borrow" | "return"
/// `return`은 Swift 예약어라 `returned` 케이스에 rawValue로 매핑한다.
enum BookType: String, Codable, CaseIterable, Sendable {
    case wish
    case have
    case borrow
    case returned = "return"
}

/// 독서 상태. "none"은 wish 전용.
enum BookStatus: String, Codable, CaseIterable, Sendable {
    case none
    case waiting
    case reading
    case completed
    case dropped
}

/// 독서 기록 타입. 알 수 없는 값은 snippet으로 폴백 (문서 §4.1).
enum RecordType: String, Codable, CaseIterable, Sendable {
    case snippet
    case diary
    case review

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RecordType(rawValue: raw) ?? .snippet
    }

    var label: String {
        switch self {
        case .snippet: return "스니펫"
        case .diary: return "독서일기"
        case .review: return "리뷰"
        }
    }
}

/// 건의 카테고리. 서버 전송 값은 대문자 (문서 §3.9).
enum SuggestionCategory: String, Codable, CaseIterable, Sendable {
    case feature = "FEATURE"
    case bug = "BUG"
    case improvement = "IMPROVEMENT"
    case other = "OTHER"

    var label: String {
        switch self {
        case .feature: return "기능 추가"
        case .bug: return "버그 신고"
        case .improvement: return "개선 제안"
        case .other: return "기타"
        }
    }
}

/// OCR 엔진 선택 (multipart `engine` 필드 값).
enum OcrEngine: String, Sendable {
    case google
    case naver
}
