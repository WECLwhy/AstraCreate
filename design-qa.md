# Native AppKit design QA

**Scope and final result**
Native settings design and core settings interactions on this host only. Finder installation/loading and macOS 15.0.1 acceptance remain pending.

final result: passed

**Evidence**
- Source visual truth: local-review/outputs/AstraCreate-磨砂玻璃修订稿.png
- Final light implementation: local-review/outputs/AstraCreate-原生界面-浅色.png
- Final dark implementation: local-review/outputs/AstraCreate-原生界面-深色.png
- Full-view combined input: local-review/work/ui-redesign/comparison-final.png
- Focused combined input (brand/navigation and file rows): local-review/work/ui-redesign/comparison-final-focus.png
- Both combined inputs were opened after the material/icon fixes. These are comparison contact sheets, not edited app assets.
- Source 1374×1145 raster; native capture 2080×1546 raster, approximately 1040×773 points at 2x. Requested content size 1040×840, minimum frame 900×680; host capture excludes/adjusts window chrome. CSS viewport/deviceScaleFactor: not applicable to AppKit.
- Density normalization: aspect-preserving copies at max width 1100 / height 950, source desktop padding and capture chrome cropped; no stretching or pixel-exact matching claim across these different native frames.
- State: General, Chinese, all independent switches on; light and dark appearances inspected. Support and English inspected in the same isolated native preview.

**Comparison history**
1. [P2, fixed] Initial content could start part-way down. Reset scroll after localization/layout and navigation; fresh capture/AX state shows scroll position 0.
2. [P2, fixed] Card edges were too heavy and row gaps too large. Reduced semantic border alpha to 0.08, restored native effect rendering, tightened card spacing and row height; post-fix light/dark captures show subtle separated groups.
3. [P2, fixed] Language controls were below the scroll viewport. Moved them to the persistent sidebar footer; fresh capture and real language clicks confirm availability.
4. [P1, fixed] Plain desktop flattened the materials compared with the blue-white reference. Added a generated quiet frosted backdrop under real NSVisualEffectView blur. It is hidden for Reduce Transparency and reduced to 0.06 alpha in dark mode. Final combined input shows cool material depth without reducing text contrast.
5. [P2, fixed] Brand icon too small. Increased image view from 112 to 160 points and adjusted sidebar spacing. Final focused comparison shows the paper/sparkle silhouette clearly.
6. [P1, fixed] The backdrop image initially imposed its raster dimensions on window layout. Removed intrinsic size from the decorative view; final capture returned to 2080×1546. Offscreen regression verifies an oversized 4000×3000 image fits 640×480 and resizes to 900×640.

**Required fidelity surfaces**
- Fonts/typography: native system type, 27 pt brand, 16 pt panel titles, 13 pt controls, 11–12 pt secondary text. Chinese/English readable without overlaps; long secondary details may truncate before primary labels. Native sizes intentionally replace image-generated typography.
- Spacing/layout: selected sidebar style (now three destinations) and grouped menu/files/actions hierarchy preserved; persistent footer and scrollable content adapt to smaller native windows. Language placement intentionally improves availability relative to the mock.
- Colors/tokens: semantic label/background colors and user-selected sidebar accent; native materials with subtle generated blue-white substrate. Dark appearance remains dark and legible. Native sidebar tint depends on system backdrop; it is deliberately quieter than the illustrative mock.
- Image/asset fidelity: original new paper/sparkle bitmap asset, clean alpha, 1024 source and verified ICNS sizes 16–1024. Native SF Symbols replace illustrative Office/app logos in the mock. No screenshot is used as UI and no code-drawn icon replaces the asset.
- Copy/content: five actual formats and all ten independent features preserved, including separate cut/paste. Automatic saving is a status, not an invented toggle. Real repair, extension-management and export actions are on Support.

**Primary interactions and evidence limits**
- Actual native clicks: General/Support navigation; one file switch off/on with isolated JSON verification; Enable All/Disable All; English/Chinese; actual NSSavePanel path/name selection, save and export-success state.
- Exported test JSON parsed; expected schema/log components present and no /Users path or clipboard payload included. Preview uses isolated settings/log storage, not the installed app's preferences.
- Original repair/installer system operations remain mocked in tests. No real Finder restart or extension activation was performed.
- App appearance switched only inside the preview, not system preferences. Host Reduce Transparency=false and Increase Contrast=false, read only. Actual accessibility preference toggling and full VoiceOver acceptance were not run.
- Final production source build, full regression suite and deep strict ad-hoc signature verification passed. Source remains unpublished, version 2.17 / build 30.

