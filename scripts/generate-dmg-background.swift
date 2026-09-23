#!/usr/bin/env swift
//
// Draws the DMG window background: the night-blue of the app icon, the notch with its focus line on top, and an arrow
// from the app to the Applications folder. Writes a HiDPI TIFF (1x + 2x) for create-dmg.
//
// Run from the repo root:
//     swift scripts/generate-dmg-background.swift
//
// Output: scripts/dmg/background.tiff (the window is 640 x 400; icons sit at x 160 and 480, y 205)
//

import AppKit
import SwiftUI

private let blue = Color(red: 0.23, green: 0.51, blue: 0.96)

private struct Tray: Shape {
    func path(in rect: CGRect) -> Path {
        let c: CGFloat = 12
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addQuadCurve(to: CGPoint(x: rect.minX + c, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - c), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct Background: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.24), Color(red: 0.03, green: 0.04, blue: 0.09)],
                startPoint: .top, endPoint: .bottom)
            // The notch with its focus line.
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
                    .fill(Color.black)
                    .frame(width: 150, height: 44)
                Tray().stroke(blue.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 134, height: 34)
                Tray().trim(from: 0, to: 0.7)
                    .stroke(blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 134, height: 34)
                    .shadow(color: blue, radius: 6)
            }
            // Arrow between the two icons.
            Image(systemName: "arrow.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .offset(y: 186)
            Text("Drag DailyNotch to Applications")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .offset(y: 318)
        }
        .frame(width: 640, height: 400)
    }
}

@MainActor
private func image(scale: CGFloat) -> NSBitmapImageRep {
    let renderer = ImageRenderer(content: Background())
    renderer.scale = scale
    let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
    rep.size = NSSize(width: 640, height: 400)
    return rep
}

MainActor.assumeIsolated {
    let out = URL(fileURLWithPath: "scripts/dmg/background.tiff")
    let data = NSBitmapImageRep.tiffRepresentationOfImageReps(in: [image(scale: 1), image(scale: 2)],
                                                              using: .lzw, factor: 0)!
    try! data.write(to: out)
    print("Wrote \(out.path)")
}
