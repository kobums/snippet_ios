// 스크린샷 모아보기 이미지(contact sheet) 생성.
// 사용: swift sheet.swift <out.png> <thumbWidth> <columns> <img1> <img2> ...
import AppKit
let a = CommandLine.arguments
let out = a[1], tw = CGFloat(Double(a[2])!), cols = Int(a[3])!
let paths = Array(a[4...])
let imgs = paths.compactMap { NSImage(contentsOfFile: $0) }
let labelH: CGFloat = 22, pad: CGFloat = 8
let thumbs = imgs.map { img -> (NSImage, CGSize) in
    let s = img.size; let h = tw * s.height / s.width; return (img, CGSize(width: tw, height: h))
}
let rows = Int(ceil(Double(thumbs.count) / Double(cols)))
var rowH = [CGFloat](repeating: 0, count: rows)
for (i, t) in thumbs.enumerated() { rowH[i / cols] = max(rowH[i / cols], t.1.height) }
let W = CGFloat(cols) * (tw + pad) + pad
let H = rowH.reduce(0) { $0 + $1 + labelH + pad } + pad
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.85, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
var yTop = H - pad
for r in 0..<rows {
    for c in 0..<cols {
        let i = r * cols + c; if i >= thumbs.count { break }
        let (img, sz) = thumbs[i]
        let x = pad + CGFloat(c) * (tw + pad)
        let name = (paths[i] as NSString).lastPathComponent.replacingOccurrences(of: ".png", with: "")
        NSAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.black]).draw(at: NSPoint(x: x, y: yTop - 16))
        img.draw(in: NSRect(x: x, y: yTop - labelH - sz.height, width: sz.width, height: sz.height))
    }
    yTop -= rowH[r] + labelH + pad
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out) \(Int(W))x\(Int(H))")
