import SwiftUI

/// Pen sketch beside a species-group title. Decorative. Not status.
struct GroupSketch: View {
    let groupId: String

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 28

    var body: some View {
        ZStack {
            SketchShape(groupId: groupId, eye: false)
                .stroke(style: StrokeStyle(lineWidth: max(1.35, size * 0.058), lineCap: .round, lineJoin: .round))
            SketchShape(groupId: groupId, eye: true)
                .fill()
        }
        .foregroundStyle(.primary)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct SketchShape: Shape {
    var groupId: String
    var eye: Bool

    func path(in rect: CGRect) -> Path {
        var pen = SketchPen(rect: rect)
        if eye {
            GroupInk.eye(groupId, pen: &pen)
        } else {
            GroupInk.strokes(groupId, pen: &pen)
        }
        return pen.path
    }
}

private struct SketchPen {
    var path = Path()
    let rect: CGRect
    private let inset: CGFloat = 0.04

    private var scaleX: CGFloat { rect.width * (1 - inset * 2) / 100 }
    private var scaleY: CGFloat { rect.height * (1 - inset * 2) / 100 }

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * (inset + x / 100 * (1 - inset * 2)),
            y: rect.minY + rect.height * (inset + y / 100 * (1 - inset * 2))
        )
    }

    mutating func move(_ x: CGFloat, _ y: CGFloat) { path.move(to: pt(x, y)) }
    mutating func line(_ x: CGFloat, _ y: CGFloat) { path.addLine(to: pt(x, y)) }

    mutating func curve(
        _ c1x: CGFloat, _ c1y: CGFloat,
        _ c2x: CGFloat, _ c2y: CGFloat,
        _ x: CGFloat, _ y: CGFloat
    ) {
        path.addCurve(to: pt(x, y), control1: pt(c1x, c1y), control2: pt(c2x, c2y))
    }

    mutating func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 4.2) {
        let c = pt(x, y)
        let rx = r * scaleX
        let ry = r * scaleY
        path.addEllipse(in: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }
}

/// Paths are drawn in a 0...100 box, origin top-left.
private enum GroupInk {
    static func strokes(_ id: String, pen: inout SketchPen) {
        switch id {
        case "klovbaerende": stag(&pen)
        case "rovdyr": fox(&pen)
        case "ovrige_pattedyr": hare(&pen)
        case "andefugle": duck(&pen)
        case "gaes": goose(&pen)
        case "honsefugle": pheasant(&pen)
        case "ovrige_fugle": bird(&pen)
        default: pen.dot(50, 50, 18)
        }
    }

    static func eye(_ id: String, pen: inout SketchPen) {
        switch id {
        case "klovbaerende": pen.dot(68, 60)
        case "rovdyr": pen.dot(58, 52)
        case "ovrige_pattedyr": pen.dot(62, 58)
        case "andefugle": pen.dot(78, 42)
        case "gaes": pen.dot(66, 18)
        case "honsefugle": pen.dot(84, 50)
        case "ovrige_fugle": pen.dot(72, 48)
        default: break
        }
    }

    /// Red-deer head with antlers.
    private static func stag(_ pen: inout SketchPen) {
        pen.move(44, 48)
        pen.curve(36, 30, 28, 18, 22, 6)
        pen.move(36, 32)
        pen.line(16, 22)
        pen.move(30, 18)
        pen.line(12, 8)
        pen.move(54, 44)
        pen.curve(64, 26, 70, 14, 78, 4)
        pen.move(62, 28)
        pen.line(80, 18)
        pen.move(70, 14)
        pen.line(86, 6)
        pen.move(40, 50)
        pen.curve(28, 48, 22, 60, 26, 66)
        pen.curve(32, 64, 38, 58, 42, 54)
        pen.move(42, 54)
        pen.curve(54, 40, 70, 46, 80, 54)
        pen.curve(90, 58, 94, 64, 92, 70)
        pen.curve(86, 78, 68, 80, 52, 72)
        pen.curve(42, 66, 36, 60, 42, 54)
        pen.move(50, 74)
        pen.curve(42, 84, 32, 92, 22, 98)
    }

    /// Pointed ears on the skull, long snout.
    private static func fox(_ pen: inout SketchPen) {
        pen.move(20, 48)
        pen.line(12, 14)
        pen.line(32, 42)
        pen.line(40, 40)
        pen.line(48, 10)
        pen.line(62, 38)
        pen.curve(76, 42, 88, 50, 96, 60)
        pen.line(94, 68)
        pen.line(78, 70)
        pen.curve(58, 76, 34, 72, 22, 60)
        pen.curve(14, 52, 14, 48, 20, 48)
        pen.move(84, 64)
        pen.line(68, 62)
    }

