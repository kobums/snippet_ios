import Foundation

/// GET /readinglogs/daily 응답 항목 — 하루 동안 읽은 페이지 합계.
/// 서버는 pages > 0인 날만 내려주므로, 빈 날은 클라이언트에서 0으로 채운다.
/// 수동 진도 수정·타이머 세션·완독 처리 등 모든 readPage 변화를 집계한다.
struct DailyPagesDto: Codable, Equatable, Sendable {
    /// "yyyy-MM-dd"
    let date: String
    let pages: Int

    init(date: String, pages: Int) {
        self.date = date
        self.pages = pages
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        pages = try c.decodeIfPresent(Int.self, forKey: .pages) ?? 0
    }
}

/// 차트용 일자 포인트 (해당 월의 1일~말일, 빈 날 0).
struct DailyPagesPoint: Identifiable, Equatable, Sendable {
    let day: Int
    let pages: Int
    var id: Int { day }
}

/// 월간 일별 독서량 요약.
struct DailyPagesSummary: Equatable, Sendable {
    let year: Int
    let month: Int
    let points: [DailyPagesPoint]
    let totalPages: Int
    let daysRead: Int
    /// 읽은 날 기준 하루 평균 (읽은 날이 없으면 0).
    let averagePerReadDay: Double
    /// 가장 많이 읽은 날 (동률이면 이른 날). 읽은 날이 없으면 nil.
    let bestDay: DailyPagesPoint?

    var isEmpty: Bool { totalPages == 0 }

    /// 서버 응답(읽은 날만) → 해당 월 전체 일자로 채운 요약.
    init(year: Int, month: Int, logs: [DailyPagesDto]) {
        let prefix = String(format: "%04d-%02d-", year, month)
        var pagesByDay: [Int: Int] = [:]
        for log in logs where log.date.hasPrefix(prefix) {
            // "yyyy-MM-dd"의 dd만 사용 — Date 파싱/타임존 변환 없이 서버 일자를 그대로 쓴다.
            guard let day = Int(log.date.dropFirst(prefix.count).prefix(2)), log.pages > 0 else { continue }
            pagesByDay[day, default: 0] += log.pages
        }

        let dayCount = Self.numberOfDays(year: year, month: month)
        let points = (1...dayCount).map { DailyPagesPoint(day: $0, pages: pagesByDay[$0] ?? 0) }
        let readPoints = points.filter { $0.pages > 0 }
        let total = readPoints.reduce(0) { $0 + $1.pages }

        self.year = year
        self.month = month
        self.points = points
        self.totalPages = total
        self.daysRead = readPoints.count
        self.averagePerReadDay = readPoints.isEmpty ? 0 : Double(total) / Double(readPoints.count)
        self.bestDay = readPoints.reduce(DailyPagesPoint?.none) { best, p in
            guard let best else { return p }
            return p.pages > best.pages ? p : best
        }
    }

    private static func numberOfDays(year: Int, month: Int) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        guard
            let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let range = calendar.range(of: .day, in: .month, for: date)
        else { return 30 }
        return range.count
    }
}
