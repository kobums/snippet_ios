import SwiftUI

// MARK: - RecordsViewModel

/// 독서 기록 탭 전용 ViewModel.
/// 월별 기록 로드(타입 필터), 기록 추가/수정/삭제,
/// 전체 독서 세션 목록(책 제목별 그룹핑).
@MainActor
@Observable
final class RecordsViewModel {

    // MARK: - 기록 탭 상태

    var selectedYear: Int = Calendar.current.component(.year, from: .now)
    var selectedMonth: Int = Calendar.current.component(.month, from: .now)

    /// 서버에서 받아온 월별 전체 기록
    var monthlyRecords: [RecordDto] = []

    var isLoadingRecords = false
    var recordsError: String? = nil

    // MARK: - 세션 탭 상태

    var allSessions: [ReadingSessionDto] = []
    var isLoadingSessions = false
    var sessionsError: String? = nil

    // MARK: - 서비스

    private let recordService = RecordService()
    private let sessionService = ReadingSessionService()

    // MARK: - 파생 계산 (타입 필터)

    func records(for type: RecordType?) -> [RecordDto] {
        guard let type else { return monthlyRecords }
        return monthlyRecords.filter { $0.type == type }
    }

    /// 책별 그룹핑된 기록. 제목이 같은 다른 책이 합쳐지지 않도록 bookId를 키로 사용한다.
    /// (키 순서는 첫 등장 순서 유지)
    func groupedRecords(for type: RecordType?) -> [(groupId: Int, bookTitle: String, records: [RecordDto])] {
        let filtered = records(for: type)
        var seen = Set<Int>()
        var keys: [Int] = []
        for r in filtered where !seen.contains(r.bookId) {
            seen.insert(r.bookId)
            keys.append(r.bookId)
        }
        return keys.map { id in
            let items = filtered.filter { $0.bookId == id }
            return (groupId: id, bookTitle: items.first?.bookTitle ?? "", records: items)
        }
    }

    /// 책별 그룹핑된 세션. 항상 존재하는 userBookId를 키로 사용한다
    /// (세션 DTO의 bookId는 누락 시 0이라 그룹이 뭉칠 수 있음).
    var groupedSessions: [(groupId: Int, bookTitle: String, sessions: [ReadingSessionDto])] {
        var seen = Set<Int>()
        var keys: [Int] = []
        for s in allSessions where !seen.contains(s.userBookId) {
            seen.insert(s.userBookId)
            keys.append(s.userBookId)
        }
        return keys.map { ubId in
            let items = allSessions.filter { $0.userBookId == ubId }
            return (groupId: ubId, bookTitle: items.first?.bookTitle ?? "", sessions: items)
        }
    }

    // MARK: - 로드 메서드

    func loadRecords() async {
        isLoadingRecords = true
        recordsError = nil
        defer { isLoadingRecords = false }
        let result = try? await recordService.fetchMonthly(
            year: selectedYear,
            month: selectedMonth
        )
        monthlyRecords = result ?? []
        if result == nil {
            recordsError = "기록을 불러올 수 없습니다"
        }
    }

    func loadSessions() async {
        isLoadingSessions = true
        sessionsError = nil
        defer { isLoadingSessions = false }
        let result = try? await sessionService.fetchAll()
        allSessions = result ?? []
        if result == nil {
            sessionsError = "독서 세션을 불러올 수 없습니다"
        }
    }

    func changeMonth(year: Int, month: Int) async {
        selectedYear = year
        selectedMonth = month
        await loadRecords()
    }

    // MARK: - 기록 추가

    @discardableResult
    func addRecord(_ request: RecordAddRequest) async -> Bool {
        let _ = try? await recordService.add(request)
        await loadRecords()
        return true
    }

    // MARK: - 기록 수정

    @discardableResult
    func updateRecord(id: Int, _ request: RecordUpdateRequest) async -> Bool {
        let updated = try? await recordService.update(id: id, request)
        if updated != nil {
            await loadRecords()
            return true
        }
        return false
    }

    // MARK: - 기록 삭제

    @discardableResult
    func deleteRecord(id: Int) async -> Bool {
        // delete() throws Void — try? returns Optional<Void>, () on success, nil on throw
        _ = try? await recordService.delete(id: id)
        await loadRecords()
        return true
    }
}
