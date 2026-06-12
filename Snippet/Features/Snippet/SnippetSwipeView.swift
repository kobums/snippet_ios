import SwiftUI

// MARK: - SnippetSwipeView

/// 스니펫 스와이프 탭 — 카드 스택 + DragGesture 물리.
struct SnippetSwipeView: View {

    @Bindable var vm: SnippetViewModel

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if !vm.hasFetched && vm.isLoading {
                ProgressView()
            } else if vm.remainingToday == 0 && vm.cards.isEmpty {
                dailyLimitEmpty
            } else if vm.cards.isEmpty && vm.hasFetched {
                generalEmpty
            } else {
                cardStackContent
            }
        }
        .task {
            if !vm.hasFetched {
                await vm.fetchSnippets()
            }
        }
    }

    // MARK: - Card Stack

    private var cardStackContent: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    ForEach(Array(vm.cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, card in
                        SwipeCardView(
                            card: card,
                            index: index,
                            totalWidth: geo.size.width,
                            onSwipe: { isLike in
                                Task { await vm.handleSwipe(card: card, isLike: isLike) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }

            // 하단 힌트
            HStack {
                Text("← Pass")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
                Spacer()
                Text("Like →")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 16)

            // 하단 버튼
            if let topCard = vm.cards.first {
                bottomButtons(card: topCard)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 16)
            }
        }
    }

    private func bottomButtons(card: SnippetCard) -> some View {
        HStack(spacing: 32) {
            Button {
                Haptics.medium()
                Task { await vm.handleSwipe(card: card, isLike: false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(.systemRed))
                    .frame(width: 56, height: 56)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            }

            Button {
                Haptics.success()
                Task { await vm.handleSwipe(card: card, isLike: true) }
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .accentColor.opacity(0.3), radius: 6, x: 0, y: 2)
            }
        }
    }

    // MARK: - Empty States

    private var dailyLimitEmpty: some View {
        VStack(spacing: 16) {
            Text("🌙")
                .font(.system(size: 52))
            Text("오늘의 스니펫을 모두 읽었어요")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("내일 다시 새로운 문장을 만나보세요")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("하루 5문장 · 매일 자정 초기화")
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(32)
    }

    private var generalEmpty: some View {
        EmptyStateView(
            systemImage: "text.quote",
            title: "더 이상 카드가 없습니다.",
            message: "보관함이나 위젯을 확인해보세요!"
        )
    }
}

// MARK: - SwipeCardView

private struct SwipeCardView: View {

    let card: SnippetCard
    let index: Int
    let totalWidth: CGFloat
    let onSwipe: (Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    private var scaleEffect: CGFloat { 1.0 - CGFloat(index) * 0.05 }
    private var yOffset: CGFloat { CGFloat(index) * 8 }

    /// 드래그 비율 (-1.0 ~ 1.0)
    private var dragRatio: CGFloat {
        let threshold = totalWidth * 0.4
        return (offset.width / threshold).clamped(to: -1...1)
    }

    var body: some View {
        ZStack {
            cardContent
                .overlay(alignment: .topLeading) { likePassOverlay }
        }
        .offset(x: offset.width, y: offset.height * 0.3)
        .rotationEffect(.degrees(Double(offset.width / totalWidth) * 8))
        .scaleEffect(isDragging ? 1.0 : scaleEffect)
        .offset(y: isDragging ? 0 : yOffset)
        .gesture(dragGesture)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isDragging ? offset.width : 0)
        .zIndex(Double(-index))
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 태그 pill
            if let tag = card.tag, !tag.isEmpty {
                Text(tag)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .overlay(
                        Capsule().stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }

            // 인용문
            ScrollView {
                Text("\"\(card.text)\"")
                    .quoteStyle()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 180)
            }
            .frame(maxHeight: 260)

            // 책 제목 (저자 비공개)
            if let bookTitle = card.bookTitle, !bookTitle.isEmpty {
                HStack {
                    Spacer()
                    Text(bookTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }

            // 하단 구분선
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 48, height: 2)
                .frame(maxWidth: .infinity)
        }
        .padding(32)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .frame(maxWidth: 400)
    }

    // MARK: - LIKE/NOPE 오버레이

    private var likePassOverlay: some View {
        ZStack(alignment: .topLeading) {
            // LIKE (우측 스와이프)
            if dragRatio > 0 {
                Text("LIKE")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.green, lineWidth: 2.5)
                    )
                    .opacity(Double(dragRatio))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(20)
            }

            // NOPE (좌측 스와이프)
            if dragRatio < 0 {
                Text("NOPE")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.red, lineWidth: 2.5)
                    )
                    .opacity(Double(-dragRatio))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(20)
            }
        }
    }

    // MARK: - DragGesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation(.interactiveSpring()) {
                    offset = value.translation
                    isDragging = true
                }
            }
            .onEnded { value in
                let threshold = totalWidth * 0.4
                let translationX = value.translation.width
                let velocityX = value.predictedEndTranslation.width

                // 임계값(40%) 또는 빠른 플릭 판정
                let isLike = translationX > threshold || (translationX > 0 && velocityX > 600)
                let isPass = translationX < -threshold || (translationX < 0 && velocityX < -600)

                if isLike || isPass {
                    Haptics.medium()
                    let flyOffX: CGFloat = isLike ? 600 : -600
                    withAnimation(.easeOut(duration: 0.25)) {
                        offset = CGSize(width: flyOffX, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onSwipe(isLike)
                        offset = .zero
                        isDragging = false
                    }
                } else {
                    // 복귀
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        offset = .zero
                        isDragging = false
                    }
                }
            }
    }
}

// MARK: - Comparable + Clamp

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
