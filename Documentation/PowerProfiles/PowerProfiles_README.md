# PowerProfiles

Change your saved therapy settings by a percentage, on one screen, and save
the result as a profile.

Use it when your needs change for weeks or months: weight gained or lost,
regular running or cycling, a new diet. For a few hours, use an override
preset instead.

## Profiles

PowerPack includes **Profiles** (profile save and load, by Jonas Björkert,
from the Loop and Learn customizations). Settings → **Profiles** saves your
correction range, carb ratios, basal rates and insulin sensitivities under a
name, and loads a saved profile later.

If you already used the Loop and Learn Profiles customization, your saved
profiles appear unchanged. PowerPack uses the same files.

Not included: switching profiles from LoopFollow, and uploading saved
profiles to Nightscout.

## Turning PowerProfiles on

Settings → **Profiles** (or tap **Includes PowerProfiles** under it). The
PowerProfiles bar at the top of the Profiles page has the on/off switch.
PowerProfiles is off until you turn it on. When it is on, tap **Open**.

## Using it

1. **Start from:** Loop's current settings, or one of your saved profiles.
2. **Tick** each setting to change: Basal Rates, Carb Ratios, Insulin
   Sensitivities, Correction Range.
3. **Move the slider** from −50% to +50%, in 1% steps. +20% makes each value
   20% larger; −10% makes it 10% smaller. The numbers change as written; what
   a larger or smaller number means differs per setting, so check each one.
   - **Lock** applies one slider to every ticked setting.
   - **Unlocked**, each ticked setting has its own slider.
4. **Before / After** appears under each ticked setting's slider, one line
   per time slot.
   - Orange: outside the recommended range. You can still save.
   - Red: outside the limits Loop allows, or a basal rate your pump cannot
     deliver. Saving is turned off until you choose a smaller change.
5. **Save:**
   - **Save as New Profile** — enter a name. It is saved, not loaded.
   - **Save to "<profile>"** — replaces that saved profile's values. Shown
     when you started from a saved profile.
   - **Save & Load** — saves, then loads it: Loop sends the basal schedule
     to the pump and starts using the new settings.
6. **Undo Last PowerProfiles Save** puts back what the last save changed,
   including Loop's previous settings after a Save & Load. It still works
   after the app restarts. Only the most recent save can be undone.

Every save asks for Face ID, Touch ID or your passcode.

Nothing is saved when you move a slider or close the screen. Your saved
profiles change only when you tap **Save to** or **Save & Load** on them.

Values are rounded: basal rates to what your pump supports, carb ratios to
0.1 g/U, insulin sensitivities and correction ranges to 1 mg/dL.

## Option A users

PowerPack already contains Profiles. Do not also apply the Loop and Learn
Profiles customization to a PowerPack (Option A) build.

## Disclaimer

PowerProfiles changes the settings Loop doses with. Agree on large changes
with your care team. This is not medical advice.
