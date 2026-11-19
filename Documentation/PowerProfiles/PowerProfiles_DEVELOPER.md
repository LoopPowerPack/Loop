# PowerProfiles — Developer Notes

Design: `PowerProfiles_DESIGN.md`. Build plan: `PowerProfiles_PLAN.md`.

## Pieces

| File | Does |
|---|---|
| LoopKit fork: `LoopKitUI/ViewModels/ProfileViewModel*.swift`, `LoopKitUI/Views/Settings Editors/{Profile,ProfilePreview,NewProfileEditor,RenameProfileEditor}View.swift` | Profiles (Loop and Learn `dev_profiles.patch`, LoopKit part, files unchanged). |
| LoopKit fork: `TherapySettingsViewModel.swift` | `updateCurrentProfileName()` on the delegate protocol, with an empty default so LoopOnboarding needs no change. |
| `Loop/Models/PowerProfiles/PowerProfiles_Models.swift` | Feature switch key, settings enum, slider rules, `PowerProfiles_Adjustment`, `PowerProfiles_ProfileValues` (same JSON as LoopKitUI `Profile`). |
| `Loop/Models/PowerProfiles/PowerProfiles_Scaler.swift` | Scaling, rounding, guardrail checks (`PowerProfiles_Review`), display formatting. Pure functions. |
| `Loop/Services/PowerProfiles/PowerProfiles_ProfileStore.swift` | Reads and writes `Documents/LoopProfile/*.json`. |
| `Loop/Services/PowerProfiles/PowerProfiles_UndoStore.swift` | One undo snapshot in `Application Support/PowerProfiles/undo.json`. |
| `Loop/Services/PowerProfiles/PowerProfiles_Coordinator.swift` | Save as New, Save to, Save & Load, Undo. Loads through `ProfileViewModel` (`validateProfile`, `loadProfile`). Posts `com.loopkit.Loop.powerProfilesSaved`. |
| `Loop/View Models/PowerProfiles/PowerProfiles_ViewModel.swift` | Screen state. |
| `Loop/Views/PowerProfiles/PowerProfiles_View.swift` | The screen. |
| `Loop/Views/PowerProfiles/PowerProfiles_ProfilesPage.swift` | PowerProfiles bar (switch, Open) above `ProfileView`. |
| `Loop/Views/SettingsView.swift` | Profiles button opening `PowerProfiles_ProfilesPage`, and the purple "Includes PowerProfiles" line. |
| `DataLayer_EventModels.swift`, `DataLayer_Coordinator.swift` | `powerProfilesSaved` event (`DataLayer_PowerProfilesSavedPayload`). |

## Why PowerProfiles writes profile files itself

`Profile`'s and `ProfileReference`'s properties and `Profile`'s initializer
are internal to LoopKitUI, and the Profiles files must stay identical to the
Loop and Learn patch. PowerProfiles therefore mirrors the JSON
(`PowerProfiles_ProfileValues`) and converts to `Profile` by a JSON round
trip only when loading.

## Loading

`PowerProfiles_ProfileViewModelLoader.activate` calls `validateProfile`, then
`loadProfile`, which writes the basal schedule to the pump and saves all four
settings through `TherapySettingsViewModelDelegate.saveCompletion`. DataLayer
records the therapy settings change from there as for any other save.

## Option B installer

- LoopKit: when `LoopKitUI/ViewModels/ProfileViewModel.swift` is missing,
  applies `patches/powerpack_profiles_loopkit.patch` and writes
  `LoopKit/.powerpack_profiles`; rollback removes Profiles only when that
  marker exists. When the user already has the Loop and Learn patch, it is
  left alone.
- SettingsView: inserts the Profiles button, or, when the Loop and Learn
  Settings hunk is present, changes `ProfileView(` to
  `PowerProfiles_ProfilesPage(` and adds the purple line.
- `update_pbxproj.py --features power_profiles`.

## Tests

`LoopTests/PowerProfiles/`: Models, Scaler, ProfileStore, Undo (fake loader).
