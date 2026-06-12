import Foundation
import Observation

// MARK: - SessionStatus

/// 세션 상태 머신.
enum SessionStatus: Equatable {
    case idle
    case running
    case paused
    case completing   // 완료 입력 대기
    case saving       // API 저장 중
    case done         // 저장 완료
}

// MARK: - ReadingTimer

/// Wall-clock epoch 기반 독서 타이머.
///
/// 영속 키 (UserDefaults):
///   - `rs_start_epoch`   : 현재 running 구간 시작 epoch (TimeInterval)
///   - `rs_base_elapsed`  : 이전 구간 누적 초 (Double)
///   - `rs_paused`        : Bool
///   - `rs_userbook_id`   : Int
///   - `rs_start_page`    : Int
///   - `rs_book_title`    : String
///
/// elapsed = baseElapsed + (now - startEpoch)  — tick 카운트가 아닌 epoch 차이.
@MainActor
@Observable
final class ReadingTimer {

    // MARK: Public state

    private(set) var status: SessionStatus = .idle
    private(set) var elapsed: TimeInterval = 0    // 표시용 (1초 갱신)
    private(set) var startPage: Int = 0
    private(set) var userBookId: Int = 0
    private(set) var bookTitle: String = ""
    var errorMessage: String? = nil

    // MARK: Private

    private var startEpoch: TimeInterval = 0      // 현재 running 구간 시작
    private var baseElapsed: TimeInterval = 0     // 일시정지 전 누적
    private var uiTimer: Timer? = nil

    /// 복구 시 인정하는 최대 공백(앱 장기 종료 등 비정상 값 방어). 24시간.
    private let maxRecoverGap: TimeInterval = 24 * 60 * 60

    private let defaults = UserDefaults.standard

    // UserDefaults 키
    private enum Key {
        static let startEpoch  = "rs_start_epoch"
        static let base        = "rs_base_elapsed"
        static let paused      = "rs_paused"
        static let userBookId  = "rs_userbook_id"
        static let startPage   = "rs_start_page"
        static let bookTitle   = "rs_book_title"
    }

    // MARK: - 복구 가능 세션 확인

    /// 앱 재시작 시 진행 중인 세션이 있으면 true.
    var isRecoverable: Bool {
        defaults.double(forKey: Key.startEpoch) > 0 ||
        defaults.double(forKey: Key.base) > 0
    }

    /// 복구: 저장된 epoch 기반으로 elapsed 재계산 후 running 상태로 복귀.
    func recover() {
        guard isRecoverable else { return }
        baseElapsed = defaults.double(forKey: Key.base)
        startEpoch  = defaults.double(forKey: Key.startEpoch)
        let isPaused = defaults.bool(forKey: Key.paused)
        userBookId  = defaults.integer(forKey: Key.userBookId)
        startPage   = defaults.integer(forKey: Key.startPage)
        bookTitle   = defaults.string(forKey: Key.bookTitle) ?? ""

        if isPaused {
            elapsed = baseElapsed
            status = .paused
        } else {
            // 비정상적으로 큰 공백(앱 장기 종료)은 상한 처리하고, 누적을 base로 고정한 뒤
            // startEpoch을 현재로 재설정해 이후 tick 계산이 다시 튀지 않게 한다.
            let now = Date().timeIntervalSince1970
            let gap = min(max(0, now - startEpoch), maxRecoverGap)
            baseElapsed += gap
            startEpoch = now
            elapsed = baseElapsed
            defaults.set(baseElapsed, forKey: Key.base)
            defaults.set(startEpoch, forKey: Key.startEpoch)
            status = .running
            startUITimer()
        }
    }

    // MARK: - 세션 시작

    func start(userBookId: Int, startPage: Int, bookTitle: String) {
        self.userBookId = userBookId
        self.startPage  = startPage
        self.bookTitle  = bookTitle
        baseElapsed     = 0
        startEpoch      = Date().timeIntervalSince1970
        elapsed         = 0
        status          = .running
        errorMessage    = nil

        persist(paused: false)
        startUITimer()
    }

    // MARK: - 일시정지 / 재개

