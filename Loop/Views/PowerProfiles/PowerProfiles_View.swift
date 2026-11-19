//
//  PowerProfiles_View.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — The one screen: choose a profile, tick settings, move the
//  sliders, read Before / After, then save, save and load, or undo.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import SwiftUI
import HealthKit
import LoopKit
import LoopKitUI

struct PowerProfiles_View: View {

    @ObservedObject var viewModel: PowerProfiles_ViewModel
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.authenticate) private var authenticate
    @Environment(\.presentationMode) private var presentationMode

    static let purple = Color(red: 107/255, green: 47/255, blue: 160/255)

    var body: some View {
        NavigationView {
            Form {
                baseSection
                changeSection
                beforeAfterSection
                saveSection
            }
            .navigationTitle(Text("PowerProfiles"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(NSLocalizedString("Done", comment: "PowerProfiles close button")) {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: Binding(get: { viewModel.message != nil }, set: { if !$0 { viewModel.message = nil } })) {
                Alert(title: Text("PowerProfiles"), message: Text(viewModel.message ?? ""), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: Sections

    private var baseSection: some View {
        Section(header: Text(NSLocalizedString("Start from", comment: "PowerProfiles base profile section")),
                footer: Text(NSLocalizedString("Nothing is saved until you tap a save button. Saved profiles are changed only by Save to.", comment: "PowerProfiles base section footer"))) {
            Picker(NSLocalizedString("Profile", comment: "PowerProfiles base profile picker"), selection: $viewModel.base) {
                Text(NSLocalizedString("Current settings", comment: "PowerProfiles base: Loop's active settings"))
                    .tag(PowerProfiles_ViewModel.Base.current)
                ForEach(viewModel.savedProfiles, id: \.fileName) { profile in
                    Text(profile.values.name).tag(PowerProfiles_ViewModel.Base.saved(fileName: profile.fileName))
                }
            }
        }
    }

    private var changeSection: some View {
        Section(header: Text(NSLocalizedString("Change", comment: "PowerProfiles sliders section")),
                footer: Text(NSLocalizedString("+20% makes each value 20% larger. −10% makes it 10% smaller.", comment: "PowerProfiles slider explanation"))) {
            HStack {
                Button(action: viewModel.toggleLock) {
                    Label(viewModel.adjustment.isLocked
                          ? NSLocalizedString("Locked: one change for all ticked", comment: "PowerProfiles lock on")
                          : NSLocalizedString("Unlocked: one change per setting", comment: "PowerProfiles lock off"),
                          systemImage: viewModel.adjustment.isLocked ? "lock.fill" : "lock.open")
                }
                .buttonStyle(.borderless)
                .foregroundColor(Self.purple)
            }
            if viewModel.adjustment.isLocked {
                sliderRow(title: NSLocalizedString("All ticked settings", comment: "PowerProfiles shared slider"),
                          percent: viewModel.adjustment.lockedPercent,
                          enabled: true,
                          set: viewModel.setLockedPercent)
            }
            ForEach(PowerProfiles_Setting.allCases) { setting in
                let ticked = viewModel.adjustment.ticked.contains(setting)
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: { viewModel.toggleTick(setting) }) {
                        Label(setting.title, systemImage: ticked ? "checkmark.square.fill" : "square")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(ticked ? Self.purple : .secondary)
                    if ticked && !viewModel.adjustment.isLocked {
                        sliderRow(title: nil, percent: viewModel.percent(for: setting), enabled: true) {
                            viewModel.setPercent($0, for: setting)
                        }
                    }
                }
            }
        }
    }

    private func sliderRow(title: String?, percent: Int, enabled: Bool, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title).font(.subheadline)
            }
            HStack {
                Text("−50%").font(.caption).foregroundColor(.secondary)
                Slider(value: Binding(get: { Double(percent) }, set: set),
                       in: Double(PowerProfiles_Slider.range.lowerBound)...Double(PowerProfiles_Slider.range.upperBound),
                       step: Double(PowerProfiles_Slider.step))
                    .accentColor(Self.purple)
                    .disabled(!enabled)
                Text("+50%").font(.caption).foregroundColor(.secondary)
                Text(Self.percentText(percent))
                    .font(.body.monospacedDigit().bold())
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }

    private var beforeAfterSection: some View {
        Section(header: Text(NSLocalizedString("Before / After", comment: "PowerProfiles comparison section"))) {
            if viewModel.before == nil {
                Text(NSLocalizedString("Loop's therapy settings are not complete, so there is nothing to change.", comment: "PowerProfiles missing settings"))
                    .foregroundColor(.secondary)
            } else if viewModel.rows.isEmpty {
                Text(NSLocalizedString("Tick a setting to see its new values.", comment: "PowerProfiles nothing ticked"))
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.rows) { row in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text(row.setting.title).font(.caption).foregroundColor(.secondary)
                            Text(Self.time(row.startTime)).font(.body.monospacedDigit())
                        }
                        Spacer()
                        Text(format(row.before, row.setting)).foregroundColor(.secondary)
                        Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                        Text(format(row.after, row.setting)).bold().foregroundColor(color(row.check))
                        if row.check != .ok {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(color(row.check))
                        }
                    }
                }
                if !PowerProfiles_Review.canSave(viewModel.rows) {
                    Text(NSLocalizedString("Red values are outside the limits Loop allows. Choose a smaller change to save.", comment: "PowerProfiles blocked explanation"))
                        .font(.footnote).foregroundColor(.red)
                } else if viewModel.rows.contains(where: { $0.check == .warning }) {
                    Text(NSLocalizedString("Orange values are outside the recommended range. You can still save them.", comment: "PowerProfiles warning explanation"))
                        .font(.footnote).foregroundColor(.orange)
                }
            }
        }
    }

    private var saveSection: some View {
        Section(header: Text(NSLocalizedString("Save", comment: "PowerProfiles save section"))) {
            TextField(NSLocalizedString("Name for a new profile", comment: "PowerProfiles new profile name field"), text: $viewModel.newName)
            Button(NSLocalizedString("Save as New Profile", comment: "PowerProfiles save new button")) {
                withAuthentication(viewModel.saveNew)
            }
            .disabled(!viewModel.canSave || !viewModel.hasNewName)
            if let baseProfile = viewModel.baseProfile {
                Button(String(format: NSLocalizedString("Save to \"%@\"", comment: "PowerProfiles save to loaded profile button"), baseProfile.values.name)) {
                    withAuthentication(viewModel.saveExisting)
                }
                .disabled(!viewModel.canSave)
            }
            Button(NSLocalizedString("Save & Load", comment: "PowerProfiles save and load button")) {
                withAuthentication(viewModel.saveAndLoad)
            }
            .disabled(!viewModel.canSave || viewModel.baseProfile == nil && !viewModel.hasNewName)
            if viewModel.canUndo {
                Button(NSLocalizedString("Undo Last PowerProfiles Save", comment: "PowerProfiles undo button")) {
                    withAuthentication(viewModel.undo)
                }
                .foregroundColor(.red)
                .disabled(viewModel.isWorking)
            }
        }
    }

    // MARK: Helpers

    private func withAuthentication(_ action: @escaping () -> Void) {
        authenticate(NSLocalizedString("Authenticate to save therapy settings", comment: "PowerProfiles authentication reason")) { result in
            if case .success = result {
                action()
            }
        }
    }

    private func color(_ check: PowerProfiles_Check) -> Color {
        switch check {
        case .ok: return .primary
        case .warning: return .orange
        case .blocked: return .red
        }
    }

    private func format(_ values: [Double], _ setting: PowerProfiles_Setting) -> String {
        let unit = displayGlucosePreference.unit
        switch setting {
        case .basalRates:
            return String(format: "%g U/h", values.first ?? 0)
        case .carbRatios:
            return String(format: "%.1f g/U", values.first ?? 0)
        case .insulinSensitivity:
            return PowerProfiles_Format.glucose(values.first ?? 0, unit: unit) + " " + unit.shortLocalizedUnitString() + "/U"
        case .correctionRange:
            return values.map { PowerProfiles_Format.glucose($0, unit: unit) }.joined(separator: "–") + " " + unit.shortLocalizedUnitString()
        }
    }

    static func percentText(_ percent: Int) -> String {
        percent > 0 ? "+\(percent)%" : "\(percent)%"
    }

    static func time(_ startTime: TimeInterval) -> String {
        let minutes = Int(startTime) / 60
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
