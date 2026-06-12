import SwiftUI

/// 연 네비게이터: `‹ 2026년 ›`
/// 가운데를 탭하면 연도 휠 피커 시트가 열린다. 미래 연도로는 이동 불가.
struct YearNavigatorView: View {

    @Binding var year: Int

    @State private var showsPicker = false

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var isAtCurrentYear: Bool { year >= currentYear }

    var body: some View {
        HStack {
            navButton(systemImage: "chevron.left", disabled: false) {
                year -= 1
            }

            Spacer()

            Button {
                showsPicker = true
            } label: {
                Text("\(String(year))년")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            navButton(systemImage: "chevron.right", disabled: isAtCurrentYear) {
                if year < currentYear { year += 1 }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showsPicker) {
            YearPickerSheet(year: $year)
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
}

// MARK: - 연도 휠 피커 시트

private struct YearPickerSheet: View {

    @Binding var year: Int

    @Environment(\.dismiss) private var dismiss
    @State private var tempYear: Int = 0

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("완료") {
                    year = tempYear
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Picker("년", selection: $tempYear) {
                ForEach((currentYear - 30)...currentYear, id: \.self) { y in
                    Text("\(String(y))년").tag(y)
                }
            }
            .pickerStyle(.wheel)
        }
        .onAppear {
            tempYear = year
        }
    }
}

#Preview {
    struct Demo: View {
        @State var year = 2026
        var body: some View {
            YearNavigatorView(year: $year)
                .padding()
        }
    }
    return Demo()
}
