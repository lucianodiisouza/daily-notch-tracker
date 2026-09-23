#!/usr/bin/env swift
//
// Draws the DailyNotch app icon and writes every size macOS asks for: a night-blue squircle with the black notch
// hanging from its top edge, the blue focus line running around it, and the month's activity grid below.
//
// Run from the repo root:
//     swift scripts/generate-icon.swift
//
// Output: DailyNotch/Assets.xcassets/AppIcon.appiconset
//

import AppKit
import SwiftUI

private let blue = Color(red: 0.23, green: 0.51, blue: 0.96)
private let lightBlue = Color(red: 0.45, green: 0.70, blue: 1.0)

/// Open-top frame hugging the notch's sides and bottom, like the app's progress tray.
private struct Tray: Shape {
    var corner: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        p.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - corner), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct Notch: Shape {
    var corner: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - corner, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - corner), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct Icon: View {
    /// Activity levels for the grid, 0 (empty) to 4 (busiest), four weeks of five days.
    private let levels: [[Int]] = [
        [1, 3, 0, 2, 4],
        [2, 4, 3, 1, 3],
        [0, 2, 4, 3, 4],
        [3, 4, 2, 4, 1],
    ]

    var body: some View {
        // macOS icons sit on a 1024 canvas with an 824 body, leaving room for the shadow.
        ZStack {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.10, green: 0.13, blue: 0.24), Color(red: 0.03, green: 0.04, blue: 0.09)],
                        startPoint: .top, endPoint: .bottom))

                // The notch, hanging from the top edge, with the focus line around it three quarters full.
                ZStack(alignment: .top) {
                    Notch(corner: 64)
                        .fill(Color.black)
                        .frame(width: 430, height: 168)
                    Tray(corner: 44)
                        .stroke(blue.opacity(0.28), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                        .frame(width: 370, height: 128)
                        .offset(y: 8)
                    Tray(corner: 44)
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            LinearGradient(colors: [lightBlue, blue], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round))
                        .frame(width: 370, height: 128)
                        .offset(y: 8)
                        .shadow(color: blue.opacity(0.9), radius: 18)
                }

                // The activity grid.
                VStack(spacing: 22) {
                    ForEach(0..<levels.count, id: \.self) { row in
                        HStack(spacing: 22) {
                            ForEach(0..<levels[row].count, id: \.self) { col in
                                let level = levels[row][col]
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(level == 0 ? Color.white.opacity(0.08) : blue.opacity(0.25 + Double(level) * 0.1875))
                                    .frame(width: 84, height: 84)
                            }
                        }
                    }
                }
                .padding(.top, 262)
            }
            .frame(width: 824, height: 824)
            .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
private func render(size: Int, to url: URL) {
    let renderer = ImageRenderer(content: Icon().frame(width: 1024, height: 1024))
    renderer.scale = CGFloat(size) / 1024
    guard let image = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let folder = URL(fileURLWithPath: "DailyNotch/Assets.xcassets/AppIcon.appiconset")
let files: [(String, Int)] = [
    ("icon_16.png", 16), ("icon_32.png", 32), ("icon_32@2x.png", 64),
    ("icon_128.png", 128), ("icon_128@2x.png", 256), ("icon_256.png", 256),
    ("icon_256@2x.png", 512), ("icon_512.png", 512), ("icon_512@2x.png", 1024),
]
MainActor.assumeIsolated {
    for (name, size) in files {
        render(size: size, to: folder.appendingPathComponent(name))
    }
}
print("Wrote \(files.count) icons to \(folder.path)")
