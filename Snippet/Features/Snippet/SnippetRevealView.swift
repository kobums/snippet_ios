import SwiftUI

// MARK: - SnippetRevealView

/// 좋아요 후 책 정보 공개 연출.
/// 보관함 카드 탭 시 sheet로 표시: 표지+제목+저자 페이드인, 제휴 링크 버튼.
struct SnippetRevealView: View {

    let item: SnippetArchive
    var onDismiss: (() -> Void)?

    @State private var coverAppeared = false
    @State private var infoAppeared = false
    @State private var buttonAppeared = false

    // 공유
    @State private var showShareSheet = false
    @State private var shareRenderedURL: URL? = nil
    @State private var isRenderingShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // 스니펫 인용문
                    VStack(spacing: 12) {
                        if let tag = item.tag, !tag.isEmpty {
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        Text("\"\(item.text)\"")
                            .quoteStyle()
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Divider()
                        .padding(.horizontal, 40)

                    // 책 표지 (페이드인 연출)
                    BookCoverView(
                        urlString: item.coverUrl,
                        size: .custom(width: 120, height: 180, cornerRadius: 10),
                        showsShadow: true
                    )
                    .opacity(coverAppeared ? 1 : 0)
                    .scaleEffect(coverAppeared ? 1 : 0.88)

                    // 제목 + 저자 (페이드인)
                    VStack(spacing: 6) {
                        Text(item.bookTitle)
                            .font(.serifTitle)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)

                        if !item.bookAuthor.isEmpty {
                            Text(item.bookAuthor)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .opacity(infoAppeared ? 1 : 0)
                    .offset(y: infoAppeared ? 0 : 8)

                    // 제휴 링크 버튼
                    if !item.affiliateUrl.isEmpty,
                       let url = URL(string: item.affiliateUrl) {
                        Link(destination: url) {
                            Label("이 책 구매하기", systemImage: "cart.fill")
                                .font(.headline)
                                .foregroundStyle(Color.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor, in: Capsule())
                        }
                        .padding(.horizontal, 32)
                        .opacity(buttonAppeared ? 1 : 0)
                        .offset(y: buttonAppeared ? 0 : 10)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
            .navigationTitle("책 공개")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        renderAndShare()
                    } label: {
                        if isRenderingShare {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(isRenderingShare)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { onDismiss?() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareRenderedURL {
                    ActivityShareSheet(activityItems: [url])
                        .ignoresSafeArea()
                }
            }
        }
        .onAppear { runRevealAnimation() }
    }

    private func renderAndShare() {
        isRenderingShare = true
        Task { @MainActor in
            let image = ShareCardRenderer.render(
                mode: .snippet(
                    text: item.text,
                    tag: item.tag,
                    bookTitle: item.bookTitle,
                    bookAuthor: item.bookAuthor
                ),
                background: .gradient
            )
            if let image, let url = ShareCardRenderer.saveTempPNG(image) {
                shareRenderedURL = url
                isRenderingShare = false
                showShareSheet = true
            } else {
                isRenderingShare = false
            }
        }
    }

    private func runRevealAnimation() {
        withAnimation(.easeOut(duration: 0.4)) {
            coverAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            infoAppeared = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.4)) {
            buttonAppeared = true
        }
    }
}

#Preview {
    SnippetRevealView(
        item: SnippetArchive.preview
    )
}

private extension SnippetArchive {
    static let preview = try! JSONDecoder().decode(
        SnippetArchive.self,
        from: Data("""
        {
          "id": 1,
          "text": "어둠이 없으면 별도 없다.",
          "tag": "철학",
          "bookTitle": "데미안",
          "bookAuthor": "헤르만 헤세",
          "coverUrl": "",
          "affiliateUrl": "https://example.com"
        }
        """.utf8)
    )
}
