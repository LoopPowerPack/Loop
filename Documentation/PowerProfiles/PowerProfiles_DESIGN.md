# PowerProfiles — Design

Status: draft for Taylor's approval (2026-11-18). Nothing is built yet.

## 1. Intent

When a person's life changes (weight gained or lost, regular running or
cycling started, a new diet), their baseline therapy settings need a
lasting adjustment, not a temporary override. Today that means editing
every time slot of every schedule by hand.

PowerProfiles lets the user pick a profile, move a slider to a percentage
(−50% to +50%), choose which settings the percentage applies to, see every
value Before and After on the same screen, and save the result as a
profile, optionally loading it at once.

The feature is an overlay on the existing **Profiles** feature (profile
save and load). Profiles becomes a permanent part of PowerPack as part of
this work.

## 2. Goals

1. One screen with: profile picker, percentage slider(s), a tick per
   setting, and a Before / After list that updates as the slider moves.
2. The percentage changes the setting's number directly: +20% makes each
   value 20% larger, −10% makes it 10% smaller. No conversion to
   "insulin need". The user interprets what a larger or smaller number
   means for each setting.
3. Settings it can change: Basal Rates, Carb Ratios, Insulin Sensitivities,
   Correction Range.
4. A per-setting slider for each ticked setting, plus a **lock** button.
   When locked, one slider drives every ticked setting with the same
   percentage. When unlocked, each ticked setting has its own slider.
5. Save options:
   - **Save as New Profile** (asks for a name).
   - **Save to This Profile** (overwrites the profile that was loaded into
     the screen).
   - **Save & Load** (saves, then loads it so Loop doses with it).
6. **Undo** restores what the last PowerProfiles save changed.
7. Own on/off switch, default OFF, like every PowerPack feature. The
   switch is on the Profiles page (section 7.1).
8. Profile Save & Load (from the Loop and Learn customization) ships in
   PowerPack permanently.

## 3. Non-goals

- No change to the dosing algorithm. Profiles and PowerProfiles only write
  therapy settings through the paths Loop already uses.
- No automatic or scheduled changes. Nothing changes unless the user taps
  a save button.
- No "insulin need" interpretation, advice or AI suggestion.
- No editing of individual time slots on this screen (the Profiles editors
  already do that).

## 4. Anti-goals (failure even if it "works")

- Any change to a user's existing saved profiles that the user did not
  explicitly save on the PowerProfiles screen.
- Breaking or migrating an existing profile library created by the Loop
  and Learn Profiles customization.
- A saved value that Loop or the pump would reject, discovered only when
  the profile is loaded.
- Large edits to Loop or LoopKit files that make upstream merges harder.

## 5. Decisions made by Taylor

| Topic | Decision |
|---|---|
| Direction | Raw number change. +20% = value × 1.20, −10% = value × 0.90 |
| Which settings | User picks one, some or all with ticks |
| Sliders | Per setting, with a lock button that applies one value to all ticked settings |
| Slider range | −50% to +50%, 5% steps |
| Saving | Save as new, save to the loaded profile, Save & Load |
| Undo | Required |
| Existing profiles | Must not be touched unless the user loads one, applies changes and saves |
| On/off | PowerProfiles has its own switch |
| Licensing | Open source; no license work needed. Keep author credit |

## 6. Profiles becomes part of PowerPack

Source: `loopandlearn/customization/profiles/dev_profiles.patch` (author
Jonas Björkert). It changes Loop, LoopKit, LoopOnboarding and
NightscoutService.

- **Left out (Taylor, 2026-11-18):** the remote profile switch from
  LoopFollow and the Nightscout profile upload. That removes every
  NightscoutService and LoopOnboarding change, plus the patch's hooks that
  exist only for them (`ServicesManager`, `RemoteDataServicesManager`,
  LoopKit `RemoteDataService`).
- The LoopKit part (6 new files plus one line in
  `TherapySettingsViewModel.swift`) is committed to PowerPack's LoopKit
  fork (`taylorpatterson-T1D/LoopKit`, branch `feat/AllFeatures`). The six
  files are copied unchanged, except for removing code that calls only
  the left-out remote parts.
- The Loop part (Profiles button in Settings, hooks in `DeviceDataManager`
  and `LoopDataManager`) is committed to Loop `feat/AllFeatures` and added
  to the Option B installer.
- **Known limitation (my call):** because the remote parts are left out,
  PowerPack's Profiles is not a byte-for-byte copy of the whole Loop and
  Learn patch. An Option A user should not apply the Loop and Learn
  Profiles customization on top of PowerPack; the README says so.
- **Compatibility with existing profile libraries:** the code is taken
  from the patch unchanged, so storage stays the same:
  `Documents/LoopProfile/*.json`, the same JSON fields, and the same
  `currentProfileName` UserDefaults key. A user who already has profiles
  sees them unchanged. Nothing is migrated.
- **No edits to the Profiles screens:** PowerPack does not change the six
  Profiles files beyond the removal above (Taylor, 2026-11-18). Everything
  PowerProfiles adds lives in Loop files.
- **Option B installer:** if the user's workspace already has the Loop and
  Learn Profiles patch (`LoopKitUI/ViewModels/ProfileViewModel.swift`
  exists), the installer skips PowerPack's Profiles code and installs only
  PowerProfiles, which then works with the user's own Profiles copy.
- Profiles itself has no on/off switch (it has none today). Only
  PowerProfiles has one.

## 7. PowerProfiles behavior

### 7.1 Entry points

Decided by Taylor, 2026-11-18:

- **Main Settings screen:** no PowerProfiles row in the PowerPack box.
  Under the existing Profiles button, one line of text in PowerPack purple
  reads "Includes PowerProfiles". Tapping it opens the Profiles page.