**Follow-up polish and platform limits**
- P3: optional further alignment of sidebar tint with different desktop wallpapers. Material blur is system/backdrop dependent.
- Remaining acceptance: macOS 15.0.1 native install/menu loading, OS-version matrix, actual Reduce Transparency changes and full VoiceOver review. This design result does not claim those are complete.

**Source binding**
Baseline HEAD: 80ff15f, plus this chat's uncommitted edits.

```
38db24337e7a1c00faa16c0ce458a5946bf81410a09ff675ad22158e18b5164b  src/Main.swift
4cae53e587cb8083a101581a5bd8da7905931a9635aaa54994bcba0290524f07  src/SettingsAppearance.swift
948e3645cde3e1aa57314cda841b1136be97f8290eeb36c7d26ae7d3db5aecfa  src/Diagnostics.swift
3d5734a348f031ad88131dbf9aaeada1675ec5dd7f7f96e570e137941c13c8cd  assets/AppIconSource1024.png
7af98a8830125fdfbc21b26d279e8c34aa030a4548566fdb2d7583a225560236  Resources/FrostedBackdrop.png
```


**Appearance and updater follow-up (2026-10-26)**
- Final native layout now has General, Appearance and Diagnostics & Support pages. Appearance keeps the selected frosted design while adding standard macOS segmented controls, a transparency slider, minimal color wells and editable HEX fields.
- Latest light capture: local-review/outputs/AstraCreate-自定义外观-浅色.png
- Latest dark capture: local-review/outputs/AstraCreate-自定义外观-深色.png
- Support/update capture: local-review/outputs/AstraCreate-诊断与更新.png
- Consent capture (clearly labelled fake release): local-review/outputs/AstraCreate-更新确认-隔离测试.png
- Opened all latest captures. Chinese and English support layouts are readable without overlap at the default native size. New controls use the established native typography and card spacing.
- Real native clicks verified: light transparency65 and dark20 do not overwrite one another; custom light accent #7866CC and tint #E3DDF6 save to isolated JSON and update the swatches/sidebar; invalid HEX shows an error and is not saved. Restart preserved preferences. App-level simulated system appearance changes update the window without changing global OS preferences. The edited palette selector intentionally stays independent from the display mode.
- Real URLSession HTTPS check and the real UI check both returned GitHub stable2.17 / current2.17, with no package transfer. Project-page action reported success. No background update checks.
- Isolated native update fixture: before consent, counters only had checks1; Later caused no download. An approved fake package passed validation and reached the Installer spy once. A second approved download was cancelled via the actual UI, showed cancellation status, removed its own staging directory and did not add an Installer handoff. Final counters: checks3/downloads2/installerSpy1. The spy never runs macOS Installer; fake v9.99 is not a real release.
- Full regression suite passed, including appearance persistence/validation, updater consent/versions/source/digests/cancellation/staging/quarantine. Deep strict signature and shell syntax checks passed on the built production app.
- Evidence boundary: native UI preview uses the production settings controller with isolated settings/log roots, injectable updater and an installer spy. Host macOS27.0.1 only; actual system appearance changes, actual color-panel selection, macOS15.0.1, VoiceOver and a real newer-version overwrite installation remain pending. Color HEX entry was tested directly. Installer opening is never treated as installation success.
- All features remain unpublished. App metadata is still2.17/build30; future releases must increase app+extension versions and attach the matching PKG with GitHub digest or the SHA256SUMS asset.

Latest source binding (supersedes older hashes above):
```
73f8d4e3878df764a145fcc28ad92bc6855d5c8255330f379dd928832cf68ff1  src/Main.swift
5135f027b6b6152b0b83eeb4274b3aac2b0fba0ab1c1c52dab043a64aea1308d  src/SettingsAppearance.swift
e8cd72dab709051734f1cd28b5e0dbb216432c233176497ff4dfa39d5224539e  src/AppearancePreferences.swift
3584e14d8271d2586bfdca12a4d9244fdb56e3d6230bdcf6a8e0ae910ce04aaa  src/GitHubUpdater.swift
77052dc0a4c01d5ab846c7df12e727f4ead4351361b84362d79b19f916d1c09e  src/UpdateUI.swift
04237c70c08f07b388a7cd1b58cf729be8e131d3c5c115f880cbce2133d366f5  src/Diagnostics.swift
```


