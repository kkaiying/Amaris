//
//  Decorations.swift
//  Amaris
//
//  Little drawn details for the themes, all vector so they stay crisp.
//  Once Upon a Broken Heart: sparkles, hearts, washi tape, gingham, scallops,
//  an ink circle, a wax seal, an apple, a postage stamp.
//  Alchemy: transmutation circles, alchemical glyphs, an arched window.
//

import SwiftUI

// MARK: - Shapes

/// Four-pointed sparkle.
struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width / 2, h = rect.height / 2
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: c.y), control: CGPoint(x: c.x + w * 0.16, y: c.y - h * 0.16))
        p.addQuadCurve(to: CGPoint(x: c.x, y: rect.maxY), control: CGPoint(x: c.x + w * 0.16, y: c.y + h * 0.16))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: c.y), control: CGPoint(x: c.x - w * 0.16, y: c.y + h * 0.16))
        p.addQuadCurve(to: CGPoint(x: c.x, y: rect.minY), control: CGPoint(x: c.x - w * 0.16, y: c.y - h * 0.16))
        p.closeSubpath()
        return p
    }
}

struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.95))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.32),
                   control1: CGPoint(x: rect.minX + w * 0.2, y: rect.minY + h * 0.75),
                   control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.55))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.18),
                   control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.02),
                   control2: CGPoint(x: rect.minX + w * 0.38, y: rect.minY - h * 0.02))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.32),
                   control1: CGPoint(x: rect.minX + w * 0.62, y: rect.minY - h * 0.02),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.02))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.95),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.55),
                   control2: CGPoint(x: rect.minX + w * 0.8, y: rect.minY + h * 0.75))
        p.closeSubpath()
        return p
    }
}

/// A loose, hand-drawn ring that doesn't quite close, like a pen circle.
struct InkCircle: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 66, y: rect.minY + rect.height * y / 76)
        }
        var p = Path()
        p.move(to: pt(35, 4))
        p.addCurve(to: pt(5, 39), control1: pt(15, 2), control2: pt(4, 18))
        p.addCurve(to: pt(36, 72), control1: pt(6, 61), control2: pt(19, 73))
        p.addCurve(to: pt(61, 36), control1: pt(54, 71), control2: pt(62, 55))
        p.addCurve(to: pt(30, 7), control1: pt(60, 16), control2: pt(48, 5))
        return p
    }
}

/// A row of half circles hanging down, for the edge under a header band.
struct ScallopEdge: Shape {
    var scallopWidth: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let count = Int(ceil(rect.width / scallopWidth))
        let r = scallopWidth / 2
        for i in 0..<count {
            let center = CGPoint(x: rect.minX + CGFloat(i) * scallopWidth + r, y: rect.minY)
            p.addArc(center: center, radius: min(r, rect.height), startAngle: .zero, endAngle: .degrees(180), clockwise: false)
        }
        return p
    }
}

/// A gentle wave, for underlining a handwritten line.
struct Squiggle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let waves = max(Int(rect.width / 24), 1)
        let step = rect.width / CGFloat(waves)
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for i in 0..<waves {
            let x0 = rect.minX + CGFloat(i) * step
            p.addCurve(to: CGPoint(x: x0 + step, y: rect.midY),
                       control1: CGPoint(x: x0 + step * 0.33, y: rect.minY),
                       control2: CGPoint(x: x0 + step * 0.66, y: rect.maxY))
        }
        return p
    }
}

/// Circles and triangles in the style of an alchemical array.
struct TransmutationCircle: Shape {
    enum Variant { case calendar, quote, year }
    var variant: Variant = .calendar

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 200
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: rect.minX + (cx - r) * s, y: rect.minY + (cy - r) * s, width: 2 * r * s, height: 2 * r * s))
        }
        func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
            var p = Path(); p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath(); return p
        }

        var p = Path()
        switch variant {
        case .calendar:
            p.addPath(circle(100, 100, 96)); p.addPath(circle(100, 100, 88)); p.addPath(circle(100, 100, 56))
            p.addPath(triangle(pt(100, 12), pt(176, 144), pt(24, 144)))
            p.addPath(triangle(pt(100, 188), pt(24, 56), pt(176, 56)))
            p.addPath(circle(100, 12, 7)); p.addPath(circle(176, 144, 7)); p.addPath(circle(24, 144, 7))
            p.addPath(circle(100, 100, 18))
            p.move(to: pt(100, 82)); p.addLine(to: pt(100, 118))
            p.move(to: pt(82, 100)); p.addLine(to: pt(118, 100))
        case .quote:
            p.addPath(circle(100, 100, 96)); p.addPath(circle(100, 100, 80))
            p.addPath(triangle(pt(100, 20), pt(169, 140), pt(31, 140)))
            p.addPath(circle(100, 100, 40))
            p.move(to: pt(100, 20)); p.addLine(to: pt(100, 180))
            p.move(to: pt(31, 140)); p.addLine(to: pt(169, 60))
            p.move(to: pt(169, 140)); p.addLine(to: pt(31, 60))
        case .year:
            p.addPath(circle(100, 100, 94))
            p.addPath(triangle(pt(100, 6), pt(181, 147), pt(19, 147)))
            p.addPath(triangle(pt(100, 194), pt(19, 53), pt(181, 53)))
        }
        return p
    }
}

