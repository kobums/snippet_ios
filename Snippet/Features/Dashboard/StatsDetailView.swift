import SwiftUI
import Charts

// MARK: - StatsDetailView

/// 통계 상세 화면 (`/stats`).
/// 월별 | 연도별 | 카테고리 | 인사이트 4탭.
struct StatsDetailView: View {

    @Bindable var vm: DashboardViewModel
    @State private var selectedSubTab: SubTab = .period
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
                ZStack {
                    PeriodStatsTab(monthly: vm.monthlyStats, yearly: vm.yearlyStats)
                        .opacity(selectedSubTab == .period ? 1 : 0)
                        .allowsHitTesting(selectedSubTab == .period)
                    CategoryStatsTab(stats: vm.categoryStats)
                        .opacity(selectedSubTab == .category ? 1 : 0)
                        .allowsHitTesting(selectedSubTab == .category)
                    InsightsTab(insights: vm.insights)
                        .opacity(selectedSubTab == .insights ? 1 : 0)
                        .allowsHitTesting(selectedSubTab == .insights)
                }
                .animation(.easeInOut(duration: 0.2), value: selectedSubTab)
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
                selection: $selectedSubTab,
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
                    EmptyStateView(systemImage: "chart.bar", title: "데이터가 없습니다")
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
                    EmptyStateView(systemImage: "chart.pie", title: "데이터가 없습니다")
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

    var body: some View {
        ScrollView {
            if let ins = insights {
                VStack(spacing: 12) {
                    InsightRow(
                        gradient: [Color(.systemBlue), Color(.systemCyan)],
                        icon: "clock",
                        title: "평균 독서 기간",
                        value: "\(String(format: "%.1f", ins.averageReadingDays))일",
                        description: "책 한 권을 완독하는 평균 시간"
                    )
                    InsightRow(
                        gradient: [Color(.systemGreen), Color.brandGreen],
                        icon: "tag",
                        title: "선호 카테고리",
                        value: ins.topCategory.isEmpty ? "-" : ins.topCategory,
                        description: "가장 많이 읽은 장르"
                    )
                    InsightRow(
                        gradient: [Color(.systemOrange), Color(.systemYellow)],
                        icon: "trophy",
                        title: "최장 독서 기록",
                        value: "\(ins.longestReadingDays)일",
                        description: "한 책을 읽은 최장 기간"
                    )
                    InsightRow(
                        gradient: [Color.accentPurple, Color(.systemPink)],
                        icon: "book",
                        title: "가장 오래 읽은 책",
                        value: ins.longestBook.isEmpty ? "-" : ins.longestBook,
                        description: "완독까지 가장 오래 걸린 책"
                    )
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            } else {
                EmptyStateView(systemImage: "lightbulb", title: "데이터가 없습니다")
                    .padding(.top, 60)
            }
        }
    }
}

// MARK: - 인사이트 행 카드

private struct InsightRow: View {

    let gradient: [Color]
    let icon: String
    let title: String
    let value: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .lineLimit(2)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

#Preview {
    NavigationStack {
        StatsDetailView(vm: DashboardViewModel())
    }
}
