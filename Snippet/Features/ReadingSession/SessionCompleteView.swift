import SwiftUI

// MARK: - SessionCompleteView

/// 세션 완료 2단계 화면.
///
/// Phase 1 (status == .completing): 종료 페이지 입력 + "기록 저장" 버튼.
/// Phase 2 (status == .done):       요약 통계 (소요시간 / 읽은 페이지 / 페이스).
struct SessionCompleteView: View {

    @Bindable var timer: ReadingTimer
    let bookTitle: String
    let startPage: Int
    let onFinish: () -> Void     // "완료" → 화면 닫기
    let onCancel: () -> Void     // "기록 취소" 확인 → 화면 닫기

    @State private var endPageText: String = ""
    @State private var endPageError: String? = nil
    @State private var showCancelAlert = false

    // 공유 관련
    @State private var showShareSheet = false
    @State private var shareBookTitle = true
    @State private var shareRenderedURL: URL? = nil
    @State private var isRenderingShare = false

    private var elapsedFormatted: String {
        let total = Int(timer.elapsed)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h)시간 \(m)분 \(s)초"
        } else if m > 0 {
            return "\(m)분 \(s)초"
        } else {
            return "\(s)초"
        }
    }

    private var pagesReadPreview: Int? {
        guard let end = Int(endPageText), end >= startPage else { return nil }
        return end - startPage
    }

    private var pacePreview: Double? {
        guard let pages = pagesReadPreview, pages > 0 else { return nil }
        return Double(timer.elapsed) / 60.0 / Double(pages)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch timer.status {
                case .completing:
                    inputPhase
                case .saving:
                    savingPhase
                case .done:
                    resultPhase
                default:
                    // 예외 상태: 화면 닫기
                    Color.clear.onAppear { onFinish() }
                }
            }
            .navigationTitle("독서 완료")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if timer.status == .done {
                            onFinish()
                        } else {
                            showCancelAlert = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("기록 취소", isPresented: $showCancelAlert) {
                Button("계속", role: .cancel) {}
                Button("취소", role: .destructive) {
                    onCancel()
                }
            } message: {
                Text("기록을 저장하지 않고 종료할까요?")
            }
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - Phase 1: 종료 페이지 입력

    private var inputPhase: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 책 제목
                Text(bookTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 8)

                // 독서 시간 박스
                VStack(spacing: 4) {
                    Text(elapsedFormatted)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                    Text("독서 시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // 시작 페이지 안내
                VStack(spacing: 4) {
                    Text("어디까지 읽으셨나요?")
                        .font(.subheadline.weight(.semibold))
                    Text("시작 페이지: \(startPage)p")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 종료 페이지 입력
                VStack(spacing: 6) {
                    HStack {
                        TextField("0", text: $endPageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 40, weight: .semibold))
                            .frame(maxWidth: 160)
                            .onChange(of: endPageText) { _, _ in
                                endPageError = nil
                            }
                        Text("페이지")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if let err = endPageError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)

                // 프리뷰 칩
                if let pages = pagesReadPreview, let pace = pacePreview {
                    HStack(spacing: 12) {
                        chipView("읽은 페이지 \(pages)p", color: .accentColor)
                        chipView(String(format: "페이스 %.1f min/p", pace), color: .secondary)
                    }
                    .opacity(endPageText.isEmpty ? 0 : 1)
                    .animation(.easeInOut, value: endPageText)
                }

                // 저장 버튼
                Button {
                    saveSession()
                } label: {
                    Text("기록 저장")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .disabled(endPageText.isEmpty)

                // API 에러 메시지
                if let err = timer.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 32)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Phase 2: 저장 중

    private var savingPhase: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("저장 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase 3: 결과

    private var resultPhase: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 성공 아이콘
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 16)

                Text(bookTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // 통계 카드 3열
                HStack(spacing: 12) {
                    statCard(title: "독서 시간", value: elapsedFormatted)

                    if let end = Int(endPageText) {
                        let pages = max(0, end - startPage)
                        statCard(title: "읽은 페이지", value: "\(pages)p")

                        let pace = pages > 0 ? Double(timer.elapsed) / 60.0 / Double(pages) : 0
                        statCard(title: "페이스", value: String(format: "%.1f min/p", pace))
                    }
                }
                .padding(.horizontal)

                // SNS 공유 섹션
                shareSection

                // 완료 버튼
                Button {
                    Haptics.success()
                    onFinish()
                } label: {
                    Text("완료")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                Spacer(minLength: 32)
            }
            .padding(.vertical)
        }
    }

    // MARK: - 공유 섹션

    private var shareSection: some View {
        VStack(spacing: 14) {
            Divider()
                .padding(.horizontal)

            // 책 제목 표시 토글
            HStack {
                Label("책 제목 표시", systemImage: "text.book.closed")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: $shareBookTitle)
                    .labelsHidden()
            }
            .padding(.horizontal)

            // 공유 카드 미리보기
            shareCardPreview
                .padding(.horizontal)

            // 공유하기 버튼
            Button {
                renderAndShare()
            } label: {
                Group {
                    if isRenderingShare {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Label("공유하기", systemImage: "square.and.arrow.up")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .disabled(isRenderingShare)
            .sheet(isPresented: $showShareSheet) {
                if let url = shareRenderedURL {
                    ActivityShareSheet(activityItems: [url])
                        .ignoresSafeArea()
                }
            }
        }
    }

    @ViewBuilder
    private var shareCardPreview: some View {
        let pages: Int = {
            guard let end = Int(endPageText), end >= startPage else { return 0 }
            return end - startPage
        }()
        let pace: Double = pages > 0 ? Double(timer.elapsed) / 60.0 / Double(pages) : 0.0

        ShareCardView(
            mode: .session(
                elapsedText: elapsedFormatted,
                pagesRead: pages,
                pace: pace,
                bookTitle: bookTitle,
                bookAuthor: "",
                showBookTitle: shareBookTitle
            ),
            background: .gradient
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        .frame(maxWidth: 280)
    }

    private func renderAndShare() {
        let pages: Int = {
            guard let end = Int(endPageText), end >= startPage else { return 0 }
            return end - startPage
        }()
        let pace: Double = pages > 0 ? Double(timer.elapsed) / 60.0 / Double(pages) : 0.0

        isRenderingShare = true
        Task { @MainActor in
            let image = ShareCardRenderer.render(
                mode: .session(
                    elapsedText: elapsedFormatted,
                    pagesRead: pages,
                    pace: pace,
                    bookTitle: bookTitle,
                    bookAuthor: "",
                    showBookTitle: shareBookTitle
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

    // MARK: - 저장 액션

    private func saveSession() {
        guard let endPage = Int(endPageText) else {
            endPageError = "숫자를 입력해주세요."
            return
        }
        if endPage < 0 {
            endPageError = "음수는 입력할 수 없습니다."
            return
        }
        if endPage < startPage {
            endPageError = "종료 페이지는 시작 페이지(\(startPage)p) 이상이어야 합니다."
            return
        }
        endPageError = nil
        Task {
            await timer.finishSession(endPage: endPage)
        }
    }

    // MARK: - 서브뷰

    private func chipView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: Capsule())
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