/// The alchemical sign for air: a triangle with a bar.
struct AirGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.62))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.62))
        return p
    }
}

// MARK: - Views

/// The alchemical sun: a ring with a dot.
struct SunGlyph: View {
    var color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 1.4)
            Circle().fill(color).scaleEffect(0.2)
        }
    }
}

/// A strip of striped pink tape, slightly see-through.
struct WashiTape: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFAC8D7, opacity: 0.88)))
            let stripe: CGFloat = 6
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + stripe, y: 0))
                p.addLine(to: CGPoint(x: x + stripe, y: size.height))
                p.closeSubpath()
                context.fill(p, with: .color(Color(hex: 0xF096B4, opacity: 0.85)))
                x += stripe * 2
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }
}

/// Pink-and-cream gingham.
struct Gingham: View {
    var color: Color = Color(hex: 0xE46F95)
    var base: Color = Color(hex: 0xF8DAE3)
    var square: CGFloat = 9

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            let tint = GraphicsContext.Shading.color(color.opacity(0.16))
            var i: CGFloat = 0
            while i < max(size.width, size.height) {
                context.fill(Path(CGRect(x: i, y: 0, width: square, height: size.height)), with: tint)
                context.fill(Path(CGRect(x: 0, y: i, width: size.width, height: square)), with: tint)
                i += square * 2
            }
        }
    }
}

/// White dots on a pink ground.
struct PolkaDots: View {
    var base: Color
    var spacing: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)),
                                 with: .color(.white.opacity(0.55)))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

/// A heart pressed into a pink wax seal.
struct WaxSeal: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xC2416B))
                .overlay(Circle().strokeBorder(Color(hex: 0xA6305A), lineWidth: 1.5).padding(3))
            Heart().fill(Color(hex: 0xA6305A)).padding(8)
        }
        .shadow(color: Color(hex: 0x6A1F3A).opacity(0.3), radius: 1, y: 1)
    }
}

/// A red apple with a leaf (Jacks would approve).
struct AppleDoodle: View {
    var body: some View {
        ZStack(alignment: .top) {
            Heart()
                .fill(Color(hex: 0xE2445F))
                .rotationEffect(.degrees(180))
                .scaleEffect(x: 1, y: 0.95)
                .padding(.top, 4)
            Capsule().fill(Color(hex: 0x7A4B2C)).frame(width: 1.8, height: 6).rotationEffect(.degrees(20)).offset(x: 1)
            Ellipse().fill(Color(hex: 0x6AA36F)).frame(width: 7, height: 3.5).rotationEffect(.degrees(-25)).offset(x: 5, y: 1)
        }
    }
}

/// A cover mounted like a postage stamp: white margin and a perforated edge.
struct PostageStamp<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(5)
            .background(.white)
            .overlay(
                Rectangle().strokeBorder(Color(hex: 0xEAD8DC),
                                         style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [0.1, 6]))
            )
            .shadow(color: Color(hex: 0x3C1423).opacity(0.2), radius: 4, y: 3)
    }
}

/// A round postmark with wavy cancellation lines.
struct Postmark: View {
    var color: Color

    var body: some View {
        HStack(spacing: 2) {
            Circle().stroke(color, lineWidth: 1.3).frame(width: 24, height: 24)
            VStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in Squiggle().stroke(color, lineWidth: 1.3).frame(width: 24, height: 4) }
            }
        }
    }
}

/// An arch-topped window frame in gold, for a cover.
struct ArchFrame<Content: View>: View {
    var color: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 200, bottomLeadingRadius: 2,
                                              bottomTrailingRadius: 2, topTrailingRadius: 200))
            .padding(4)
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 200, bottomLeadingRadius: 3,
                                       bottomTrailingRadius: 3, topTrailingRadius: 200)
                    .stroke(color, lineWidth: 1)
            )
    }
}
