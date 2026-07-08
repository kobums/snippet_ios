import SwiftUI
import UIKit

// MARK: - CalendarShareBook

/// 캘린더 공유 카드에 그릴 완독 도서(표지 이미지 사전 로드 포함).
struct CalendarShareBook: Identifiable {
    let id: Int
    let coverImage: UIImage?
    let day: Int   // 완독일(해당 월의 일)
}

// MARK: - ShareableCalendarView

/// Instagram 4:5(1080×1350) 피드 공유용 월간 독서 캘린더 뷰.
///
/// Flutter `ShareableReadingCalendar` 포팅. 각 날짜 셀에 완독한 책 표지를 쌓아 보여주고,
/// 날짜 배지와 (복수일 때) "N권" 배지를 표시한다.
///
/// IMPORTANT: `ImageRenderer`는 `AsyncImage` 네트워크 로드를 기다리지 않으므로,
/// 표지는 미리 `UIImage`로 다운로드해서 `CalendarShareBook`으로 전달해야 한다.
struct ShareableCalendarView: View {

    let year: Int
    let month: Int
    let books: [CalendarShareBook]
    let isDark: Bool
    /// 캘린더에 통계(완독 권수·총 페이지) 오버레이 표시 여부.
    var showStats: Bool = false
    var completedCount: Int = 0
    var totalPages: Int = 0

    // 렌더링용 고정 크기 — scale 3 → 1080×1350 px
    static let cardWidth: CGFloat  = 360
    static let cardHeight: CGFloat = 450

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let calendar = Calendar.current

    // ── 시맨틱 색상 ──
    private var bgColor: Color { isDark ? Color(red: 0.110, green: 0.110, blue: 0.118) : Color(.systemGroupedBackground) }
    private var cardBg: Color { isDark ? Color(red: 0.173, green: 0.173, blue: 0.180) : .white }
    private var textPrimary: Color { isDark ? .white : Color(red: 0.110, green: 0.110, blue: 0.118) }
    private var textSecondary: Color { isDark ? Color(red: 0.682, green: 0.682, blue: 0.698) : Color(red: 0.424, green: 0.424, blue: 0.439) }
    private var textTertiary: Color { isDark ? Color(red: 0.388, green: 0.388, blue: 0.400) : Color(.tertiaryLabel) }
    private var primary: Color { isDark ? .white : .accentColor }
    private var emptyCellBg: Color { isDark ? Color.white.opacity(0.05) : Color.gray.opacity(0.05) }
    private var emptyCellBorder: Color { isDark ? Color.white.opacity(0.1) : Color.gray.opacity(0.1) }

