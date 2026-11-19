# PowerProfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Profile Save & Load in PowerPack and add PowerProfiles, a one-screen percentage adjuster that saves its result as a profile.

**Architecture:** Profiles code comes from Loop and Learn's `dev_profiles.patch` (LoopKit part only, files unchanged) and goes into the LoopKit fork. PowerProfiles lives in the Loop target under `PowerProfiles_*` files. It reads and writes the same profile JSON files itself, and uses only the public `ProfileViewModel` API to load a profile. Loop's Settings screen opens a wrapper view that shows the PowerProfiles switch above the unchanged `ProfileView`.

**Tech Stack:** Swift 5, SwiftUI, XCTest, LoopKit / LoopKitUI, bash + Python installer.

**Spec:** `Documentation/PowerProfiles/PowerProfiles_DESIGN.md`

## Global Constraints

- No `xcodebuild` / `swift build`. Taylor builds and runs tests in Xcode; each "run" step below is Taylor's.
- Loop target compiles for iOS 15.1: gate newer APIs with `#available`.
- Slider: −50…+50, step 5. After = Before × (1 + percent/100).
- Settings: Basal Rates, Carb Ratios, Insulin Sensitivities, Correction Range (both bounds).
- Rounding: basal → nearest pump-supported rate; carb ratio → 0.1 g/U; insulin sensitivity → 1 mg/dL/U; correction range → 1 mg/dL. Values are stored in mg/dL (as Profiles stores them); mmol/L is a display conversion shown to 0.1.
- Blocked (save disabled) = outside the guardrail's absolute bounds, or basal not supported by the pump, or basal above maximum basal rate. Warning = outside recommended bounds.
- Profile files: `Documents/LoopProfile/*.json`, Profiles' JSON keys (`name`, `correctionRange`, `carbRatioSchedule`, `basalRateSchedule`, `insulinSensitivitySchedule`, `sortOrder`), file name `yyyy-MM-dd-HH-mm-ss.json`, names sanitized as Profiles does ("." and "<" → "_", max 32 characters). Active-profile key: UserDefaults `currentProfileName`.
- Nothing is written to disk unless the user taps a save button or Undo.
- Feature switch key `PowerProfiles.isEnabled`, default false.
- File headers: the standard PowerPack header (see `DataLayer_SettingsChangeEvents.swift`).
- Loop-file edits only in `SettingsView.swift`. LoopKit's six Profiles files byte-identical to the Loop and Learn patch.

## Review Focus

1. A schedule with many time slots (e.g. 24 basal rates): every slot appears in Before/After, and rounding is per slot. Test in Task 3.
2. A percentage that pushes a basal rate between two supported pump rates, or below the pump's lowest rate: rounds to the nearest supported rate; below lowest → blocked, not silently raised. Test in Task 3.
3. "Save as New" with a name that already exists (after sanitizing): refused with a message; the existing file is not touched. Test in Task 4.
4. Undo after the app restarts, and Undo pressed twice: first restores; second has nothing to undo and changes nothing. Test in Task 5.
5. Correction range in mmol/L users: stored values stay mg/dL; Before/After shows mmol/L to 0.1. Test in Task 3.

---

### Task 1: Profiles in the LoopKit fork

**Files (LoopKit repo, worktree `.worktrees/loopkit`, branch `feat/PowerProfiles` from `fork/feat/AllFeatures`):**
- Apply: Loop and Learn `dev_profiles.patch`, LoopKit hunks only, minus `LoopKit/Service/RemoteDataService.swift` (saved as `loopkit_profiles.patch`).
- Modify: `LoopKitUI/ViewModels/TherapySettingsViewModel.swift` — after the protocol, add `public extension TherapySettingsViewModelDelegate { func updateCurrentProfileName() {} }` with a comment: default so delegates outside Loop (LoopOnboarding) need no change.

