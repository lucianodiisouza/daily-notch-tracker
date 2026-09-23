#!/usr/bin/env swift
//
// Composes the Mac App Store screenshots (2880 x 1800) from the app's own renders.
//
// 1. Render the app with demo data, once per language (Debug build):
//        DailyNotch.app/Contents/MacOS/DailyNotch -snapshot 1 -AppleLanguages '(en)'
//        DailyNotch.app/Contents/MacOS/DailyNotch -snapshot 1 -AppleLanguages '(pt-BR)'
//    and copy ~/Library/Containers/dev.oprimo.DailyNotch/Data/tmp/snapshots to appstore/screenshots/raw/<lang>
// 2. From the repo root:
//        swift appstore/screenshots/compose.swift            (App Store: appstore/screenshots/<lang>/*.png)
//        swift appstore/screenshots/compose.swift --readme   (README: docs/images/*.png, English, smaller)
//

import AppKit
import SwiftUI

let readme = CommandLine.arguments.contains("--readme")
let root = URL(fileURLWithPath: "appstore/screenshots")

struct Shot {
    let file: String
    let headline: [String: String]
    let caption: [String: String]
}

let shots: [Shot] = [
    Shot(file: "1-dashboard",
         headline: ["en": "Your day, in the notch", "pt-BR": "Seu dia, no notch"],
         caption: ["en": "Hover the notch for today's tasks and a month of focus.",
                   "pt-BR": "Passe o mouse no notch para ver as tarefas de hoje e um mês de foco."]),
    Shot(file: "2-focus",
         headline: ["en": "Focus without leaving your work", "pt-BR": "Foco sem sair do trabalho"],
         caption: ["en": "The countdown sits beside the camera while a line fills up around it.",
                   "pt-BR": "A contagem fica ao lado da câmera enquanto uma linha se preenche em volta."]),
    Shot(file: "3-tasks",
         headline: ["en": "Plan every day", "pt-BR": "Planeje cada dia"],
         caption: ["en": "A calendar, per-task focus lengths and your events, read-only.",
                   "pt-BR": "Calendário, duração de foco por tarefa e seus eventos, só leitura."]),
    Shot(file: "4-notch",
         headline: ["en": "Make the notch yours", "pt-BR": "Deixe o notch do seu jeito"],
         caption: ["en": "Standard or minimal, accent or RGB, on the screen you choose.",
                   "pt-BR": "Padrão ou mínimo, cor de destaque ou RGB, na tela que você escolher."]),
    Shot(file: "5-streak",
         headline: ["en": "Keep the streak going", "pt-BR": "Mantenha a sequência"],
         caption: ["en": "Today's focus time, finished blocks and days in a row.",
                   "pt-BR": "Tempo de foco de hoje, blocos concluídos e dias seguidos."]),
]

// MARK: - Pieces

let wallpaper = LinearGradient(
    colors: [Color(red: 0.13, green: 0.20, blue: 0.48), Color(red: 0.30, green: 0.13, blue: 0.52),
             Color(red: 0.06, green: 0.07, blue: 0.16)],
    startPoint: .topLeading, endPoint: .bottomTrailing)

func image(_ lang: String, _ name: String) -> NSImage {
    let url = root.appendingPathComponent("raw/\(lang)/\(name).png")
    guard let img = NSImage(contentsOf: url) else { fatalError("missing \(url.path)") }
    // The renders are 2x; size them in points.
    if let rep = img.representations.first {
        img.size = NSSize(width: CGFloat(rep.pixelsWide) / 2, height: CGFloat(rep.pixelsHigh) / 2)
    }
    return img
}

