import AppKit

extension AppearancePreferences {
    var applicationAppearance: NSAppearance? {
        switch mode {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
    func palette(for appearance: NSAppearance) -> GlassPalette {
        let isDark = mode == .dark || (mode == .system && appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        return isDark ? dark : light
    }
}

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x007AFF
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
    }
    var rgbHex: String? {
        guard let color = usingColorSpace(.sRGB) else { return nil }
        func byte(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(color.redComponent), byte(color.greenComponent), byte(color.blueComponent))
    }
}

/// Quiet generated material underneath the native blur, so a plain desktop
/// does not flatten the glass. Hidden when Reduce Transparency is enabled.
final class FrostedBackdropView: NSImageView {
    var preferences = AppearancePreferences() { didSet { updateMaterial(); needsDisplay = true } }
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
    init() {
        super.init(frame: .zero)
        image = Bundle.main.url(forResource: "FrostedBackdrop", withExtension: "png").flatMap(NSImage.init(contentsOf:))
        imageScaling = .scaleAxesIndependently
        setAccessibilityElement(false)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateMaterial), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        updateMaterial()
    }
    required init?(coder: NSCoder) { nil }
    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateMaterial()
    }
    @objc private func updateMaterial() {
        isHidden = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let palette = preferences.palette(for: effectiveAppearance)
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        alphaValue = (isDark ? 0.08 : 0.7) * (0.35 + palette.transparency / 100)
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.fromHex(preferences.palette(for: effectiveAppearance).tintHex).withAlphaComponent(0.22).setFill()
        dirtyRect.fill(using: .sourceAtop)
    }
}

/// Native materials follow the system appearance and Reduce Transparency setting.
final class FrostedPanelView: NSVisualEffectView {
    var preferences = AppearancePreferences() { didSet { updateColors() } }
    init(material: NSVisualEffectView.Material = .popover, cornerRadius: CGFloat = 14) {
        super.init(frame: .zero)
        self.material = material
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = cornerRadius == 0 ? 0 : 0.5
        updateColors()
    }

    required init?(coder: NSCoder) { nil }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let palette = preferences.palette(for: effectiveAppearance)
            let tint = NSColor.fromHex(palette.tintHex)
            let base = NSColor.textBackgroundColor.blended(withFraction: 0.1, of: tint) ?? .textBackgroundColor
            let opacity = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 1 - palette.transparency / 100
            layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
            layer?.backgroundColor = base.withAlphaComponent(opacity).cgColor
        }
    }
}

final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class SettingsNavigationCell: NSButtonCell {
    override func imageRect(forBounds rect: NSRect) -> NSRect {
        NSRect(x: rect.minX + 12, y: rect.midY - 9, width: 18, height: 18)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let title = super.titleRect(forBounds: rect)
        return NSRect(x: rect.minX + 42, y: title.minY, width: max(0, rect.width - 54), height: title.height)
    }
}

final class SettingsNavigationButton: NSButton {
    var preferences = AppearancePreferences() { didSet { needsLayout = true } }
    var selected = false { didSet { needsDisplay = true; needsLayout = true } }

    init(symbol: String, tag: Int) {
        super.init(frame: .zero)
        cell = SettingsNavigationCell(textCell: "")
        self.tag = tag
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        imagePosition = .imageLeading
        alignment = .left
        isBordered = false
        font = .systemFont(ofSize: 14, weight: .medium)
        wantsLayer = true
        layer?.cornerRadius = 9
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        let accent = NSColor.fromHex(preferences.palette(for: effectiveAppearance).accentHex)
        contentTintColor = selected ? accent : .secondaryLabelColor
        layer?.backgroundColor = selected ? accent.withAlphaComponent(0.13).cgColor : NSColor.clear.cgColor
        setAccessibilityValue(selected ? 1 : 0)
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }
}
