import SwiftUI
import Charts

// MARK: - 일별 읽은 페이지 카드

/// 대시보드 통계 섹션의 "일별 읽은 페이지" 카드.
/// 대시보드의 선택 년/월(`vm.selectedYear/selectedMonth`)을 그대로 공유하므로
/// 카드에서 월을 옮기면 상단 년월 버튼·캘린더도 함께 바뀐다.
/// 데이터: GET /readinglogs/daily — 타이머를 쓰지 않아도 진도 수정만으로 집계된다.
struct DailyPagesCard: View {

    @Bindable var vm: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "일별 읽은 페이지")

            MonthNavigatorView(year: $vm.selectedYear, month: $vm.selectedMonth)

            content
                .frame(maxWidth: .infinity)
                .animation(.smooth(duration: 0.25), value: vm.dailyPages)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var content: some View {
        if let error = vm.dailyPagesError {
            DailyPagesErrorView(message: error) {
                Task { await vm.retryDailyPages() }
            }
        } else if let summary = vm.dailyPages,
                  summary.year == vm.selectedYear, summary.month == vm.selectedMonth {
            if summary.isEmpty {
                DailyPagesEmptyView()
            } else {
                VStack(spacing: 16) {
                    DailyPagesSummaryRow(summary: summary)
                    DailyPagesChart(summary: summary)
                        .frame(height: 180)
                }
            }
        } else {
            // 첫 로드 / 다른 달로 이동 직후
            ProgressView()
                .frame(height: 180)
        }
    }
}

// MARK: - 요약 (총 페이지 · 읽은 날 · 하루 평균 · 최고 기록)

private struct DailyPagesSummaryRow: View {

    let summary: DailyPagesSummary

    private var averageText: String {
        let avg = summary.averagePerReadDay
        // 정수로 떨어지면 소수점 없이, 아니면 소수 첫째 자리까지
        return avg.rounded() == avg ? "\(Int(avg))" : String(format: "%.1f", avg)
    }

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                metric(title: "이번 달 총", value: "\(summary.totalPages)", unit: "쪽")
                metric(title: "읽은 날", value: "\(summary.daysRead)", unit: "일")
            }
            GridRow {
                metric(title: "하루 평균", value: averageText, unit: "쪽")
                if let best = summary.bestDay {
                    metric(
                        title: "최고 기록 · \(summary.month)월 \(best.day)일",
                        value: "\(best.pages)",
                        unit: "쪽",
                        tint: .brandGreen
                    )
                } else {
                    metric(title: "최고 기록", value: "-", unit: "")
                }
            }
        }
    }

    private func metric(title: String, value: String, unit: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.statValueSmall)
                    .foregroundStyle(tint)
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
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 일별 막대 차트 (Swift Charts)

private struct DailyPagesChart: View {

    let summary: DailyPagesSummary

    /// 탭/드래그로 선택한 일자 — 해당 일의 페이지 수를 막대 위에 보여준다.
    @State private var selectedDay: Int? = nil

    private var maxY: Double {
        let maxVal = Double(summary.points.map(\.pages).max() ?? 0)
        return max(maxVal * 1.25, 1)
    }

    private var lastDay: Int { summary.points.last?.day ?? 30 }

    private var selectedPoint: DailyPagesPoint? {
        guard let selectedDay else { return nil }
        return summary.points.first { $0.day == selectedDay }
    }

    private func barColor(for point: DailyPagesPoint) -> Color {
        if let selectedDay {
            return point.day == selectedDay ? .brandGreen : Color.primary.opacity(0.35)
        }
        return point.day == summary.bestDay?.day ? .brandGreen : Color.primary.opacity(0.85)
    }

    var body: some View {
        Chart {
            ForEach(summary.points) { point in
                BarMark(
                    x: .value("일", point.day),
                    y: .value("페이지", point.pages),
                    width: .ratio(0.7)
                )
                .foregroundStyle(barColor(for: point))
                .cornerRadius(2)
            }

            if let point = selectedPoint {
                RuleMark(x: .value("일", point.day))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        VStack(spacing: 2) {
                            Text("\(summary.month)월 \(point.day)일")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(point.pages)쪽")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
            }
        }
        // 양 끝 막대가 잘리지 않도록 0일·말일+1까지 여백을 둔다
        .chartXScale(domain: 0...(lastDay + 1))
        .chartYScale(domain: 0...maxY)
        .chartXSelection(value: $selectedDay)
        .chartXAxis {
            AxisMarks(values: xAxisDays) { value in
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text("\(day)일")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.separator))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .onChange(of: summary.month) { _, _ in selectedDay = nil }
        .onChange(of: selectedDay) { old, new in
            if new != nil, new != old { Haptics.selection() }
        }
        .accessibilityLabel("\(summary.month)월 일별 읽은 페이지 차트")
    }

    /// X축 라벨 — 1일, 5일 간격, 말일.
    private var xAxisDays: [Int] {
        var days = [1]
        days.append(contentsOf: stride(from: 5, to: lastDay - 2, by: 5))
        days.append(lastDay)
        return days
    }
}

// MARK: - 빈 상태 / 에러 상태 (카드 내부용 컴팩트 뷰)

private struct DailyPagesEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("이 달에 읽은 기록이 없어요")
                .font(.subheadline.weight(.medium))
            Text("책 상세에서 읽은 페이지를 기록하면 여기에 쌓여요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }
}

private struct DailyPagesErrorView: View {

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(Color(.systemOrange))
            Text("일별 기록을 불러오지 못했어요")
                .font(.subheadline.weight(.medium))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도", action: onRetry)
                .font(.subheadline.weight(.medium))
                .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }
}
