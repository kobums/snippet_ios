import SwiftUI

// MARK: - ReadingTimerView

/// 독서 세션 타이머 화면 (ActiveSessionScreen 스펙).
///
/// 진입: BookDetailView의 "독서 시작" 버튼 → .fullScreenCover
/// 상태: idle → (3초 카운트다운) → running ⇄ paused → completing → SessionCompleteView
struct ReadingTimerView: View {

    let userBookId: Int
    let startPage: Int
    let bookTitle: String
    let onDismiss: () -> Void       // 포기 또는 세션 완료 후 호출

    @State private var timer = ReadingTimer()
    @State private var showAbandonAlert = false
    @State private var showCompleteView = false

    // 카운트다운 연출
    @State private var countdownValue: Int? = 3
    @State private var countdownScale: CGFloat = 0.5
    @State private var countdownOpacity: Double = 0

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // 배경: primary 단색
            Color.brandNavy.ignoresSafeArea()

            // 본문
            VStack(spacing: 0) {
                // 상단 바
                HStack {
                    Text(bookTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                    Button("포기") {
                        showAbandonAlert = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // 대형 타이머
                Text(formattedElapsed)
                    .font(.system(size: 72, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(timer.status == .paused ? 0.4 : 1.0))
                    .animation(.easeInOut(duration: 0.3), value: timer.status)
                    .contentTransition(.numericText())

                // 에러 메시지
                if let err = timer.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 8)
                }

                // 시작 페이지 캡션
                Text("\(startPage)p 에서 시작")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 12)

                Spacer()

                // 버튼 영역
                VStack(spacing: 20) {
                    // 일시정지 / 재개 버튼
                    Button {
                        Haptics.medium()
                        if timer.status == .running {
                            timer.pause()
                            LocalNotifications.scheduleReadingActiveNotification(
                                bookTitle: bookTitle,
                                elapsedSeconds: Int(timer.elapsed)
                            )
                        } else if timer.status == .paused {
                            timer.resume()
                            LocalNotifications.cancelReadingActiveNotification()
                        }
                    } label: {
                        Image(systemName: timer.status == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(.white.opacity(0.15))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(Circle())
                    }
                    .disabled(timer.status != .running && timer.status != .paused)

                    // 독서 완료 버튼
                    Button {
                        Haptics.success()
                        timer.prepareFinish()
                        showCompleteView = true
                    } label: {
                        Text("독서 완료")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                            )
                    }
                    .disabled(timer.status != .running && timer.status != .paused)
                }
                .padding(.bottom, 48)
            }

            // 카운트다운 오버레이 (3-2-1)
            if let count = countdownValue {
                Color.brandNavy.ignoresSafeArea()
                Text("\(count)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(countdownScale)
                    .opacity(countdownOpacity)
            }
        }
        .task {
            await runCountdown()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                timer.recalculateElapsed()
                LocalNotifications.cancelReadingActiveNotification()
            } else if newPhase == .background, timer.status == .running {
                LocalNotifications.scheduleReadingActiveNotification(
                    bookTitle: bookTitle,
                    elapsedSeconds: Int(timer.elapsed)
                )
            }
        }
        .alert("독서 포기", isPresented: $showAbandonAlert) {
            Button("계속 읽기", role: .cancel) {}
            Button("포기", role: .destructive) {
                timer.cancel()
                LocalNotifications.cancelReadingActiveNotification()
                onDismiss()
            }
        } message: {
            Text("세션을 종료할까요? 기록이 저장되지 않습니다.")
        }
        .fullScreenCover(isPresented: $showCompleteView) {
            SessionCompleteView(
                timer: timer,
                bookTitle: bookTitle,
                startPage: startPage,
                onFinish: {
                    showCompleteView = false
                    onDismiss()
                },
                onCancel: {
                    // 완료 취소 → 타이머 화면도 닫기
                    showCompleteView = false
                    timer.cancel()
                    onDismiss()
                }
            )
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - 카운트다운 3-2-1

    private func runCountdown() async {
        for n in stride(from: 3, through: 1, by: -1) {
            countdownValue = n
            countdownScale = 0.5
            countdownOpacity = 0
            withAnimation(.spring(duration: 0.3)) {
                countdownScale = 1.0
                countdownOpacity = 1.0
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                countdownOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        countdownValue = nil

        // 카운트다운 완료 → 세션 시작
        await LocalNotifications.requestAuthorization()
        timer.start(userBookId: userBookId, startPage: startPage, bookTitle: bookTitle)
    }

    // MARK: - 포맷

    private var formattedElapsed: String {
        let total = Int(timer.elapsed)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