/// A macOS menu bar with the notch cut out in the middle.
struct MenuBar: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.28))
            HStack(spacing: 22) {
                Image(systemName: "apple.logo").font(.system(size: 17))
                Text("Finder").font(.system(size: 15, weight: .bold))
                ForEach(["File", "Edit", "View", "Go"], id: \.self) { Text($0).font(.system(size: 15)) }
                Spacer()
                Image(systemName: "hourglass").font(.system(size: 16))
                Image(systemName: "wifi").font(.system(size: 15))
                Image(systemName: "battery.75percent").font(.system(size: 17))
                Text("Tue 22 Sep  9:41").font(.system(size: 15))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
        }
        .frame(height: 38)
    }
}

/// A window render with the macOS window corner and shadow.
struct WindowFrame: View {
    let image: NSImage
    var scale: CGFloat = 1

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .frame(width: image.size.width * scale, height: image.size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 40, y: 20)
    }
}

struct Screen<Content: View>: View {
    let headline: String
    let caption: String
    /// Whether the content hangs from the menu bar (the notch shots) or floats as a window.
    var fromNotch = false
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            wallpaper
            MenuBar()
            if fromNotch {
                content.padding(.top, 0)
            }
            VStack(spacing: 14) {
                Text(headline)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text(caption)
                    .font(.system(size: 26, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, fromNotch ? 520 : 90)
            if !fromNotch {
                content.padding(.top, 280)
            }
        }
        .frame(width: 1440, height: 900)
        .clipped()
    }
}

// MARK: - Screens

@ViewBuilder
func screen(_ shot: Shot, lang: String) -> some View {
    let headline = shot.headline[lang]!
    let caption = shot.caption[lang]!
    switch shot.file {
    case "1-dashboard":
        let img = image(lang, "notch-expanded")
        Screen(headline: headline, caption: caption, fromNotch: true) {
            Image(nsImage: img).resizable()
                .frame(width: img.size.width * 1.45, height: img.size.height * 1.45)
                .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        }
    case "2-focus":
        let pill = image(lang, "notch-focus")
        let rgb = image(lang, "notch-focus-rgb")
        let minimal = image(lang, "notch-focus-minimal")
        ZStack(alignment: .top) {
            Screen(headline: headline, caption: caption, fromNotch: true) {
                Image(nsImage: pill).resizable()
                    .frame(width: pill.size.width * 1.8, height: pill.size.height * 1.8)
            }
            HStack(spacing: 60) {
                VStack(spacing: 14) {
                    Image(nsImage: minimal).resizable()
                        .frame(width: minimal.size.width * 1.6, height: minimal.size.height * 1.6)
                    Text(lang == "en" ? "Minimal" : "Mínimo").font(.system(size: 20, weight: .semibold))
                }
                VStack(spacing: 14) {
                    Image(nsImage: rgb).resizable()
                        .frame(width: rgb.size.width * 1.1, height: rgb.size.height * 1.1)
                    Text(lang == "en" ? "RGB line" : "Linha RGB").font(.system(size: 20, weight: .semibold))
                }
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.top, 700)
        }
    case "3-tasks":
        Screen(headline: headline, caption: caption) { WindowFrame(image: image(lang, "tasks"), scale: 1.05) }
    case "4-notch":
        Screen(headline: headline, caption: caption) {
            WindowFrame(image: image(lang, "settings-notch-dark"), scale: 0.95)
        }
    default:
        Screen(headline: headline, caption: caption) {
            WindowFrame(image: image(lang, "settings-focus-dark"), scale: 0.95)
        }
    }
}

@MainActor
func write<V: View>(_ view: V, scale: CGFloat, to url: URL) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let cg = renderer.cgImage else { fatalError("render failed: \(url.lastPathComponent)") }
    try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path)")
}

MainActor.assumeIsolated {
    if readme {
        let out = URL(fileURLWithPath: "docs/images")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for shot in shots {
            write(screen(shot, lang: "en"), scale: 1, to: out.appendingPathComponent("\(shot.file).png"))
        }
    } else {
        for lang in ["en", "pt-BR"] {
            let out = root.appendingPathComponent(lang)
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            for shot in shots {
                write(screen(shot, lang: lang), scale: 2, to: out.appendingPathComponent("\(shot.file).png"))
            }
        }
    }
}
