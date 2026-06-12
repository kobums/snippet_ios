import SwiftUI
import Charts

// MARK: - StatsDetailView

/// 통계 상세 화면 (`/stats`).
/// 월별 | 연도별 | 카테고리 | 인사이트 4탭.
struct StatsDetailView: View {

    @Bindable var vm: DashboardViewModel
    @State private var selectedSubTab: SubTab = .monthly

    enum SubTab: Int, CaseIterable {
        case monthly, yearly, category, insights

        var title: String {
            switch self {
            case .monthly:  "월별"
            case .yearly:   "연도별"
            case .category: "카테고리"
            case .insights: "인사이트"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 연도 네비게이터
            YearNavigatorView(year: $vm.selectedYear)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .onChange(of: vm.selectedYear) { _, _ in
                    Task { await vm.refreshStats() }
                }

            Divider()

            // 서브탭
            Picker("탭", selection: $selectedSubTab) {
                ForEach(SubTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            TabView(selection: $selectedSubTab) {
                MonthlyStatsTab(stats: vm.monthlyStats)
                    .tag(SubTab.monthly)
                YearlyStatsTab(stats: vm.yearlyStats)
                    .tag(SubTab.yearly)
                CategoryStatsTab(stats: vm.categoryStats)
                    .tag(SubTab.category)
                InsightsTab(insights: vm.insights)
                    .tag(SubTab.insights)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedSubTab)
        }
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.refreshStats() }
    }
}

// MARK: - 월별 탭

private struct MonthlyStatsTab: View {

    let stats: [MonthlyStatsDto]

    private var maxY: Double {
        let m = stats.map { Double($0.completedCount) }.max() ?? 0
        return max(m * 1.2, 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if stats.isEmpty {
                    EmptyStateView(systemImage: "chart.bar", title: "데이터가 없습니다")
                        .padding(.top, 60)
                } else {
                    // 막대 차트
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "월별 완독 권수")
                        Chart(stats, id: \.month) { item in
                            BarMark(
                                x: .value("월", "\(item.month)월"),
                                y: .value("완독", item.completedCount)
                            )
                            .foregroundStyle(.primary)
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
                        .frame(height: 220)
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    // 월별 카드 목록
                    VStack(spacing: 8) {
                        ForEach(stats.filter { $0.completedCount > 0 }, id: \.month) { item in
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
                Spacer(minLength: 24)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - 연도별 탭

private struct YearlyStatsTab: View {

    let stats: [YearlyStatsDto]

    private var totalCompleted: Int { stats.reduce(0) { $0 + $1.completedCount } }
    private var totalPages: Int { stats.reduce(0) { $0 + $1.totalPages } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if stats.isEmpty {
                    EmptyStateView(systemImage: "chart.bar", title: "데이터가 없습니다")
                        .padding(.top, 60)
                } else {
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
                        ForEach(stats, id: \.year) { item in
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
