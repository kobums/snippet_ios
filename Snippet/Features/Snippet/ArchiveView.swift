import SwiftUI

// MARK: - ArchiveView

/// 보관함 탭 — 좋아요한 스니펫 목록 + Reveal 인터랙션.
struct ArchiveView: View {

    @Bindable var vm: SnippetViewModel

    var body: some View {
        ZStack {
            if vm.isArchiveLoading && vm.archiveItems.isEmpty {
                ProgressView()
            } else if let error = vm.archiveError {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
            } else if vm.archiveItems.isEmpty {
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: "아직 모은 문장이 없어요",
                    message: "마음에 드는 문장을 오른쪽으로 스와이프하면\n여기에 모을 수 있어요"
                )
            } else {
                archiveList
            }
        }
        .task {
            await vm.fetchArchive()
        }
        .sheet(item: $vm.revealItem) { item in
            SnippetRevealView(item: item) {
                vm.dismissReveal()
            }
        }
        .refreshable {
            await vm.fetchArchive()
        }
    }

    // MARK: - List

    private var archiveList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(vm.archiveItems) { item in
                    ArchiveCardView(item: item)
                        .onTapGesture {
                            Haptics.selection()
                            vm.showReveal(for: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await vm.removeFromArchive(item: item) }
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - ArchiveCardView

private struct ArchiveCardView: View {

    let item: SnippetArchive
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 태그 pill
            if let tag = item.tag, !tag.isEmpty {
                Text(tag)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            // 인용문
            Text("\"\(item.text)\"")
                .font(.body)
                .lineSpacing(6)
                .fontWeight(.light)
                .lineLimit(isExpanded ? nil : 5)
                .multilineTextAlignment(.leading)

            // 책 제목 - 저자 (우측 정렬)
            HStack {
                Spacer()
                Text("\(item.bookTitle) — \(item.bookAuthor)")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .lineLimit(1)
            }

            // Reveal 확장 패널 (AnimatedSize 대응)
            if isExpanded {
                revealPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Reveal 패널

    private var revealPanel: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(alignment: .top, spacing: 16) {
                BookCoverView(urlString: item.coverUrl, size: .large)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.bookTitle)
                        .font(.headline)
                        .lineLimit(3)
                    Text(item.bookAuthor)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !item.affiliateUrl.isEmpty,
                       let url = URL(string: item.affiliateUrl) {
                        Link(destination: url) {
                            Text("이 책 구매하기")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor, in: Capsule())
                        }
                        .padding(.top, 4)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