**Issue #1 developer formats follow-up (2026-10-26)**
- Current content supersedes the earlier five-format count: twelve file types (five original plus JSON/JS/TS/Vue/HTML/CSS/YAML), seventeen independent feature switches in total; no PDF option or creation route.
- Retained native card/row design and added a Developer Files card in General. All seven switches are off by default for new/legacy settings, with a short explanation. General scrolls; appearance/support navigation and language footer remain fixed.
- Latest native screenshot: local-review/outputs/AstraCreate-开发文件设置.png
- Chinese and English layouts were opened and inspected at the default window size; all seven developer rows and actions remain available via scrolling, with no overlap. Actual JSON/HTML switch clicks and isolated JSON inspection confirmed only those new formats changed and all ten prior feature values remained on. PDF is absent.
- Full production build, complete regression suite and deep strict signing verification passed. Added 1,536 developer menu combinations, copied-item dispatch, opt-in migration/persistence, actual host/helper handler file generation with UI/system effects stubbed, collision/symlink preservation and concurrent writes.
- Evidence boundary unchanged: isolated native settings preview on macOS27.0.1; actual installed Finder/target macOS15.0.1 acceptance remains pending. No project issue was closed or commented on, and no release or installation was performed.

Latest issue #1 source binding (supersedes prior hashes for changed files):
```
7b625360d7c2cbec94b616ed1d7534167bf1c83b5033a4a094494d53e82cbb95  src/Main.swift
e6f3999851f501126868aec7f401499a0d6a8a2ce0ed0b1ac6e7383379388769  src/Helper.swift
0100bb567cbee0b906b5013d0679d58b6581753b6e6f7e12fd1d6e393a0ea2cc  src/FinderSyncObjC.m
dd667fbc7f1b242b78951b5aeb5b8239119a2cb7fe922e0d21d8f234bb400cc7  src/SourceFileTemplates.swift
fd60285906289c00a02d9114b5b711d6acf995227e3d51390ac244b455167226  src/Diagnostics.swift
5cee40b89803f455cc15ce47fe4269218d0d1c2497f52999d79ce154d868fd4b  scripts/build.sh
56268bd6d5d791a9115fa3226b0bde638c7f82a92945ea8ccb6207139e895242  scripts/test.sh
```


**Sidebar spacing follow-up (2026-10-26)**
- Native navigation cells now reserve an18pt icon frame,12pt icon/title gap and12pt horizontal insets. Sidebar width increased228→248pt so the14pt English Diagnostics & Support title remains complete.
- Opened fresh native Chinese/English captures, including selected Support; spacing, shared leading alignment and full labels verified. Native build and deep strict signature verification passed. This was a layout-only change; the full functional suite from the developer-format change was not repeated.
- Latest captures: local-review/outputs/AstraCreate-侧栏间距-中文.png and local-review/outputs/AstraCreate-侧栏间距-英文.png
- Latest source hashes supersede previous entries:
```
bd0f3bd385d17d6cd9fd4694cf14813ae3a262a8ea4dcb1ee00d734ff3d3ed5a  src/Main.swift
29a7dbe797a4a3788b5b3a252d960e73b9ef2909e9e59114be2d47cc2dd51fef  src/SettingsAppearance.swift
```


**3.00 release acceptance (2026-10-26)**
- Supersedes earlier unpublished/GUI-pending notes for this host: version3.00/build31 installed through macOS Installer with the user's system authorization. Final installed app payload files match the release PKG byte-for-byte; deep strict signing verification passes and PlugInKit selects the /Applications extension.
- Native Finder toolbar created JSON/JS/TS/Vue/HTML/CSS/YAML files in a dedicated test folder. Final-package background context menu is visible; Chinese JSON creation and numbered collision creation succeeded. No PDF menu entry. Original feature settings retained; the seven test-enabled developer switches were restored to off, preserving the user's current language preference.
- Installed diagnostic export succeeded through NSSavePanel; JSON parsed and excluded user paths/clipboard payloads. Full regression suite passed for3.00. Remote real-newer-version install, macOS15.0.1, complete Office/VoiceOver/accessibility-matrix acceptance remain outside this evidence.
- Build uses relative compiler inputs plus prefix maps to remove local source paths. Expanded final PKG and current source/archive privacy checks report no local identity/credential matches or Office personal author fields.
- Historical entries above describe earlier stages; they are not claims about untested platforms or a full remote update install.

Final runtime/build source binding:
```
bd0f3bd385d17d6cd9fd4694cf14813ae3a262a8ea4dcb1ee00d734ff3d3ed5a  src/Main.swift
29a7dbe797a4a3788b5b3a252d960e73b9ef2909e9e59114be2d47cc2dd51fef  src/SettingsAppearance.swift
33ba83c681d32a529574a8794797ff6cb25703f377954fbfb0c7557fd81d1194  scripts/build.sh
0797215880ff632c50156356a0d986460344d91ec78a875e627d91ce09412e8c  AppInfo.plist
220391b13b56e32b0fc3ded252f95c5b3a97982680fbbf236e2ff4d07cdc7658  ExtensionInfo.plist
```
