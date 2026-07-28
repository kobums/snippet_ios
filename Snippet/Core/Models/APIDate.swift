import Foundation

/// 서버 날짜 문자열 파싱 헬퍼.
/// DTO는 날짜를 String으로 보관하고, 화면 표시 직전에 이 헬퍼로 파싱한다 (문서 §2.4).
/// - ISO LocalDateTime: `2026-06-11T14:30:00` (초/소수점 초 혼용 허용)
/// - 일자: `2026-06-11`
enum APIDate {
    /// ISO-8601 LocalDateTime(타임존 없음) 파싱. 소수점 초 유무 모두 허용.
    static func parseDateTime(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
        ] {
            if let date = makeFormatter(format).date(from: string) {
                return date
            }
        }
        return nil
    }

    /// "yyyy-MM-dd" 파싱.
    static func parseDay(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        return makeFormatter("yyyy-MM-dd").date(from: string)
    }

    /// "yyyy-MM-dd" 또는 "yyyy-MM-dd'T'HH:mm:ss" → "yyyy.MM.dd" 표시 문자열.
    /// 형식이 어긋나면 앞 10자를 그대로 반환한다 (기록/세션/건의 카드 공통 표기).
    static func dotDayString(from raw: String) -> String {
        let day = String(raw.prefix(10))
        let parts = day.split(separator: "-")
        guard parts.count == 3 else { return day }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }

    /// 앱 → 서버 ISO LocalDateTime 문자열 (Dart toIso8601String 호환).
    static func dateTimeString(from date: Date = Date()) -> String {
        makeFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS").string(from: date)
    }

    /// 앱 → 서버 "yyyy-MM-dd" 문자열 (sessionDate 등).
    static func dayString(from date: Date = Date()) -> String {
        makeFormatter("yyyy-MM-dd").string(from: date)
    }

    // DateFormatter 생성은 비싸므로 포맷 문자열별로 캐시해 재사용한다.
    // DateFormatter는 date(from:)/string(from:) 호출에 한해 thread-safe하다.
    private static let cacheLock = NSLock()
    private static var formatterCache: [String: DateFormatter] = [:]

    private static func makeFormatter(_ format: String) -> DateFormatter {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = formatterCache[format] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        formatterCache[format] = formatter
        return formatter
    }
}
