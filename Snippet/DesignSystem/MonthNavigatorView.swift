import SwiftUI

/// 월 네비게이터: `‹ 2026년 6월 ›`
/// 가운데를 탭하면 년/월 휠 피커 시트가 열린다. 미래 월로는 이동 불가.
struct MonthNavigatorView: View {

    @Binding var year: Int
    @Binding var month: Int

    @State private var showsPicker = false

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var currentMonth: Int { Calendar.current.component(.month, from: .now) }

    private var isAtCurrentMonth: Bool {
        year > currentYear || (year == currentYear && month >= currentMonth)
    }

    var body: some View {
        HStack {
            navButton(systemImage: "chevron.left", disabled: false) {
                moveMonth(by: -1)
            }

            Spacer()

            Button {
                showsPicker = true
            } label: {
                Text("\(String(year))년 \(month)월")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            navButton(systemImage: "chevron.right", disabled: isAtCurrentMonth) {
                moveMonth(by: 1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showsPicker) {
            MonthYearPickerSheet(year: $year, month: $month)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    private func navButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .foregroundStyle(disabled ? Color(.quaternaryLabel) : .primary)
    }

    private func moveMonth(by delta: Int) {
        var newYear = year
        var newMonth = month + delta
        if newMonth < 1 {
            newMonth = 12
            newYear -= 1
        } else if newMonth > 12 {
            newMonth = 1
            newYear += 1
        }
        // 미래 월 차단
        if newYear > currentYear || (newYear == currentYear && newMonth > currentMonth) {
            return
        }
        year = newYear
        month = newMonth
    }
}

// MARK: - 년/월 휠 피커 시트

private struct MonthYearPickerSheet: View {

    @Binding var year: Int
    @Binding var month: Int

    @Environment(\.dismiss) private var dismiss
    @State private var tempYear: Int = 0
    @State private var tempMonth: Int = 1

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var currentMonth: Int { Calendar.current.component(.month, from: .now) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("완료") {
                    year = tempYear
                    month = clampedMonth(tempMonth, in: tempYear)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            HStack(spacing: 0) {
                Picker("년", selection: $tempYear) {
                    ForEach((currentYear - 30)...currentYear, id: \.self) { y in
                        Text("\(String(y))년").tag(y)
                    }
                }
                .pickerStyle(.wheel)

                Picker("월", selection: $tempMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text("\(m)월").tag(m)
                    }
                }
                .pickerStyle(.wheel)
            }
        }
        .onAppear {
            tempYear = year
            tempMonth = month
        }
    }

    /// 미래 월 선택 시 현재 월로 보정.
    private func clampedMonth(_ month: Int, in year: Int) -> Int {
        if year == currentYear, month > currentMonth {
            return currentMonth
        }
        return month
    }
}

#Preview {
    struct Demo: View {
        @State var year = 2026
        @State var month = 6
        var body: some View {
            MonthNavigatorView(year: $year, month: $month)
                .padding()
        }
    }
    return Demo()
}
