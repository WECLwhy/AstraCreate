// App settings implementation is prepended by scripts/test.sh.
let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let testURL = scratch.appendingPathComponent("nested/settings.json")
defer { try? FileManager.default.removeItem(at: scratch) }
func check(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
}
func fixture(_ text: String) throws {
    try FileManager.default.createDirectory(at: testURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: testURL)
}
private let defaults = loadSettings(from: testURL)
check(defaults.groupNewFiles && defaults.language == .zh && defaults.enabled == defaultEnabledFeatures(), "Missing settings defaults")
try fixture(#"{"enabled":{"docx":false,"txt":true},"language":"en"}"#)
private let legacy = loadSettings(from: testURL)
check(legacy.groupNewFiles && legacy.language == .en && legacy.enabled["docx"] == false && legacy.enabled["xlsx"] == true, "Legacy settings migration")
for grouped in [true, false] {
    for language in [AppLanguage.zh, .en] {
        var settings = legacy
        settings.groupNewFiles = grouped
        settings.language = language
        try saveSettings(settings, to: testURL)
        let restored = loadSettings(from: testURL)
        check(restored.groupNewFiles == grouped && restored.language == language && restored.enabled == legacy.enabled, "Settings round-trip")
    }
}
try fixture(#"{"groupNewFiles":false,"language":"en"}"#)
check(!loadSettings(from: testURL).groupNewFiles && loadSettings(from: testURL).language == .en, "Partial settings")
for corrupt in ["broken JSON", "[]", #"{"enabled":null,"groupNewFiles":null,"language":42}"#] {
    try fixture(corrupt)
    let settings = loadSettings(from: testURL)
    check(settings.groupNewFiles && settings.language == .zh && settings.enabled == defaultEnabledFeatures(), "Corrupt settings fallback")
}
print("Passed settings defaults, migration, round-trip, partial and corrupt configuration checks.")

private var appearanceSettings = legacy
appearanceSettings.appearance.mode = .dark
appearanceSettings.appearance.light = GlassPalette(transparency: 8, accentHex: "#AABBCC", tintHex: "#CCDDEE")
appearanceSettings.appearance.dark = GlassPalette(transparency: 82, accentHex: "#BB11EE", tintHex: "#112233")
try saveSettings(appearanceSettings, to: testURL)
private let appearanceRestored = loadSettings(from: testURL)
check(appearanceRestored.appearance == appearanceSettings.appearance && appearanceRestored.enabled == legacy.enabled, "Appearance persistence must preserve feature preferences")
try fixture(##"{"appearance":{"mode":"dark","light":{"transparency":200,"accent":"#aabbcc","tint":"not-a-color"},"dark":{"transparency":true,"accent":"file:///private","tint":"#112233"}}}"##)
private let clampedAppearance = loadSettings(from: testURL).appearance
check(clampedAppearance.mode == .dark && clampedAppearance.light.transparency == 100 && clampedAppearance.light.accentHex == "#AABBCC", "Appearance normalization")
check(clampedAppearance.light.tintHex == GlassPalette.light.tintHex && clampedAppearance.dark.transparency == GlassPalette.dark.transparency && clampedAppearance.dark.accentHex == GlassPalette.dark.accentHex, "Invalid colors and Bool percentage must fall back")
try fixture(#"{"appearance":{"mode":"future","light":[],"dark":{"transparency":-9}}}"#)
check(loadSettings(from: testURL).appearance.mode == .system && loadSettings(from: testURL).appearance.dark.transparency == 0, "Unknown appearance and negative percentage")
print("Passed independent light/dark appearance persistence, legacy defaults and invalid-value handling.")

check(SourceFileKind.allCases.allSatisfy { defaults.enabled[$0.rawValue] == false && legacy.enabled[$0.rawValue] == false }, "New formats must be opt-in for new and legacy users")
check(defaults.enabled["pdf"] == nil, "PDF must not be offered")
private var developerSettings = legacy
for (index, kind) in SourceFileKind.allCases.enumerated() { developerSettings.enabled[kind.rawValue] = index % 2 == 0 }
try saveSettings(developerSettings, to: testURL)
private let developerRestored = loadSettings(from: testURL)
check(developerRestored.enabled == developerSettings.enabled, "Each developer format must persist independently without changing existing preferences")
print("Passed opt-in developer formats and independent settings persistence; PDF excluded.")
