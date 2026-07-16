import SwiftUI
import Charts

// MARK: - StatsDetailView

/// 통계 상세 화면 (`/stats`).
/// 월별 | 연도별 | 카테고리 | 인사이트 4탭.
struct StatsDetailView: View {

    @Bindable var vm: DashboardViewModel
    @State private var selectedSubTab: SubTab = .period
    /// 콘텐츠 전환 방향 — 새로 선택한 탭이 오른쪽이면 오른쪽에서 밀려 들어온다(공간 일관성).
    @State private var transitionEdge: Edge = .trailing
    @Environment(\.dismiss) private var dismiss

    private var yearOptions: [Int] {
        let current = Calendar.current.component(.year, from: .now)
        return Array((current - 9...current).reversed())
    }

    enum SubTab: Int, CaseIterable {
        case period, category, insights

        var title: String {
            switch self {
            case .period:   "기간별"
            case .category: "카테고리"
            case .insights: "인사이트"
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top + 64
            let bottomInset = proxy.safeAreaInsets.bottom + 8

            ZStack(alignment: .top) {
                // 탭 순서 방향으로 밀려 들어오는 전환 — 진행 섹션과 같은 문법(공간 일관성).
                ZStack {
                    switch selectedSubTab {
                    case .period:
                        PeriodStatsTab(monthly: vm.monthlyStats, yearly: vm.yearlyStats)
                            .transition(.push(from: transitionEdge))
                    case .category:
                        CategoryStatsTab(stats: vm.categoryStats)
                            .transition(.push(from: transitionEdge))
                    case .insights:
                        InsightsTab(insights: vm.insights)
                            .transition(.push(from: transitionEdge))
                    }
                }
                .contentMargins(.top, topInset, for: .scrollContent)
                .contentMargins(.bottom, bottomInset, for: .scrollContent)
                .ignoresSafeArea(edges: [.top, .bottom])

                floatingBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: vm.selectedYear) { _, _ in
            Task { await vm.refreshStats() }
        }
    }

    // MARK: - 플로팅 바 — [뒤로가기] [상단탭] [년도] 한 줄

    private var floatingBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            FloatingSubTabBar(
                tabs: SubTab.allCases.map { ($0, $0.title) },
                selection: Binding(
                    get: { selectedSubTab },
                    set: { newTab in
                        guard newTab != selectedSubTab else { return }
                        transitionEdge = newTab.rawValue > selectedSubTab.rawValue ? .trailing : .leading
                        Haptics.selection()
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedSubTab = newTab
                        }
                    }
                ),
                compact: true
            )

            // 년도 선택 — 시스템 메뉴 피커
            Menu {
                Picker("연도", selection: $vm.selectedYear) {
                    ForEach(yearOptions, id: \.self) { year in
                        Text("\(String(year))년").tag(year)
                    }
                }
            } label: {
                Text("\(String(vm.selectedYear))년")
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
        }
        .padding(.top, 4)
        .padding(.horizontal, 12)
    }
}

// MARK: - 기간별 탭 (월별 + 연도별 통합)

private struct PeriodStatsTab: View {

    let monthly: [MonthlyStatsDto]
    let yearly: [YearlyStatsDto]

    private var maxY: Double {
        let m = monthly.map { Double($0.completedCount) }.max() ?? 0
        return max(m * 1.2, 1)
    }

