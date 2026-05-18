//  BrightnessManager.swift
//  quietNotch
//
//  Created by JeanLouis on 08/22/24.

import AppKit
import Combine
import Defaults

final class BrightnessManager: ObservableObject {
	static let shared = BrightnessManager()

	@Published private(set) var rawBrightness: Float = 0
	@Published private(set) var animatedBrightness: Float = 0
	@Published private(set) var lastChangeAt: Date = .distantPast

	private let visibleDuration: TimeInterval = 1.2
	private let client = XPCHelperClient.shared

	// Polling state — used to detect brightness changes that bypass the
	// CGEventTap (e.g. real F1/F2 brightness keys on modern macOS, which
	// don't reliably surface as system-defined events to user-space taps).
	// Per-display tracking so a brightness change on a secondary display
	// also surfaces the in-notch HUD instead of just macOS's native one.
	private var pollTimer: Timer?
	private let pollInterval: TimeInterval = 0.15
	private let changeThreshold: Float = 0.005
	// displayID -> last observed brightness on that display.
	private var lastObservedByDisplay: [UInt32: Float] = [:]
	// displayIDs we've seen at least once (baseline established).
	private var primedDisplays: Set<UInt32> = []

	private init() {
		refresh()
		startPolling()
	}

	var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

	func refresh() {
		Task { @MainActor in
			if let current = await client.currentScreenBrightness() {
				publish(brightness: current, touchDate: false)
			}
		}
	}

	@MainActor func setRelative(delta: Float) {
		Task { @MainActor in
			let starting = await client.currentScreenBrightness() ?? rawBrightness
			let target = max(0, min(1, starting + delta))
			let ok = await client.setScreenBrightness(target)
			if ok {
				publish(brightness: target, touchDate: true)
			} else {
				refresh()
			}
			QuietViewCoordinator.shared.toggleSneakPeek(status: true, type: .brightness, value: CGFloat(target))
		}
	}

	func setAbsolute(value: Float) {
		let clamped = max(0, min(1, value))
		Task { @MainActor in
			let ok = await client.setScreenBrightness(clamped)
			if ok {
				publish(brightness: clamped, touchDate: true)
			} else {
				refresh()
			}
		}
	}

	private func publish(brightness: Float, touchDate: Bool) {
		DispatchQueue.main.async {
			if self.rawBrightness != brightness || touchDate {
				if touchDate { self.lastChangeAt = Date() }
				self.rawBrightness = brightness
				self.animatedBrightness = brightness
			}
		}
	}

	// MARK: - Polling for external brightness changes

	private func startPolling() {
		guard pollTimer == nil else { return }
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			let t = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { [weak self] _ in
				self?.pollOnce()
			}
			t.tolerance = self.pollInterval * 0.25
			RunLoop.main.add(t, forMode: .common)
			self.pollTimer = t
		}
	}

	private func pollOnce() {
		// Skip polling entirely when HUD replacement is off — saves the XPC
		// roundtrip cost when the user has the feature disabled.
		guard Defaults[.hudReplacement] else { return }

		// Snapshot the current set of display IDs on the main thread; the
		// async sample loop below can then read each one without touching
		// AppKit off-main.
		let displayIDs: [UInt32] = NSScreen.screens.compactMap { $0.displayID }
		guard !displayIDs.isEmpty else { return }

		Task { @MainActor in
			let mainID = CGMainDisplayID()
			for id in displayIDs {
				guard let current = await client.currentScreenBrightness(forDisplayID: id) else {
					continue
				}
				let prev = lastObservedByDisplay[id]
				lastObservedByDisplay[id] = current

				// First successful read for this display: baseline only.
				if !primedDisplays.contains(id) {
					primedDisplays.insert(id)
					if id == mainID {
						publish(brightness: current, touchDate: false)
					}
					continue
				}

				guard let prev else { continue }

				if abs(current - prev) >= changeThreshold {
					// Mirror main display in our own published value so any
					// in-app UI bound to BrightnessManager stays in sync.
					if id == mainID {
						publish(brightness: current, touchDate: true)
					} else {
						lastChangeAt = Date()
					}
					QuietViewCoordinator.shared.toggleSneakPeek(
						status: true,
						type: .brightness,
						value: CGFloat(current)
					)
					// macOS will have already drawn its native bezel HUD on
					// the changed display (we can't intercept the brightness
					// key event reliably). Kill OSDUIHelper so the native
					// HUD disappears — ours stays. The helper auto-respawns.
					client.dismissNativeOSDFireAndForget()
				} else if id == mainID, rawBrightness != current {
					publish(brightness: current, touchDate: false)
				}
			}
		}
	}
}

