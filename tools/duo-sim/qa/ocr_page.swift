// OCR 테스트용 책 페이지 이미지 (직접 쓴 문장 6줄, 1200x1600). 사용: swift ocr_page.swift <출력.png>
import AppKit
let lines = ["첫째 줄: 바람이 머무는 서점에는 늘 같은 시간에 불이 켜졌다.",
             "둘째 줄: 나는 그 불빛 아래에서 오래된 질문을 다시 꺼냈다.",
             "셋째 줄: 문장은 천천히 읽을수록 더 많은 계절을 보여 준다.",
             "넷째 줄: 우리는 서로의 이야기를 끝까지 들어줄 사람이 필요했다.",
             "다섯째 줄: 접힌 페이지를 펼치면 잊었던 하루가 돌아온다.",
             "여섯째 줄: 마지막 문장은 언제나 첫 문장을 닮아 있었다."]
let w = 1200, h = 1600
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
for (i, l) in lines.enumerated() {
    NSAttributedString(string: l, attributes: [.font: NSFont.systemFont(ofSize: 44), .foregroundColor: NSColor(white: 0.12, alpha: 1)])
        .draw(at: NSPoint(x: 80, y: CGFloat(h) - 260 - CGFloat(i) * 200))
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("ok")
