//
//  DirectConnect_UICoordinator.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//  DirectConnect — Navigation for CGM setup and sensor settings.
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Adapted from LoopKit G7SensorKitUI G7UICoordinator (MIT, © 2022 LoopKit Authors).
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.

import LoopKit
import LoopKitUI
import SwiftUI
import UIKit

final class DirectConnect_UICoordinator: UINavigationController, CGMManagerOnboarding, CompletionNotifying, UINavigationControllerDelegate {
    weak var cgmManagerOnboardingDelegate: CGMManagerOnboardingDelegate?
    weak var completionDelegate: CompletionDelegate?

    private var cgmManager: DirectConnect_G7CGMManager?
    private let colorPalette: LoopUIColorPalette
    private let displayGlucosePreference: DisplayGlucosePreference

    init(cgmManager: DirectConnect_G7CGMManager? = nil, colorPalette: LoopUIColorPalette, displayGlucosePreference: DisplayGlucosePreference) {
        self.cgmManager = cgmManager
        self.colorPalette = colorPalette
        self.displayGlucosePreference = displayGlucosePreference
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
        DirectConnect_G7CGMManager.setDisplayUnit(displayGlucosePreference.unit)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        navigationBar.prefersLargeTitles = true
        setViewControllers([cgmManager == nil ? setupScreen() : statusScreen()], animated: false)
    }

    private func setupScreen() -> UIViewController {
        let view = DirectConnect_SetupView(
            onContinue: { [weak self] type, code in
                self?.completeSetup(type: type, code: code)
            },
            onCancel: { [weak self] in
                guard let self = self else { return }
                self.completionDelegate?.completionNotifyingDidComplete(self)
            })
        let controller = DismissibleHostingController(content: view, colorPalette: colorPalette)
        controller.navigationItem.largeTitleDisplayMode = .never
        return controller
    }

    private func statusScreen() -> UIViewController {
        guard let manager = cgmManager else { return UIViewController() }
        let view = DirectConnect_SensorStatusView(
            viewModel: DirectConnect_SensorStatusViewModel(cgmManager: manager, displayGlucosePreference: displayGlucosePreference),
            didFinish: { [weak self] in
                guard let self = self else { return }
                self.completionDelegate?.completionNotifyingDidComplete(self)
            },
            deleteCGM: { [weak self] in
                manager.delete {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.completionDelegate?.completionNotifyingDidComplete(self)
                        self.dismiss(animated: true)
                    }
                }
            })
        return DismissibleHostingController(content: view, colorPalette: colorPalette)
    }

    private func completeSetup(type: DirectConnect_SensorType, code: String) {
        let manager = DirectConnect_G7CGMManager()
        cgmManager = manager
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didCreateCGMManager: manager)
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didOnboardCGMManager: manager)
        manager.configure(type: type, pairingCode: code)
        // Stay on screen to show search and pairing progress instead of closing immediately.
        setViewControllers([statusScreen()], animated: true)
    }
}