**Interfaces:**
- Produces (public, from the patch): `ProfileViewModel(therapySettings:pumpSupportedIncrements:sensitivityOverridesEnabled:adultChildInsulinModelSelectionEnabled:prescription:delegate:)`, `therapySettings`, `currentProfileName`, `loadProfiles()`, `savedProfile(named:) throws -> Profile?`, `validateProfile(_:) -> Result<Void, ProfileValidationError>`, `loadProfile(profile:completion:)`, `pumpSupportedIncrements()`, `ProfileView(viewModel:)`, `Profile: Codable`.

- [ ] Step 1: `git apply loopkit_profiles.patch`; `git diff --stat` shows 8 files.
- [ ] Step 2: Add the default extension.
- [ ] Step 3: Check the six new Swift files are byte-identical to the patch (`cmp` against the extracted copies).
- [ ] Step 4: Commit "Profiles: Loop and Learn profile save and load (Jonas Björkert), without remote switch". Save `git format-patch -1 --stdout` as the installer patch for Task 8.

### Task 2: Models and feature switch

**Files:**
- Create: `Loop/Models/PowerProfiles/PowerProfiles_Models.swift`
- Test: `LoopTests/PowerProfiles/PowerProfiles_ModelsTests.swift`

**Interfaces — Produces:**
- `enum PowerProfiles_FeatureFlags { enum Keys { static let isEnabled = "PowerProfiles.isEnabled" } }`
- `enum PowerProfiles_Setting: String, CaseIterable, Codable { case basalRates, carbRatios, insulinSensitivity, correctionRange }`
- `enum PowerProfiles_Slider { static let range: ClosedRange<Int> = -50...50; static let step = 5; static func snap(_ value: Double) -> Int }`
- `struct PowerProfiles_Adjustment: Equatable, Codable { var isLocked: Bool; var lockedPercent: Int; var percents: [PowerProfiles_Setting: Int]; var ticked: Set<PowerProfiles_Setting>; func percent(for: PowerProfiles_Setting) -> Int? }` — nil when not ticked; `lockedPercent` when locked; else `percents[setting] ?? 0`. Default: unlocked, 0, empty, nothing ticked.
- `struct PowerProfiles_ProfileValues: Codable, Equatable { var name: String; var correctionRange: GlucoseRangeSchedule; var carbRatioSchedule: CarbRatioSchedule; var basalRateSchedule: BasalRateSchedule; var insulinSensitivitySchedule: InsulinSensitivitySchedule; var sortOrder: Int? }` plus `static func current(name: String, from: TherapySettings) -> PowerProfiles_ProfileValues?` (mg/dL schedules; nil when any schedule is missing).

- [ ] Step 1: Tests: `testSnapRoundsToNearestFiveAndClamps` (7.4→5, 7.5→10, −53→−50, 61→50); `testPercentNilWhenNotTicked`; `testLockedUsesLockedPercentForEveryTickedSetting`; `testUnlockedUsesPerSettingPercent`; `testProfileValuesJSONMatchesProfilesKeys` (encode, decode as `[String: Any]`, keys equal the six Profiles keys); `testProfileValuesDecodesAsLoopKitProfile` (encode, `JSONDecoder().decode(Profile.self…)` succeeds).
- [ ] Step 2: Taylor runs → fail (types missing).
- [ ] Step 3: Implement.
- [ ] Step 4: Taylor runs → pass.
- [ ] Step 5: Commit.

### Task 3: Scaling, rounding and safety checks

**Files:**
- Create: `Loop/Models/PowerProfiles/PowerProfiles_Scaler.swift`
- Test: `LoopTests/PowerProfiles/PowerProfiles_ScalerTests.swift`