    private var booksByDay: [Int: [CalendarShareBook]] {
        Dictionary(grouping: books, by: { $0.day })
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

    var body: some View {
        VStack(spacing: 0) {
            // 타이틀 (Flutter ShareableReadingCalendar 비율)
            Text("\(String(year))년 \(month)월")
                .font(.system(size: 15, weight: .medium))
                .tracking(-0.3)
                .foregroundStyle(textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // 캘린더 카드 — 남은 세로 공간 전부 사용 (Flutter Expanded 대응)
            VStack(spacing: 0) {
                weekdayHeader
                    .padding(.bottom, 6)
                grid
            }
            .padding(4)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(bgColor)
        .clipped()
    }

    // MARK: - 통계 셀 (캘린더 마지막 행 안에 인라인 — Flutter와 동일)

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(primary)
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(primary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(primary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { idx, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        idx == 0 ? Color.red.opacity(isDark ? 0.9 : 1.0)
                        : idx == 6 ? Color.blue.opacity(isDark ? 0.9 : 1.0)
                        : textSecondary
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    private var grid: some View {
        // Flutter와 동일: 6주 행 고정, 남은 높이를 6등분해 셀이 커진다.
        GeometryReader { geo in
            let colW = geo.size.width / 7
            let rowH = geo.size.height / 6
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            cell(row: row, col: col, colW: colW, rowH: rowH)
                        }
                    }
                }
            }
        }
    }

    /// 행/열 위치별 셀 — showStats 시 마지막 행의 목~토 4칸은 통계 셀 2개로 대체 (Flutter와 동일).
    @ViewBuilder
    private func cell(row: Int, col: Int, colW: CGFloat, rowH: CGFloat) -> some View {
        if showStats && row == 5 && col >= 3 {
            if col == 3 {
                statCell(icon: "book.pages.fill", value: "\(completedCount)권", label: "완독한 책")
                    .padding(1.5)
                    .frame(width: colW * 2, height: rowH)
            } else if col == 5 {
                statCell(icon: "book.fill", value: "\(totalPages)쪽", label: "총 페이지")
                    .padding(1.5)
                    .frame(width: colW * 2, height: rowH)
            }
            // col 4, 6은 통계 셀이 2칸을 차지하므로 생략
        } else {
            let cellIndex = row * 7 + col
            let day = cellIndex - firstWeekday + 1
            Group {
                if day >= 1 && day <= daysInMonth {
                    dayCell(day: day, dayBooks: booksByDay[day] ?? [])
                } else {
                    Color.clear
                }
            }
            .padding(1.5)
            .frame(width: colW, height: rowH)
        }
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCell(day: Int, dayBooks: [CalendarShareBook]) -> some View {
        if dayBooks.isEmpty {
            // 빈 날짜 — 연한 타일 + 흐린 숫자 (Flutter와 동일)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(emptyCellBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(emptyCellBorder, lineWidth: 0.5)
                    )
                Text("\(day)")
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
            }
        } else {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    stackedCovers(books: dayBooks, size: geo.size)

                    // 날짜 배지
                    Text("\(day)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
                        .padding(3)

                    // 권수 배지
                    if dayBooks.count > 1 {
                        Text("\(dayBooks.count)권")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(isDark ? Color(red: 0.110, green: 0.110, blue: 0.118) : .white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(primary.opacity(0.95), in: RoundedRectangle(cornerRadius: 3))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(3)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Stacked covers

    @ViewBuilder
    private func stackedCovers(books: [CalendarShareBook], size: CGSize) -> some View {
        if books.count == 1 {
            coverImageView(books[0])
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            // 최대 4장 쌓기 (뒤에서부터)
            let display = Array(books.reversed().prefix(4))
            let layers = display.count
            let scale = max(0.7, min(1.0, 1.0 - Double(layers - 1) * 0.1))
            let offsetX = size.width * 0.10
            let offsetY = size.height * 0.10

            ZStack(alignment: .topLeading) {
                // index 큰 것(뒤쪽) 먼저 그려 아래에 깔리도록 reversed
                ForEach(Array(display.enumerated()).reversed(), id: \.offset) { index, book in
                    coverImageView(book)
                        .frame(
                            width: size.width * CGFloat(scale),
                            height: size.height * CGFloat(scale)
                        )
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6 * CGFloat(scale)))
                        .offset(x: offsetX * CGFloat(index), y: offsetY * CGFloat(index))
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func coverImageView(_ book: CalendarShareBook) -> some View {
        if let img = book.coverImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.blue.opacity(0.2)
                Image(systemName: "book")
                    .foregroundStyle(.blue)
                    .font(.system(size: 16))
            }
        }
    }
}

// MARK: - CalendarCoverPrefetcher

/// 캘린더 표지 이미지를 사전 다운로드하는 헬퍼.
///
/// `ImageRenderer`가 비동기 이미지를 기다리지 않으므로, 렌더링 전에
/// 모든 표지를 `UIImage`로 받아 둔다.
enum CalendarCoverPrefetcher {

    /// 완독 도서 목록에서 표지를 다운로드해 `CalendarShareBook` 배열을 만든다.
    /// - Parameters:
    ///   - books: 완독(status == .completed) 도서.
    ///   - year/month: 대상 연·월 (endDate가 해당 월인 것만 포함).
    static func prefetch(books: [UserBookDto], year: Int, month: Int) async -> [CalendarShareBook] {
        let calendar = Calendar.current

        // endDate가 대상 월인 완독 도서만 추림
        let target: [(UserBookDto, Int)] = books.compactMap { book in
            guard book.status == .completed,
                  let end = book.endDate,
                  let date = APIDate.parseDay(end) ?? APIDate.parseDateTime(end) else { return nil }
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            guard comps.year == year, comps.month == month, let day = comps.day else { return nil }
            return (book, day)
        }

        // 표지 동시 다운로드
        return await withTaskGroup(of: CalendarShareBook.self) { group in
            for (book, day) in target {
                group.addTask {
                    let image = await downloadImage(book.coverUrl)
                    return CalendarShareBook(id: book.id, coverImage: image, day: day)
                }
            }
            var result: [CalendarShareBook] = []
            for await item in group { result.append(item) }
            return result
        }
    }

    private static func downloadImage(_ urlString: String) async -> UIImage? {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
