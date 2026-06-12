import SwiftUI

/// 별점 표시/입력 뷰.
///
/// - 표시 전용: `RatingStarsView(rating: 4)`
/// - 입력 모드: `RatingStarsView(rating: rating, onRatingChanged: { rating = $0 })`
///   (같은 별을 다시 탭하면 0으로 초기화)
struct RatingStarsView: View {

    let rating: Int
    var maxRating: Int = 5
    var starSize: CGFloat = 20
    var spacing: CGFloat = 4
    var onRatingChanged: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                star(at: index)
            }
        }
    }

    @ViewBuilder
    private func star(at index: Int) -> some View {
        let filled = index <= rating
        let image = Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: starSize))
            .foregroundStyle(filled ? Color(.systemYellow) : Color(.tertiaryLabel))

        if let onRatingChanged {
            Button {
                Haptics.selection()
                onRatingChanged(index == rating ? 0 : index)
            } label: {
                image
            }
            .buttonStyle(.plain)
        } else {
            image
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RatingStarsView(rating: 3)
        RatingStarsView(rating: 4, starSize: 32, onRatingChanged: { _ in })
    }
    .padding()
}
