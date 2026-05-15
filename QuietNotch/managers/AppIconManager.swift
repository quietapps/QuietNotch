//
//  AppIconManager.swift
//  QuietNotch
//

import AppKit
import Combine
import Defaults

final class AppIconManager {
    static let shared = AppIconManager()

    private var cancellable: AnyCancellable?

    private init() {}

    func applyCurrentChoice() {
        apply(Defaults[.appIconChoice])
    }

    func startObserving() {
        cancellable = Defaults.publisher(.appIconChoice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.apply(change.newValue)
            }
    }

    func apply(_ choice: AppIconChoice) {
        guard let image = NSImage(named: choice.assetName) else { return }
        NSApplication.shared.applicationIconImage = image
    }
}