**Interfaces — Produces:**
- `enum PowerProfiles_Scaler { static func scale(_ values: PowerProfiles_ProfileValues, by: PowerProfiles_Adjustment, supportedBasalRates: [Double]) -> PowerProfiles_ProfileValues }` — unticked schedules returned unchanged; start times kept.
- `enum PowerProfiles_Check: Equatable { case ok, warning, blocked }`
- `struct PowerProfiles_Row: Identifiable, Equatable { let id: String; let setting: PowerProfiles_Setting; let startTime: TimeInterval; let before: [Double]; let after: [Double]; let check: PowerProfiles_Check }` — `before`/`after` hold one value, or two (min, max) for correction range; mg/dL for glucose values.
- `enum PowerProfiles_Review { static func rows(before:after:ticked:supportedBasalRates:maximumBasalRate:) -> [PowerProfiles_Row]; static func canSave(_ rows: [PowerProfiles_Row]) -> Bool }` — rows only for ticked settings, in setting order then start time. `check` uses `Guardrail.carbRatio / .insulinSensitivity / .correctionRange` (blocked iff outside `absoluteBounds`, warning iff `classification` ≠ `.withinRecommendedRange`); basal blocked iff not in `supportedBasalRates`, ≤ 0, or > `maximumBasalRate`.
- `enum PowerProfiles_Format { static func glucose(_ mgdl: Double, unit: HKUnit) -> String }` (mmol/L to 0.1).

- [ ] Step 1: Tests: `testPlusTwentyMultipliesByOnePointTwo` (CR 10 → 12.0); `testMinusTenMultipliesByNinetyPercent` (ISF 50 → 45); `testCarbRatioRoundsToTenth` (CR 8.3 × 1.05 = 8.715 → 8.7); `testBasalRoundsToNearestSupportedRate` (0.85 × 1.1 = 0.935 with rates stride 0.05 → 0.95); `testBasalBelowLowestSupportedIsBlocked`; `testEveryBasalSlotScaled` (24 slots); `testCorrectionRangeScalesBothBounds` (100–110 × 1.1 → 110–121); `testUntickedScheduleUnchanged`; `testOutsideRecommendedIsWarning` (CR 30); `testOutsideAbsoluteIsBlocked` (CR 160); `testBasalAboveMaximumIsBlocked`; `testCanSaveFalseWhenAnyRowBlocked`; `testMmolDisplay` (100 mg/dL → "5.6").
- [ ] Step 2–5: fail, implement, pass, commit.

### Task 4: Profile file store

**Files:**
- Create: `Loop/Services/PowerProfiles/PowerProfiles_ProfileStore.swift`
- Test: `LoopTests/PowerProfiles/PowerProfiles_ProfileStoreTests.swift`

**Interfaces — Produces:**
- `struct PowerProfiles_StoredProfile: Equatable { let fileName: String; let values: PowerProfiles_ProfileValues }`
- `enum PowerProfiles_StoreError: LocalizedError, Equatable { case nameExists(String), emptyName, notFound(String) }`
- `final class PowerProfiles_ProfileStore { init(directory: URL = <Documents>/LoopProfile); static func sanitize(_ name: String) -> String; func loadAll() -> [PowerProfiles_StoredProfile]; func data(fileName: String) -> Data?; func createNew(_ values: PowerProfiles_ProfileValues, now: Date = Date()) throws -> String /* file name */; func overwrite(_ values: PowerProfiles_ProfileValues, fileName: String) throws; func restore(fileName: String, data: Data?) throws /* nil → delete */ }` — writes are atomic; `createNew` sets `sortOrder = -1`, throws `nameExists` when a sanitized name matches, picks the next free second if the file name exists; `loadAll` skips files that fail to decode, sorted by `sortOrder ?? 0`.

- [ ] Step 1: Tests (temp directory): `testSanitizeMatchesProfiles`; `testCreateNewWritesProfilesJSON`; `testCreateNewRefusesExistingName` (existing file unchanged byte-for-byte); `testOverwriteKeepsFileName`; `testRestoreNilDeletes`; `testRestoreDataPutsBackBytes`; `testLoadAllSkipsUnreadableFiles`.
- [ ] Step 2–5: fail, implement, pass, commit.

### Task 5: Undo and save coordinator