    func pause() {
        guard status == .running else { return }
        baseElapsed = currentElapsed()
        elapsed     = baseElapsed
        status      = .paused
        stopUITimer()
        defaults.set(baseElapsed, forKey: Key.base)
        defaults.set(true, forKey: Key.paused)
    }

    func resume() {
        guard status == .paused else { return }
        startEpoch = Date().timeIntervalSince1970
        status     = .running
        defaults.set(startEpoch, forKey: Key.startEpoch)
        defaults.set(false, forKey: Key.paused)
        startUITimer()
    }

    // MARK: - 완료 준비 (타이머 정지, 입력 화면 전환)

    /// 타이머를 멈추고 완료 입력 화면으로 전환할 준비.
    func prepareFinish() {
        guard status == .running || status == .paused else { return }
        baseElapsed = currentElapsed()
        elapsed     = baseElapsed
        stopUITimer()
        status = .completing
        // 저장 전까지 영속 데이터를 유지해 완료 입력 화면에서 앱이 종료돼도
        // 세션을 복구할 수 있게 한다. 일시정지 스냅샷으로 기록(recover 시 baseElapsed 기준).
        defaults.set(baseElapsed, forKey: Key.base)
        defaults.set(true, forKey: Key.paused)
    }

    // MARK: - 완료 저장

    /// POST /readingsessions 호출.
    /// 성공 시 status = .done.  실패 시 status = .completing + errorMessage.
    func finishSession(endPage: Int) async {
        guard status == .completing else { return }
        status = .saving
        errorMessage = nil

        let durationSeconds = Int(elapsed)
        let sessionDate = APIDate.dayString()

        let request = ReadingSessionAddRequest(
            userBookId: userBookId,
            durationSeconds: durationSeconds,
            startPage: startPage,
            endPage: endPage,
            sessionDate: sessionDate
        )

        do {
            _ = try await ReadingSessionService().add(request)
            clearPersistence()   // 저장 성공 후에만 영속 데이터 정리
            status = .done
        } catch {
            errorMessage = "저장에 실패했습니다. 다시 시도해주세요."
            status = .completing
        }
    }

    // MARK: - 포기

    func cancel() {
        stopUITimer()
        clearPersistence()
        baseElapsed = 0
        startEpoch  = 0
        elapsed     = 0
        status      = .idle
        errorMessage = nil
    }

    // MARK: - 현재 elapsed 계산 (진실 원천)

    private func currentElapsed() -> TimeInterval {
        guard status == .running, startEpoch > 0 else { return baseElapsed }
        return baseElapsed + (Date().timeIntervalSince1970 - startEpoch)
    }

    // MARK: - 백그라운드 복귀 시 재계산

    /// scenePhase가 active로 돌아올 때 호출 — UI 타이머 없이도 정확한 elapsed 복원.
    func recalculateElapsed() {
        guard status == .running else { return }
        elapsed = currentElapsed()
    }

    // MARK: - UI 타이머 (1초 갱신, 표시 전용)

    private func startUITimer() {
        stopUITimer()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            // self가 사라졌으면(뷰가 외부 경로로 dismiss 등) 타이머가 스스로 무효화돼
            // run loop에 no-op 타이머가 남지 않게 한다.
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in
                self.elapsed = self.currentElapsed()
            }
        }
    }

    private func stopUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }

    // MARK: - UserDefaults 영속

    private func persist(paused: Bool) {
        defaults.set(startEpoch,  forKey: Key.startEpoch)
        defaults.set(baseElapsed, forKey: Key.base)
        defaults.set(paused,      forKey: Key.paused)
        defaults.set(userBookId,  forKey: Key.userBookId)
        defaults.set(startPage,   forKey: Key.startPage)
        defaults.set(bookTitle,   forKey: Key.bookTitle)
    }

    private func clearPersistence() {
        defaults.removeObject(forKey: Key.startEpoch)
        defaults.removeObject(forKey: Key.base)
        defaults.removeObject(forKey: Key.paused)
        defaults.removeObject(forKey: Key.userBookId)
        defaults.removeObject(forKey: Key.startPage)
        defaults.removeObject(forKey: Key.bookTitle)
    }
}
