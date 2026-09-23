// swift-tools-version: 5.9
// 点译 · eDrop — macOS menu bar app (0.3.17, PRD v0.3)
// Bundle ID: app.eyedrop.translate
//
// On a Mac with Xcode:
//   open eDrop.xcodeproj   ← preferred for LSUIElement menu bar
//   or: open Package.swift
//
// Build / run (Mac only):
//   swift build && swift run eDrop
//
// Note: Info.plist + entitlements + Assets live in Resources/ for the Xcode app target.
// SPM executable builds do not embed them automatically.
// Default engine: MyMemory → Google → Lingva → Mock（Sources 下 GoogleTranslateService.swift 已纳入）。
// Sources path remains Sources/EyedropTranslate to limit churn; product name is eDrop.

import PackageDescription

let package = Package(
    name: "eDrop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "eDrop",
            targets: ["EyedropTranslate"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EyedropTranslate",
            path: "Sources/EyedropTranslate",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)