**Files:**
- Create: `Loop/Services/PowerProfiles/PowerProfiles_UndoStore.swift`, `Loop/Services/PowerProfiles/PowerProfiles_Coordinator.swift`
- Test: `LoopTests/PowerProfiles/PowerProfiles_UndoTests.swift`

**Interfaces — Produces:**
- `enum PowerProfiles_SaveAction: String, Codable { case saveNew, saveExisting, saveAndLoad, undo }`
- `struct PowerProfiles_UndoSnapshot: Codable, Equatable { let action: PowerProfiles_SaveAction; let fileName: String; let previousFileData: Data?; let previousActive: PowerProfiles_ProfileValues?; let previousProfileName: String?; let date: Date }`
- `final class PowerProfiles_UndoStore { init(url: URL = <Application Support>/PowerProfiles/undo.json); func save(_: PowerProfiles_UndoSnapshot) throws; func load() -> PowerProfiles_UndoSnapshot?; func clear() }`
- `protocol PowerProfiles_ProfileLoading: AnyObject { var activeValues: PowerProfiles_ProfileValues? { get }; var activeProfileName: String? { get set }; func activate(_ values: PowerProfiles_ProfileValues, completion: @escaping (Result<Void, Error>) -> Void) }` and `final class PowerProfiles_ProfileViewModelLoader: PowerProfiles_ProfileLoading` wrapping `ProfileViewModel` (activate = `loadProfiles()`; JSON round-trip values → `Profile`; `validateProfile`; `loadProfile`).
- `final class PowerProfiles_Coordinator { init(store:undoStore:loader:notificationCenter: = .default); func saveNew(_:) throws -> String; func saveExisting(_:fileName:) throws; func saveAndLoad(_:fileName: String?, completion: @escaping (Result<Void, Error>) -> Void); func undo(completion: @escaping (Result<Void, Error>) -> Void); var canUndo: Bool }` — each save writes an `UndoSnapshot` first; `saveAndLoad` restores the file if activation fails; `undo` restores the file, re-activates `previousActive` and sets `previousProfileName` when the action was `saveAndLoad`, then clears the snapshot; every save and undo posts `PowerProfiles_Coordinator.savedNotification` (`com.loopkit.Loop.powerProfilesSaved`, userInfo: `action`, `profileName`, `percents: [String: Int]`).

- [ ] Step 1: Tests with a fake loader and temp directories: `testSaveNewThenUndoDeletesFile`; `testSaveExistingThenUndoRestoresBytes`; `testSaveAndLoadThenUndoReactivatesPrevious` (fake records activate calls and name); `testFailedActivationRestoresFile`; `testUndoSurvivesNewStoreInstance` (restart); `testSecondUndoDoesNothing`; `testSavePostsNotification`.
- [ ] Step 2–5: fail, implement, pass, commit.

### Task 6: Screens and Settings entry

**Files:**
- Create: `Loop/Views/PowerProfiles/PowerProfiles_ProfilesPage.swift` (wrapper: bar with switch + "Open PowerProfiles", then `ProfileView(viewModel:)`; reloads `viewModel.loadProfiles()` when the PowerProfiles sheet closes)
- Create: `Loop/Views/PowerProfiles/PowerProfiles_View.swift` (one screen per design 7.2; profile picker = "Current settings" + saved profiles; lock button; per-setting tick + slider; Before/After rows with amber/red; Undo, Save as New (name prompt), Save to "<name>" (hidden for Current settings), Save & Load; every save behind `@Environment(\.authenticate)`; save buttons disabled when `!PowerProfiles_Review.canSave`)
- Create: `Loop/View Models/PowerProfiles/PowerProfiles_ViewModel.swift` (`@Published adjustment`, `selectedBase`, computed `after` and `rows`; calls the coordinator)
- Modify: `Loop/Views/SettingsView.swift` — `@State private var showProfiles = false`; in `configurationSection` after the Therapy Settings `NavigationLink`, the Profiles `LargeButton` + `.sheet` from the patch with `ProfileView(` replaced by `PowerProfiles_ProfilesPage(`, then a `Button` with text "Includes PowerProfiles" in the colour `PowerPackGroupBorder` uses that sets `showProfiles = true`.