- **Profiles page:** holds the PowerProfiles on/off switch, so people who
  already use Profiles see it there. When the switch is on, an "Open
  PowerProfiles" button appears next to it and opens the PowerProfiles
  screen.
- **No button inside a profile's detail screen** (it would require editing
  a Profiles file).

How this is built without editing the Profiles files (my call): Loop's
Settings screen opens a PowerPack wrapper view instead of `ProfileView`
directly. The wrapper shows a PowerProfiles bar (switch, and the Open
button when on) above the unchanged `ProfileView`. When the Loop and Learn
patch is already installed, the Option B installer changes the patch's
Settings sheet to open the same wrapper.

### 7.2 Screen layout (one screen)

```
Profile: [Current settings ▾]           (or any saved profile)
[🔒 Lock]   All ticked settings  −50% ─────●───── +50%   +10%
☑ Basal Rates          −50% ───●─── +50%   +10%
☑ Carb Ratios          −50% ───●─── +50%   +10%
☑ Insulin Sensitivity  −50% ───●─── +50%   +10%
☐ Correction Range     (not changed)
Before / After  (every time slot of every ticked setting)
 Basal   00:00  0.85 → 0.95 U/h
 CR      06:00  10   → 11   g/U
 ISF     00:00  45   → 50   mg/dL/U
 Target  00:00  100–110 → 110–121 mg/dL   ⚠ above recommended
[Undo]  [Save as New Profile]  [Save to "Running"]  [Save & Load]
```

- Locked: one slider at the top; the per-setting sliders show the same
  value and are disabled.
- Unlocked: each ticked setting uses its own slider.
- An unticked setting is not changed and shows no After column.
- "Current settings" means Loop's active therapy settings. "Save to this
  profile" is not offered for it.

### 7.3 Math and rounding

- After = Before × (1 + percent / 100).
- Correction Range: both the lower and upper value of each range are
  scaled.
- Rounding:
  - Basal rates: to the pump's supported basal increments.
  - Carb ratios: 0.1 g/U.
  - Insulin sensitivity: 1 mg/dL/U, or 0.1 mmol/L/U.
  - Correction range: 1 mg/dL, or 0.1 mmol/L.
- Display uses the user's glucose unit.

### 7.4 Safety checks

- Every After value is checked against Loop's guardrails for that setting.
  - Outside the recommended range: amber warning, save allowed (same as
    Therapy Settings).
  - Outside the absolute limits: red, all save buttons disabled.
- Basal rates must be values the pump supports.
- Saving asks for Face ID / passcode, as Therapy Settings does.
- Save & Load uses the Profiles load path: the basal schedule is written
  to the pump first. If the pump write fails, nothing is saved as active
  and the error is shown.

### 7.5 What each save writes

| Button | Writes | Active settings change? |
|---|---|---|
| Save as New Profile | a new file in `Documents/LoopProfile/` | No |
| Save to This Profile | overwrites the loaded profile's file | No, unless that profile is the active one; then Loop asks whether to load it now (same prompt Profiles uses after an edit) |
| Save & Load | the profile file, then loads it | Yes |

Nothing is written when the screen opens, the slider moves, or the user
leaves without saving.

### 7.6 Undo

- Before each save, PowerProfiles keeps a copy of everything that save
  will overwrite: the profile file's previous contents (or "did not
  exist"), and for Save & Load the previous active therapy settings and
  the previous `currentProfileName`.
- Undo restores the copy:
  - A new profile is deleted.
  - An overwritten profile gets its old contents back.
  - After Save & Load, the previous settings are loaded again, which
    writes the previous basal schedule to the pump.
- One level of undo: the most recent PowerProfiles save. The copy is
  stored on disk, so Undo still works after the app restarts. It is
  cleared when a newer PowerProfiles save replaces it.

### 7.7 DataLayer

- Every PowerProfiles save posts one event: action (new / overwrite /
  save-and-load / undo), profile name, ticked settings and their
  percentages.
- Changes to active therapy settings are already recorded by
  `DataLayer_SettingsChangeEvents` through `DeviceDataManager.saveCompletion`.

## 8. PowerPack standards that apply

- Files under `Loop/Views/PowerProfiles/`, `Loop/Models/PowerProfiles/` and
  `Loop/Services/PowerProfiles/`, all named `PowerProfiles_*`, with the
  standard header.
- Loop file changes limited to `SettingsView.swift` (the Profiles button
  opens the wrapper view, and the purple "Includes PowerProfiles" line),
  plus the Profiles hooks from section 6.
- Feature switch default OFF.
- `PowerProfiles_README.md` (for users) and `PowerProfiles_DEVELOPER.md`
  (for developers) in `Loop/Documentation/PowerProfiles/`.
- Tests in `LoopTests/PowerProfiles/`, written before the code: math,
  rounding, guardrail classification, lock behavior, undo snapshot and
  restore, "nothing written without save".
- Installer: `NEW_FILES`, `update_pbxproj.py`, the embedded `SettingsView`
  insert, the LoopKit Profiles files, and the skip rule from section 6.
- `DIVERGENCE.md`: add PowerProfiles and Profiles to the feature table.

## 9. Left to the builder

- Exact view model structure and SwiftUI layout details.
- Where the Undo copy is stored (a file in Application Support is
  expected).
- Exact wording of warnings, within the plain-language rule.

## 10. Open questions

None. Answered by Taylor on 2026-11-18: remote switch and Nightscout
upload left out (section 6); no button inside a profile's detail screen
(7.1); PowerProfiles switch on the Profiles page with a purple "Includes
PowerProfiles" line on the main Settings screen (7.1).
