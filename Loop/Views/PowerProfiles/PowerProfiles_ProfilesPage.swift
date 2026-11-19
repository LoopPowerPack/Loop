//
//  PowerProfiles_ProfilesPage.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — The Profiles page as Settings opens it: a PowerProfiles bar
//  (on/off switch, and an Open button when on) above the unchanged Profiles
//  list, so the Profiles files from Loop and Learn need no edits.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import SwiftUI
import LoopKitUI

struct PowerProfiles_ProfilesPage: View {

    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @AppStorage(PowerProfiles_FeatureFlags.Keys.isEnabled) private var isEnabled = false
    @State private var showPowerProfiles = false

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            powerProfilesBar
            ProfileView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPowerProfiles, onDismiss: { viewModel.loadProfiles() }) {
            PowerProfiles_View(viewModel: PowerProfiles_ViewModel(profileViewModel: viewModel))
                .environmentObject(displayGlucosePreference)
        }
    }

    private var powerProfilesBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(PowerProfiles_View.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("PowerProfiles").font(.headline).foregroundColor(PowerProfiles_View.purple)
                Text(NSLocalizedString("Change settings by a percentage", comment: "PowerProfiles bar subtitle"))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isEnabled {
                Button(NSLocalizedString("Open", comment: "Button that opens PowerProfiles")) {
                    showPowerProfiles = true
                }
                .buttonStyle(.bordered)
                .tint(PowerProfiles_View.purple)
            }
            Toggle(NSLocalizedString("PowerProfiles", comment: "PowerProfiles on/off switch"), isOn: $isEnabled)
                .labelsHidden()
                .tint(PowerProfiles_View.purple)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(Rectangle().frame(height: 1).foregroundColor(PowerProfiles_View.purple.opacity(0.4)), alignment: .bottom)
    }
}
