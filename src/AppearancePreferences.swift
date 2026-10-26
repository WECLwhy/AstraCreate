import Foundation
import CoreFoundation

enum AppearanceMode: String, Codable, CaseIterable {
    case system, light, dark
}

struct GlassPalette: Equatable {
    var transparency: Double
    var accentHex: String
    var tintHex: String

    static let light = GlassPalette(transparency: 40, accentHex: "#007AFF", tintHex: "#C9DFFF")
    static let dark = GlassPalette(transparency: 35, accentHex: "#409CFF", tintHex: "#26374D")

    static func color(_ value: Any?, fallback: String) -> String {
        guard let value = value as? String,
              value.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else { return fallback }
        return value.uppercased()
    }

    init(transparency: Double, accentHex: String, tintHex: String) {
        self.transparency = transparency.isFinite ? min(100, max(0, transparency)) : 40
        self.accentHex = Self.color(accentHex, fallback: Self.lightAccent)
        self.tintHex = Self.color(tintHex, fallback: "#C9DFFF")
    }

    private static let lightAccent = "#007AFF"

    init(object: Any?, fallback: GlassPalette) {
        let object = object as? [String: Any] ?? [:]
        // Bool is a JSON NSNumber too; it is never a valid percentage.
        let raw = object["transparency"] as? NSNumber
        let number = raw.flatMap { CFGetTypeID($0) == CFBooleanGetTypeID() ? nil : $0.doubleValue }
        transparency = number.map { $0.isFinite ? min(100, max(0, $0)) : fallback.transparency } ?? fallback.transparency
        accentHex = Self.color(object["accent"], fallback: fallback.accentHex)
        tintHex = Self.color(object["tint"], fallback: fallback.tintHex)
    }

    var object: [String: Any] {
        ["transparency": transparency, "accent": accentHex, "tint": tintHex]
    }
}

struct AppearancePreferences: Equatable {
    var mode: AppearanceMode = .system
    var light = GlassPalette.light
    var dark = GlassPalette.dark

    init() {}
    init(object: Any?) {
        let object = object as? [String: Any] ?? [:]
        mode = (object["mode"] as? String).flatMap(AppearanceMode.init(rawValue:)) ?? .system
        light = GlassPalette(object: object["light"], fallback: .light)
        dark = GlassPalette(object: object["dark"], fallback: .dark)
    }

    var object: [String: Any] {
        ["schema": 1, "mode": mode.rawValue, "light": light.object, "dark": dark.object]
    }
}