    /// Long ears. That is the hare.
    private static func hare(_ pen: inout SketchPen) {
        pen.move(32, 50)
        pen.curve(28, 28, 34, 8, 38, 8)
        pen.curve(44, 18, 44, 36, 44, 50)
        pen.move(50, 50)
        pen.curve(52, 26, 58, 6, 64, 6)
        pen.curve(70, 18, 64, 36, 62, 50)
        pen.move(30, 54)
        pen.curve(26, 68, 40, 76, 54, 74)
        pen.curve(70, 72, 80, 62, 76, 52)
        pen.curve(70, 44, 50, 44, 36, 50)
        pen.move(36, 72)
        pen.curve(20, 80, 22, 96, 42, 98)
        pen.curve(64, 100, 82, 90, 74, 74)
    }

    /// Flat bill and a line of water.
    private static func duck(_ pen: inout SketchPen) {
        pen.move(20, 60)
        pen.curve(16, 46, 34, 44, 50, 48)
        pen.curve(64, 44, 72, 52, 70, 58)
        pen.curve(84, 62, 82, 74, 66, 78)
        pen.curve(44, 84, 18, 76, 20, 62)
        pen.move(20, 56)
        pen.line(8, 48)
        pen.line(12, 60)
        pen.move(64, 52)
        pen.curve(62, 36, 76, 32, 84, 38)
        pen.curve(92, 44, 90, 56, 74, 56)
        pen.move(82, 42)
        pen.line(98, 46)
        pen.line(82, 50)
        pen.move(32, 60)
        pen.curve(44, 68, 58, 66, 68, 58)
        pen.move(8, 90)
        pen.curve(24, 82, 40, 90, 56, 98)
        pen.curve(72, 90, 88, 82, 98, 90)
    }

    /// The long neck is the goose.
    private static func goose(_ pen: inout SketchPen) {
        pen.move(16, 70)
        pen.curve(14, 56, 34, 54, 50, 58)
        pen.curve(66, 54, 76, 66, 72, 76)
        pen.curve(64, 88, 34, 92, 18, 80)
        pen.curve(10, 74, 12, 72, 16, 70)
        pen.move(48, 62)
        pen.curve(42, 42, 46, 24, 54, 16)
        pen.curve(60, 10, 72, 10, 74, 20)
        pen.line(92, 24)
        pen.line(74, 28)
        pen.curve(66, 32, 58, 30, 54, 38)
        pen.curve(50, 48, 52, 56, 54, 62)
        pen.move(18, 64)
        pen.line(6, 54)
    }

    /// Long straight tail. That is the pheasant, even at list size.
    private static func pheasant(_ pen: inout SketchPen) {
        pen.move(48, 52)
        pen.line(2, 64)
        pen.move(48, 60)
        pen.line(4, 78)
        pen.move(46, 48)
        pen.curve(62, 42, 74, 48, 76, 58)
        pen.curve(78, 68, 64, 74, 50, 70)
        pen.curve(38, 66, 38, 56, 46, 48)
        pen.move(72, 54)
        pen.curve(76, 42, 90, 42, 92, 52)
        pen.curve(94, 60, 84, 64, 74, 56)
        pen.move(84, 44)
        pen.line(88, 32)
        pen.move(92, 50)
        pen.line(100, 52)
    }

    /// Short beak, cocked tail. Not a duck, goose, or pheasant.
    private static func bird(_ pen: inout SketchPen) {
        pen.move(28, 62)
        pen.curve(24, 48, 42, 44, 56, 50)
        pen.curve(68, 46, 74, 56, 70, 66)
        pen.curve(64, 78, 42, 82, 28, 72)
        pen.curve(20, 66, 22, 64, 28, 60)
        pen.move(60, 54)
        pen.curve(62, 40, 74, 38, 80, 46)
        pen.curve(86, 54, 80, 64, 66, 60)
        pen.move(80, 48)
        pen.line(94, 50)
        pen.line(80, 54)
        pen.move(28, 58)
        pen.line(10, 42)
        pen.move(30, 64)
        pen.line(14, 54)
        pen.move(36, 60)
        pen.curve(48, 68, 60, 66, 68, 58)
    }
}
