// Renders the DMG window background (660×400 pt) at 1x and 2x and combines them into
// background.tiff, which Finder picks the right resolution from.
//
//   swift scripts/dmg/make-background.swift      # from macApp/, rewrites scripts/dmg/background.tiff
//
// Icon centres used by make-dmg.sh: app at (165, 200), Applications at (495, 200).
import AppKit

let size = NSSize(width: 660, height: 400)
let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

let ink = NSColor(srgbRed: 0x0b / 255, green: 0x0b / 255, blue: 0x0f / 255, alpha: 1)
let body = NSColor(srgbRed: 0x55 / 255, green: 0x56 / 255, blue: 0x5f / 255, alpha: 1)
let brand = NSColor(srgbRed: 0x25 / 255, green: 0x63 / 255, blue: 0xeb / 255, alpha: 1)
let top = NSColor(srgbRed: 0xee / 255, green: 0xf3 / 255, blue: 0xff / 255, alpha: 1)
let bottom = NSColor.white

func draw() {
    NSGradient(starting: top, ending: bottom)!.draw(in: NSRect(origin: .zero, size: size), angle: -90)

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let title = NSAttributedString(string: "Drag Disk Clean AI into Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: ink, .paragraphStyle: para,
    ])
    title.draw(in: NSRect(x: 0, y: size.height - 62, width: size.width, height: 28))
    let subtitle = NSAttributedString(string: "Then open it from Launchpad, Spotlight or your Applications folder.", attributes: [
        .font: NSFont.systemFont(ofSize: 12.5), .foregroundColor: body, .paragraphStyle: para,
    ])
    subtitle.draw(in: NSRect(x: 0, y: size.height - 86, width: size.width, height: 20))

    // Arrow between the two icons (AppKit's origin is bottom-left; Finder's icon y=200 is from the top).
    let y = size.height - 200
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 262, y: y))
    shaft.line(to: NSPoint(x: 388, y: y))
    shaft.lineWidth = 5
    shaft.lineCapStyle = .round
    brand.withAlphaComponent(0.85).setStroke()
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 404, y: y))
    head.line(to: NSPoint(x: 382, y: y + 15))
    head.line(to: NSPoint(x: 382, y: y - 15))
    head.close()
    brand.withAlphaComponent(0.85).setFill()
    head.fill()
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size  // points, so the 2x rep is recognised as Retina
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let data = NSBitmapImageRep.tiffRepresentationOfImageReps(in: [render(scale: 1), render(scale: 2)],
                                                         using: .lzw, factor: 0)!
try data.write(to: dir.appendingPathComponent("background.tiff"))
print("wrote \(dir.appendingPathComponent("background.tiff").path)")