// (DisplayServices helpers moved into XPC helper)

// MARK: - Keyboard Backlight Controller
final class KeyboardBacklightManager: ObservableObject {
	static let shared = KeyboardBacklightManager()

	@Published private(set) var rawBrightness: Float = 0
	@Published private(set) var lastChangeAt: Date = .distantPast

	private let visibleDuration: TimeInterval = 1.2
	private let client = XPCHelperClient.shared

	private var pollTimer: Timer?
	private let pollInterval: TimeInterval = 0.15
	private let changeThreshold: Float = 0.005
	private var lastObservedBrightness: Float?
	private var hasPrimedBaseline = false

	private init() {
		refresh()
		startPolling()
	}

	var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

	func refresh() {
		Task { @MainActor in
			if let current = await client.currentKeyboardBrightness() {
				publish(brightness: current, touchDate: false)
			}
		}
	}

	@MainActor func setRelative(delta: Float) {
		Task { @MainActor in
			let starting = await client.currentKeyboardBrightness() ?? rawBrightness
			let target = max(0, min(1, starting + delta))
			let ok = await client.setKeyboardBrightness(target)
			if ok {
				publish(brightness: target, touchDate: true)
			} else {
				refresh()
			}
			QuietViewCoordinator.shared.toggleSneakPeek(
				status: true,
				type: .backlight,
				value: CGFloat(target)
			)
		}
	}

	func setAbsolute(value: Float) {
		let clamped = max(0, min(1, value))
		Task { @MainActor in
			let ok = await client.setKeyboardBrightness(clamped)
			if ok {
				publish(brightness: clamped, touchDate: true)
			} else {
				refresh()
			}
		}
	}

	private func publish(brightness: Float, touchDate: Bool) {
		DispatchQueue.main.async {
			if self.rawBrightness != brightness || touchDate {
				if touchDate { self.lastChangeAt = Date() }
				self.rawBrightness = brightness
			}
		}
	}

	// MARK: - Polling for external backlight changes

	private func startPolling() {
		guard pollTimer == nil else { return }
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			let t = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { [weak self] _ in
				self?.pollOnce()
			}
			t.tolerance = self.pollInterval * 0.25
			RunLoop.main.add(t, forMode: .common)
			self.pollTimer = t
		}
	}

	private func pollOnce() {
		guard Defaults[.hudReplacement] else { return }
		Task { @MainActor in
			guard let current = await client.currentKeyboardBrightness() else { return }
			let prev = lastObservedBrightness
			lastObservedBrightness = current

			guard hasPrimedBaseline else {
				hasPrimedBaseline = true
				publish(brightness: current, touchDate: false)
				return
			}

			guard let prev else {
				publish(brightness: current, touchDate: false)
				return
			}

			if abs(current - prev) >= changeThreshold {
				publish(brightness: current, touchDate: true)
				QuietViewCoordinator.shared.toggleSneakPeek(
					status: true,
					type: .backlight,
					value: CGFloat(current)
				)
				client.dismissNativeOSDFireAndForget()
			} else if rawBrightness != current {
				publish(brightness: current, touchDate: false)
			}
		}
	}
}

