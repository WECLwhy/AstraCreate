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
check(defaults.groupNewFiles && defaults.language == .zh && defaults.enabled.values.allSatisfy { $0 }, "Missing settings defaults")
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
    check(settings.groupNewFiles && settings.language == .zh && settings.enabled.values.allSatisfy { $0 }, "Corrupt settings fallback")
}
print("Passed settings defaults, migration, round-trip, partial and corrupt configuration checks.")
