import AppKit

@main
enum SettingsAppearanceTests {
    static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480), styleMask: [.borderless], backing: .buffered, defer: false)
        defer { window.close() }
        let root = window.contentView!
        let backdrop = FrostedBackdropView()
        // A large raster must never impose its native pixel size on the window.
        backdrop.image = NSImage(size: NSSize(width: 4000, height: 3000))
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: root.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        root.layoutSubtreeIfNeeded()
        precondition(abs(root.frame.width - 640) < 1 && abs(root.frame.height - 480) < 1)
        precondition(abs(backdrop.frame.width - 640) < 1 && abs(backdrop.frame.height - 480) < 1)
        window.setContentSize(NSSize(width: 900, height: 640))
        root.layoutSubtreeIfNeeded()
        precondition(abs(backdrop.frame.width - 900) < 1 && abs(backdrop.frame.height - 640) < 1)
        print("Passed oversized backdrop window sizing and resize regression (offscreen AppKit).")
    }
}
