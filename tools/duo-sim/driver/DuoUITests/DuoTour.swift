import XCTest

/// Snippet 앱을 Duo의 여러 자세에서 화면별로 순회하며 스크린샷·접근성 트리를 남긴다.
/// 화면 전환(duotool)과 디스플레이별 캡처는 호스트가 수행한다 — `Support.swift`의 `Host` 참고.
final class DuoTour: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "com.gowoobro.snippet")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() { continueAfterFailure = true }

    // MARK: 공통

    func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    func capture(_ name: String) {
        Host.shot(name)
        Host.dump(app, name)
    }

    func dismissSystemPrompts() {
        for label in ["허용 안 함", "허용하지 않음", "Don’t Allow", "Don't Allow"] {
            let b = springboard.alerts.buttons[label]
            if b.exists { b.tap(); pause(0.5) }
        }
        // 로그인 직후 뜨는 "암호를 저장하겠습니까?"
        let notNow = app.buttons["지금 안 함"]
        if notNow.exists { notNow.tap(); pause(0.8) }
    }

    /// 로컬 QA 백엔드의 테스트 계정으로만 로그인한다 (run.sh가 TEST_RUNNER_QA_* 로 넘김).
    func loginIfNeeded() {
        let email = app.textFields["Email"]
        guard email.waitForExistence(timeout: 8) else { return }
        email.tap(); email.typeText(Host.env["QA_EMAIL"] ?? "")
        let pw = app.secureTextFields["Password"]
        pw.tap(); pw.typeText(Host.env["QA_PASSWORD"] ?? "")
        app.buttons["Login"].tap()
        pause(3)
    }

    /// 같은 라벨이 메인 탭과 상단 서브탭에 동시에 있을 수 있다(스니펫·서재).
    /// 메인 탭은 세로 바든 하단 바든 항상 서브탭보다 아래에 있으므로 y로 고른다.
    func pick(_ label: String, lowest: Bool) -> XCUIElement {
        let all = app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex.filter { $0.exists && !$0.frame.isEmpty }
        guard let first = all.first else { return app.buttons[label].firstMatch }
        return all.reduce(first) { best, e in lowest ? (e.frame.minY > best.frame.minY ? e : best) : (e.frame.minY < best.frame.minY ? e : best) }
    }

    func mainTab(_ title: String) -> XCUIElement { pick(title, lowest: true) }

    func subTab(_ title: String) -> XCUIElement { pick(title, lowest: false) }

    @discardableResult
    func tap(_ e: XCUIElement, _ what: String, wait: Double = 1.5) -> Bool {
        guard e.waitForExistence(timeout: 4) else { print("[duo] missing: \(what)"); return false }
        if e.isHittable { e.tap() } else { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        pause(wait); return true
    }

    func closeSheet() {
        for label in ["취소", "닫기", "완료", "Close", "Cancel"] {
            let b = app.buttons[label].firstMatch
            if b.exists && b.isHittable { b.tap(); pause(1.2); return }
        }
        // 버튼이 없으면 아래로 쓸어 닫기
        let w = app.windows.firstMatch
        w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 0.05, thenDragTo: w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        pause(1.2)
    }

    func goBack() {
        let candidates = [app.buttons["BackButton"].firstMatch, app.navigationBars.buttons.element(boundBy: 0),
                          app.buttons["chevron.left"].firstMatch, app.buttons["뒤로"].firstMatch, app.buttons["Back"].firstMatch]
        for b in candidates where b.exists && b.isHittable { b.tap(); pause(1.2); return }
        let w = app.windows.firstMatch
        w.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).press(forDuration: 0.05, thenDragTo: w.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        pause(1.2)
    }

    func abandonTimer() {
        let giveUp = app.buttons["포기"].firstMatch
        if giveUp.waitForExistence(timeout: 2) && giveUp.isHittable {
            giveUp.tap(); pause(1)
            let confirm = app.alerts.buttons["포기"].firstMatch
            if confirm.exists { confirm.tap(); pause(1.5) }
        } else {
            closeSheet()
        }
    }

    // MARK: 화면 순회

    func tour(_ tag: String) {
        // 스니펫
        tap(mainTab("스니펫"), "tab 스니펫", wait: 2.5)
        tap(subTab("스와이프"), "sub 스와이프", wait: 2)
        capture("\(tag)_01_snippet_swipe")
        tap(subTab("보관함"), "sub 보관함")
        capture("\(tag)_02_snippet_archive")
        tap(subTab("스와이프"), "sub 스와이프", wait: 1)

        // 대시보드
        tap(mainTab("대시보드"), "tab 대시보드", wait: 2.5)
        tap(subTab("통계"), "sub 통계")
        capture("\(tag)_03_dashboard_stats")
        if tap(app.buttons["chart.bar.xaxis"].firstMatch, "통계 상세", wait: 2) {
            capture("\(tag)_03b_stats_detail")
            goBack()
        }
        app.swipeUp(); pause(1.2)
        capture("\(tag)_04_dashboard_stats_scrolled")
        tap(subTab("진행"), "sub 진행")
        capture("\(tag)_05_dashboard_progress")
        tap(subTab("서재"), "sub 서재(대시보드)")
        capture("\(tag)_06_dashboard_library")
        tap(subTab("통계"), "sub 통계", wait: 1)

        // 독서기록
        tap(mainTab("독서기록"), "tab 독서기록", wait: 2.5)
        tap(subTab("스니펫"), "sub 스니펫(기록)")
        capture("\(tag)_07_records_snippet")
        tap(subTab("세션"), "sub 세션")
        capture("\(tag)_08_records_session")
        tap(subTab("스니펫"), "sub 스니펫(기록)")
        if tap(app.buttons["calendar"].firstMatch, "records calendar", wait: 1.8) {
            capture("\(tag)_09_records_month_sheet")
            closeSheet()
        }
        if tap(app.buttons["plus"].firstMatch, "records plus", wait: 2.5) {
            capture("\(tag)_10_add_record_sheet")
            closeSheet()
        }

        // 서재
        tap(mainTab("서재"), "tab 서재", wait: 2.5)
        tap(subTab("소장"), "sub 소장")
        capture("\(tag)_11_library_have")
        tap(subTab("위시"), "sub 위시")
        capture("\(tag)_12_library_wish")
        tap(subTab("소장"), "sub 소장", wait: 1)
        if tap(app.buttons["plus"].firstMatch, "library plus", wait: 2) {
            capture("\(tag)_13_book_add_sheet")
            closeSheet()
        }
        if tap(app.staticTexts["바람이 머무는 서점"].firstMatch, "book cell", wait: 2.5) {
            capture("\(tag)_14_book_detail")
            if tap(app.buttons["독서 시작"].firstMatch, "독서 시작", wait: 2.5) {
                capture("\(tag)_16_timer")
                abandonTimer()
            }
            app.swipeUp(); pause(1.2)
            capture("\(tag)_15_book_detail_scrolled")
            goBack()
        }

        // 프로필
        tap(mainTab("프로필"), "tab 프로필", wait: 2)
        capture("\(tag)_18_profile")
        tap(mainTab("스니펫"), "tab 스니펫", wait: 1)
    }

    // MARK: 시나리오

    /// TOUR_CONFIGS(쉼표 구분): outer, inner_land, inner_port, book, book_port (Duo) / port, land, first (그 밖의 기기)
    func testTour() {
        let configs = (Host.env["TOUR_CONFIGS"] ?? "outer,inner_land,inner_port,book").split(separator: ",").map(String.init)
        Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
        app.launch()
        pause(3)
        dismissSystemPrompts()
        loginIfNeeded()
        dismissSystemPrompts()
        XCTAssertTrue(mainTab("스니펫").waitForExistence(timeout: 20), "탭이 안 보임")

        // 기기 방향은 바깥 화면 기준이다: portrait로 펼치면 안쪽 화면은 가로, landscapeLeft로 펼쳐야 세로.
        for c in configs {
            switch c {
            case "outer":
                Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
                pause(1.5); tour("A_outer")
            case "inner_land":
                Host.swap("-position=open -duration=0 -deviceOrientation=portrait -wait", to: "LCD-1")
                pause(2); tour("B_inner_land")
            case "inner_port":
                Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
                Host.swap("-position=open -duration=0 -deviceOrientation=landscapeLeft -wait", to: "LCD-1")
                pause(2); tour("C_inner_port")
            case "book":
                Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
                Host.swap("-position=book -deviceOrientation=portrait -wait", to: "LCD-1")
                pause(2); tour("D_book")
            case "book_port":
                Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
                Host.swap("-position=book -deviceOrientation=landscapeLeft -wait", to: "LCD-1")
                pause(2); tour("E_book_port")
            case "port", "land":
                // Duo가 아닌 기기(iPad 등) 회전 비교 — XCUIDevice 회전이 그대로 먹는다
                XCUIDevice.shared.orientation = c == "land" ? .landscapeLeft : .portrait
                pause(2); tour(c == "land" ? "G_land" : "H_port")
            case "first":
                // Duo가 아닌 비교용 기기: 첫 화면(스와이프)과 대시보드만
                tap(mainTab("스니펫"), "tab 스니펫", wait: 3)
                capture("F_first_01_snippet_swipe")
                tap(mainTab("대시보드"), "tab 대시보드", wait: 3)
                capture("F_first_03_dashboard_stats")
            default:
                print("[duo] unknown config: \(c)")
            }
        }
        Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
    }
}
