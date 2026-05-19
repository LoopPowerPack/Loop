//
//  LoopInsights_SubstackPromo.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  Shared UI components for inviting users to subscribe to the PowerPack
//  Substack. Used by every feature's settings view (footer card) and as a
//  one-time onboarding sheet on first launch of the LoopInsights dashboard.
//
//  Implementation note: subscription happens in SFSafariViewController
//  pointed at Substack's normal subscribe page. We never collect emails
//  in-app, never embed admin session cookies, never proxy through any
//  server — Substack's own form does everything. Privacy-respecting,
//  Apple-approved pattern.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import SwiftUI
import SafariServices

// MARK: - Configuration

enum LoopInsights_SubstackPromo {

    /// Substack publication subscribe URL. Used by every UI surface.
    static let subscribeURL = URL(string: "https://taylor256.substack.com/subscribe")!

    /// Publication landing page (used by the "Browse" link).
    static let homeURL = URL(string: "https://taylor256.substack.com")!

    /// UserDefaults key — tracks whether the user has been shown the
    /// onboarding sheet at least once. Sheet auto-presents on first
    /// dashboard appearance, then never again (whether they subscribed or
    /// dismissed).
    static let onboardingShownKey = "PowerPack_HasSeenSubstackOnboarding"

    static var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingShownKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingShownKey) }
    }
}

// MARK: - Footer (always visible at the bottom of every settings view)

/// Compact card that lives at the bottom of each feature's settings view.
/// Tap → opens Substack subscribe page in SFSafariViewController.
struct LoopInsights_SubstackPromoFooter: View {

    @State private var showingSafari = false

    var body: some View {
        Section {
            Button(action: { showingSafari = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "newspaper.fill")
                        .font(.title3)
                        .foregroundColor(Color(red: 26/255, green: 138/255, blue: 158/255))
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("PowerPack writeups on Substack", comment: "Substack footer title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(NSLocalizedString("Free deep-dives on every feature. Tap to subscribe.", comment: "Substack footer subtitle"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingSafari) {
            LoopInsights_SafariView(url: LoopInsights_SubstackPromo.subscribeURL)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Onboarding sheet (first launch only)

/// Full-screen sheet shown ONCE the first time the user opens the
/// LoopInsights dashboard. Persistent dismissal via UserDefaults; subsequent
/// access is via the footer in any settings view.
struct LoopInsights_SubstackOnboardingSheet: View {

    let onDismiss: () -> Void

    @State private var showingSafari = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color(red: 26/255, green: 138/255, blue: 158/255))
                        .padding(.top, 24)

                    Text(NSLocalizedString("Want to know what each feature does, and why?", comment: "Substack onboarding sheet title"))
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        bulletRow(icon: "doc.text.fill",
                                  title: NSLocalizedString("Deep-dive writeups", comment: "Substack onboarding bullet 1 title"),
                                  body: NSLocalizedString("One per feature — FoodFinder, LoopInsights, AutoPresets, BolusPro, SiteAtlas, Meal Debrief. Plus the install-without-a-Mac guide.", comment: "Substack onboarding bullet 1 body"))

                        bulletRow(icon: "chart.bar.doc.horizontal.fill",
                                  title: NSLocalizedString("The receipts posts", comment: "Substack onboarding bullet 2 title"),
                                  body: NSLocalizedString("AI vs human carb counting accuracy (50 meals, kitchen-scale ground truth). AI vs clinical norms on therapy settings (8 windows, my own data, my own endo).", comment: "Substack onboarding bullet 2 body"))

                        bulletRow(icon: "dollarsign.circle.fill",
                                  title: NSLocalizedString("Cost and privacy, with numbers", comment: "Substack onboarding bullet 3 title"),
                                  body: NSLocalizedString("Exactly what runs the AI features per month and exactly what data leaves your device.", comment: "Substack onboarding bullet 3 body"))
                    }
                    .padding(.horizontal)

                    VStack(spacing: 8) {
                        Button(action: {
                            LoopInsights_SubstackPromo.hasSeenOnboarding = true
                            showingSafari = true
                        }) {
                            Text(NSLocalizedString("Subscribe (free)", comment: "Substack onboarding primary CTA"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 26/255, green: 138/255, blue: 158/255))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }

                        Button(action: {
                            LoopInsights_SubstackPromo.hasSeenOnboarding = true
                            onDismiss()
                        }) {
                            Text(NSLocalizedString("Maybe later", comment: "Substack onboarding dismiss"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal)

                    Text(NSLocalizedString("You can always subscribe later from the bottom of any feature's Settings screen.", comment: "Substack onboarding footer note"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingSafari, onDismiss: { onDismiss() }) {
            LoopInsights_SafariView(url: LoopInsights_SubstackPromo.subscribeURL)
                .ignoresSafeArea()
        }
    }

    private func bulletRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(red: 26/255, green: 138/255, blue: 158/255))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - SFSafariViewController SwiftUI wrapper

/// Minimal SwiftUI wrapper around SFSafariViewController. Used by both the
/// footer button and the onboarding sheet's "Subscribe" CTA.
///
/// SFSafariViewController is Apple's blessed pattern for showing web content
/// without leaving the app. It uses Safari's cookie jar, supports Apple ID
/// autofill, and never shares state back with the host app — the user's
/// Substack email never touches PowerPack code.
struct LoopInsights_SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(red: 26/255, green: 138/255, blue: 158/255, alpha: 1.0)
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
