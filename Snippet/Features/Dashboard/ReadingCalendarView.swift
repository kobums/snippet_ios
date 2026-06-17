import SwiftUI

// MARK: - ReadingCalendarView

/// 독서 캘린더 풀스크린 — 월별 그리드에 완독일 책 표지 표시.
struct ReadingCalendarView: View {

    let initialYear: Int
    let initialMonth: Int
    let books: [UserBookDto]

    @State private var year: Int
    @State private var month: Int
    @State private var monthlyBooks: [UserBookDto]

    // 캘린더 이미지 공유
    @State private var isPreparingShare = false
    @State private var showShare = false
    @State private var shareURLs: [URL] = []
    /// 공유 이미지에 통계(완독 권수·총 페이지) 오버레이 표시 여부.
    @State private var showStats = false

    private let userBookService = UserBookService()

    @Environment(\.colorScheme) private var colorScheme

    init(initialYear: Int, initialMonth: Int, books: [UserBookDto]) {
        self.initialYear = initialYear
        self.initialMonth = initialMonth
        self.books = books
        _year = State(initialValue: initialYear)
        _month = State(initialValue: initialMonth)
        _monthlyBooks = State(initialValue: books)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MonthNavigatorView(year: $year, month: $month)
                    .padding(.horizontal, 16)
                    .onChange(of: year) { _, _ in Task { await loadMonthly() } }
                    .onChange(of: month) { _, _ in Task { await loadMonthly() } }

                FullCalendarView(year: year, month: month, books: monthlyBooks)
                    .padding(.horizontal, 16)

                // 공유 이미지 통계 오버레이 토글
                Toggle("캘린더에 통계 표시", isOn: $showStats)
                    .font(.subheadline)
                    .padding(.horizontal, 16)

                // 완독 책 수 요약
                let completed = monthlyBooks.filter { $0.status == .completed }
                if !completed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "이번 달 완독 (\(completed.count)권)")
                            .padding(.horizontal, 16)
                        ForEach(completed) { book in
                            BookRowView(book: book)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 16)
        }
        .navigationTitle("독서 캘린더")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadMonthly() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isPreparingShare {
                    ProgressView()
                } else {
                    Button {
                        Task { await prepareAndShare() }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if !shareURLs.isEmpty {
                ActivityShareSheet(activityItems: shareURLs)
                    .ignoresSafeArea()
            }
        }
    }

    private func loadMonthly() async {
        let loaded = try? await userBookService.fetchMonthly(year: year, month: month)
        monthlyBooks = loaded ?? []
    }

    /// 표지를 사전 다운로드한 뒤 캘린더 이미지를 렌더링해 공유 시트를 띄운다.
    private func prepareAndShare() async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        // 1) 표지 사전 다운로드 (ImageRenderer는 비동기 로드를 기다리지 않음)
        let shareBooks = await CalendarCoverPrefetcher.prefetch(
            books: monthlyBooks,
            year: year,
            month: month
        )

        // 2) 렌더링 + PNG 저장 (메인 액터)
        // 통계 값 (완독 권수 / 총 페이지) — 토글 시 오버레이에 사용
        let completedBooks = monthlyBooks.filter { $0.status == .completed }
        let completedCount = completedBooks.count
        let totalPages = completedBooks.reduce(0) { $0 + $1.totalPage }

        let url: URL? = await MainActor.run {
            let view = ShareableCalendarView(
                year: year,
                month: month,
                books: shareBooks,
                isDark: colorScheme == .dark,
                showStats: showStats,
                completedCount: completedCount,
                totalPages: totalPages
            )
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3.0
            guard let image = renderer.uiImage else { return nil }
            return ShareCardRenderer.saveTempPNG(image)
        }

        if let url {
            shareURLs = [url]
            showShare = true
        }
    }
}

// MARK: - 풀 캘린더 그리드

struct FullCalendarView: View {

    let year: Int
    let month: Int
    let books: [UserBookDto]

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let calendar = Calendar.current

    private var completedByDay: [Int: [UserBookDto]] {
        var result: [Int: [UserBookDto]] = [:]
        for book in books where book.status == .completed {
            if let end = book.endDate,
               let date = APIDate.parseDay(end) ?? APIDate.parseDateTime(end) {
                let comps = calendar.dateComponents([.year, .month, .day], from: date)
                if comps.year == year, comps.month == month, let day = comps.day {
                    result[day, default: []].append(book)
                }
            }
        }
        return result
    }

    private var daysInMonth: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private var firstWeekday: Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = calendar.date(from: comps) else { return 0 }
        return (calendar.component(.weekday, from: date) - 1 + 7) % 7
    }

    private var todayDay: Int? {
        let c = calendar.dateComponents([.year, .month, .day], from: .now)
        guard c.year == year, c.month == month else { return nil }
        return c.day
    }

    var body: some View {
        VStack(spacing: 4) {
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { idx, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(idx == 0 ? Color(.systemRed) : idx == 6 ? Color(.systemBlue) : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            // 날짜 그리드
            let totalCells = firstWeekday + daysInMonth
            let rows = Int(ceil(Double(totalCells) / 7.0))
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let day = cellIndex - firstWeekday + 1
                        if day >= 1 && day <= daysInMonth {
                            LargeDayCell(
                                day: day,
                                month: month,
                                books: completedByDay[day] ?? [],
                                isToday: day == todayDay
                            )
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(0.75, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 큰 날짜 셀

private struct LargeDayCell: View {

    let day: Int
    let month: Int
    let books: [UserBookDto]
    let isToday: Bool

    @State private var showSheet = false

    var body: some View {
        Button {
            if !books.isEmpty { showSheet = true }
        } label: {
            ZStack(alignment: .topLeading) {
                if let first = books.first {
                    AsyncImage(url: URL(string: first.coverUrl)) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Color(.systemGray5)
                        }
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        Text("\(day)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 3))
                            .padding(3)
                    }
                    .overlay(alignment: .bottom) {
                        Text("\(books.count)권")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                } else {
                    Color(.systemBackground)
                    Text("\(day)")
                        .font(.system(size: 13, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if isToday {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.primary, lineWidth: 1.5)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.75, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                List(books) { book in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: book.coverUrl)) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Color(.secondarySystemBackground)
                            }
                        }
                        .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title).font(.subheadline.weight(.medium)).lineLimit(2)
                            Text(book.author).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("\(month)월 \(day)일 완독")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") { showSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    NavigationStack {
        ReadingCalendarView(
            initialYear: 2026,
            initialMonth: 6,
            books: []
        )
    }
}