    private var totalCompleted: Int { yearly.reduce(0) { $0 + $1.completedCount } }
    private var totalPages: Int { yearly.reduce(0) { $0 + $1.totalPages } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if monthly.isEmpty && yearly.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar",
                        title: "아직 완독한 책이 없어요",
                        message: "책을 완독하면 월별·연도별 통계가 여기에 채워져요."
                    )
                    .padding(.top, 60)
                }

                // ── 월별 ──
                if !monthly.isEmpty {
                    // 막대 차트
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "월별 완독 권수")
                        Chart(monthly, id: \.month) { item in
                            BarMark(
                                x: .value("월", "\(item.month)월"),
                                y: .value("완독", item.completedCount),
                                width: .ratio(0.55)
                            )
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .cornerRadius(4)
                            .annotation(position: .top) {
                                if item.completedCount > 0 {
                                    Text("\(item.completedCount)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .chartYScale(domain: 0...maxY)
                        // 값은 막대 위에 직접 표기하므로 Y축·그리드라인은 제거
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .frame(height: 220)
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // 월별 카드 목록
                    VStack(spacing: 8) {
                        ForEach(monthly.filter { $0.completedCount > 0 }, id: \.month) { item in
                            HStack {
                                Text("\(item.month)월")
                                    .font(.subheadline.weight(.medium))
                                    .frame(width: 40, alignment: .leading)
                                Spacer()
                                Text("완독 \(item.completedCount)권")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.totalPages)쪽")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 16)
                        }
                    }
                }

                // ── 연도별 ──
                if !yearly.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "연도별")
                            .padding(.horizontal, 16)

                        // 전체 통계 카드
                        HStack {
                            VStack(spacing: 4) {
                                Text("\(totalCompleted)권")
                                    .font(.statValue)
                                Text("총 완독")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider().frame(height: 50)

                            VStack(spacing: 4) {
                                Text("\(totalPages)쪽")
                                    .font(.statValue)
                                Text("총 페이지")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)

                        // 연도별 행
                        VStack(spacing: 8) {
                            ForEach(yearly, id: \.year) { item in
                                HStack {
                                    Text("\(String(item.year))년")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(item.completedCount)권 / \(item.totalPages)쪽")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - 카테고리 탭

private struct CategoryStatsTab: View {

    let stats: [CategoryStatsDto]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if stats.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.pie",
                        title: "카테고리 분포가 비어 있어요",
                        message: "책을 완독하면 어떤 장르를 즐겨 읽는지 보여드려요."
                    )
                    .padding(.top, 60)
                } else {
                    // 도넛 차트
                    CategoryDonutChartView(stats: stats)
                        .padding(.horizontal, 16)

                    // 카테고리 카드 목록
                    VStack(spacing: 8) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { idx, item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(Color.chartPalette[idx % Color.chartPalette.count])
                                        .frame(width: 10, height: 10)
                                    Text(item.category)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("완독 \(item.completedCount) / 전체 \(item.totalCount)권")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: item.completionRate / 100)
                                    .tint(Color.chartPalette[idx % Color.chartPalette.count])
                                Text("완독률: \(String(format: "%.1f", item.completionRate))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                }
                Spacer(minLength: 24)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - 인사이트 탭

private struct InsightsTab: View {

    let insights: ReadingInsightsDto?

    /// 전 지표가 비어 있으면 빈 상태로 취급한다.
    private var hasData: Bool {
        guard let ins = insights else { return false }
        return ins.averageReadingDays > 0
            || ins.longestReadingDays > 0
            || !ins.topCategory.isEmpty
            || !ins.longestBook.isEmpty
    }

    var body: some View {
        ScrollView {
            if let ins = insights, hasData {
                VStack(spacing: 12) {
                    // 핵심 지표 — 가장 중요한 숫자를 가장 크게(위계).
                    InsightHeroCard(
                        icon: "clock.fill",
                        tint: Color(.systemBlue),
                        title: "평균 독서 기간",
                        value: String(format: "%.1f", ins.averageReadingDays),
                        unit: "일",
                        description: "책 한 권을 완독하는 데 걸리는 평균 기간"
                    )

                    // 보조 숫자 지표 — 2열
                    HStack(alignment: .top, spacing: 12) {
                        InsightStatCard(
                            icon: "trophy.fill",
                            tint: Color(.systemOrange),
                            title: "최장 독서 기록",
                            value: "\(ins.longestReadingDays)",
                            unit: "일"
                        )
                        InsightStatCard(
                            icon: "tag.fill",
                            tint: .brandGreen,
                            title: "선호 카테고리",
                            value: ins.topCategory.isEmpty ? nil : ins.topCategory
                        )
                    }

                    // 책 인사이트 — 시그니처 세리프로 책 제목 강조
                    InsightBookCard(
                        title: "가장 오래 읽은 책",
                        bookTitle: ins.longestBook.isEmpty ? nil : ins.longestBook,
                        description: "완독까지 가장 오래 걸린 책"
                    )

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .animation(.smooth(duration: 0.3), value: ins)
            } else {
                EmptyStateView(
                    systemImage: "lightbulb",
                    title: "아직 인사이트가 없어요",
                    message: "독서 기록이 쌓이면 나만의 독서 패턴을 분석해드려요."
                )
                .padding(.top, 60)
            }
        }
    }
}

// MARK: - 인사이트 아이콘 칩 (공통)

private struct InsightIconChip: View {

    let icon: String
    let tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 인사이트 히어로 카드 (전폭 · 대형 숫자)

private struct InsightHeroCard: View {

    let icon: String
    let tint: Color
    let title: String
    let value: String
    let unit: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                InsightIconChip(icon: icon, tint: tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.statValueLarge)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 인사이트 통계 카드 (2열 그리드용)

private struct InsightStatCard: View {

    let icon: String
    let tint: Color
    let title: String
    /// nil이면 아직 데이터가 없다는 뜻 — 플레이스홀더를 보여준다.
    let value: String?
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InsightIconChip(icon: icon, tint: tint)

            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.statValueSmall)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("아직 없어요")
                    .font(.headline)
                    .foregroundStyle(.tertiary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 인사이트 책 카드 (세리프 제목)

private struct InsightBookCard: View {

    let title: String
    let bookTitle: String?
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            InsightIconChip(icon: "book.fill", tint: .accentPurple)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let bookTitle {
                    Text(bookTitle)
                        .font(.serifHeadline)
                        .lineLimit(2)
                } else {
                    Text("아직 없어요")
                        .font(.headline)
                        .foregroundStyle(.tertiary)
                }
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        StatsDetailView(vm: DashboardViewModel())
    }
}