**Interfaces — Consumes:** Tasks 2–5. `PowerProfiles_ProfilesPage(viewModel: ProfileViewModel)`.

- [ ] Step 1: Implement the view model with the Task 3 functions only (no new logic beyond wiring).
- [ ] Step 2: Implement the views and the Settings edit.
- [ ] Step 3: Commit. Taylor checks on device: switch off → no Open button; on → screen opens; moving the slider changes After only; leaving without saving writes nothing (profile list unchanged).

### Task 7: DataLayer event, project file, docs

**Files:**
- Modify: `Loop/Models/DataLayer/DataLayer_EventModels.swift` — `case powerProfilesSaved` (consent `.aiBehavioral`, with `therapySettingsChanged`); `struct DataLayer_PowerProfilesSavedPayload: Codable { let action: String; let profileName: String; let percents: [String: Int] }`.
- Modify: `Loop/Managers/DataLayer/DataLayer_Coordinator.swift` — observer for `com.loopkit.Loop.powerProfilesSaved`, same shape as `observeSiteAtlasNotifications`.
- Modify: `Loop.xcodeproj/project.pbxproj` — run the Task 8 `update_pbxproj.py --features power_profiles` on it.
- Create: `Documentation/PowerProfiles/PowerProfiles_README.md`, `PowerProfiles_DEVELOPER.md` (README states: Option A users should not also apply the Loop and Learn Profiles customization).
- [ ] Steps: edit, run updater, `git diff --stat` shows only these files, commit.

### Task 8: Installer and workspace

**Files (workspace repo):**
- `feat/installer` → `Scripts/install_features.sh`: new files in `NEW_FILES`; new phase "Profiles in LoopKit": skip when `LoopKit/LoopKitUI/ViewModels/ProfileViewModel.swift` exists; else download `patches/powerpack_profiles_loopkit.patch` the way the script fetches its other files, `git apply` it in LoopKit, and write marker `LoopKit/.powerpack_profiles`; rollback removes the Profiles files only when the marker exists; `patch_settings_view`: if `ProfileView(viewModel: ProfileViewModel(` is present (Loop and Learn), replace `ProfileView(` with `PowerProfiles_ProfilesPage(` and insert the purple line after that sheet; else insert the Task 6 block; validation checks for `PowerProfiles_ProfilesPage`.
- `feat/installer` → `Scripts/update_pbxproj.py`: feature id `power_profiles`; SOURCE_FILES, TEST_FILES, SUBGROUPS for `Models/PowerProfiles`, `Services/PowerProfiles`, `Views/PowerProfiles`, `View Models/PowerProfiles`, `LoopTests/PowerProfiles`.
- `feat/installer` → `patches/powerpack_profiles_loopkit.patch` (from Task 1).
- `feat/AllFeatures` → `DIVERGENCE.md` feature table rows for Profiles and PowerProfiles.
- [ ] Step 1: Dry-run the Settings insert on `git show origin/dev:Loop/Views/SettingsView.swift` and on a copy with the Loop and Learn hunk applied; both contain `PowerProfiles_ProfilesPage` once.
- [ ] Step 2: Dry-run the LoopKit phase on a clean copy of LoopKit's released LoopKit (`a7b43f4d`): files present, marker written; second run skips.
- [ ] Step 3: `bash -n`, commit (not pushed).

### Task 9: Local checkout for Taylor's Option A build

- [ ] Point the main checkout's `Loop` and `LoopKit` at `feat/PowerProfiles` (both clean except machine-local files) and report what Taylor builds and which tests to run (`LoopTests/PowerProfiles/*`). Pushing branches waits for Taylor.
