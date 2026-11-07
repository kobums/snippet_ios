import XCTest

/// 호스트(맥)의 `scripts/watcher.sh`와 파일로 통신한다.
/// 시뮬레이터 안의 테스트는 접기·펴기(duotool)나 디스플레이별 캡처를 직접 못 하므로 요청 파일을 남기고 결과를 기다린다.
enum Host {
    static let env = ProcessInfo.processInfo.environment
    static var ipc: String { env["IPC_DIR"] ?? "/tmp/duo-ipc" }
    static var treeDir: String { env["TREE_DIR"] ?? "/tmp/duo-tree" }
    static var runID: String { env["RUN_ID"] ?? "run" }
    /// 지금 앱이 떠 있는 디스플레이 — LCD = 바깥, LCD-1 = 안쪽
    static var display = "LCD"

    @discardableResult
    static func run(_ cmd: String, timeout: TimeInterval = 60) -> String {
        let id = UUID().uuidString
        let req = "\(ipc)/req-\(id).txt", done = "\(ipc)/done-\(id).txt"
        try? cmd.write(toFile: req, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let out = try? String(contentsOfFile: done, encoding: .utf8) {
                try? FileManager.default.removeItem(atPath: done)
                return out.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return "timeout"
    }

    /// duotool swap 인자를 넘겨 접기·펴기. 전환 애니메이션·레이아웃이 끝날 때까지 잠시 기다린다.
    static func swap(_ args: String, to newDisplay: String) {
        let out = run("swap \(args)")
        display = newDisplay
        Thread.sleep(forTimeInterval: 2.5)
        print("[duo] swap \(args) -> \(out)")
    }

    static func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        print("[duo] shot \(name) -> \(run("shot \(display) \(runID) \(name)"))")
    }

    /// 화면별 접근성 트리 — 요소 프레임으로 레이아웃 문제를 수치로 확인할 때 쓴다.
    static func dump(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: treeDir, withIntermediateDirectories: true)
        try? app.debugDescription.write(toFile: "\(treeDir)/\(name).txt", atomically: true, encoding: .utf8)
    }
}
