// QA 테스트 데이터용 표지 이미지 생성 — books.json의 제목·저자·색으로 360x540 PNG를 만든다.
// 사용: swift covers.swift books.json <출력 폴더>
import AppKit
let args = CommandLine.arguments
let data = try! Data(contentsOf: URL(fileURLWithPath: args[1]))
let json = try! JSONSerialization.jsonObject(with: data) as! [String: [[String: Any]]]
let outDir = args[2]
func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0; Scanner(string: String(hex.dropFirst())).scanHexInt64(&v)
    return NSColor(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
}
for (_, books) in json {
    for b in books {
        let w = 360, h = 540
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let cs = b["color"] as! [String]
        NSGradient(starting: color(cs[0]), ending: color(cs[1]))!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)
        NSColor.white.withAlphaComponent(0.85).setFill()
        NSRect(x: 28, y: h - 70, width: 60, height: 4).fill()
        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
        let title = NSAttributedString(string: b["title"] as! String, attributes: [.font: NSFont.boldSystemFont(ofSize: 34), .foregroundColor: NSColor.white, .paragraphStyle: para])
        title.draw(in: NSRect(x: 28, y: 150, width: w - 56, height: h - 240))
        let author = NSAttributedString(string: b["author"] as! String, attributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.white.withAlphaComponent(0.85)])
        author.draw(at: NSPoint(x: 28, y: 60))
        NSGraphicsContext.restoreGraphicsState()
        let png = rep.representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(b["isbn"] as! String).png"))
    }
}
print("ok")
