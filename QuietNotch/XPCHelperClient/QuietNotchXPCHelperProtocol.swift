//
//  QuietNotchXPCHelperProtocol.swift
//  QuietNotchXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol QuietNotchXPCHelperProtocol {
    func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void)
    func requestAccessibilityAuthorization()
    func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void)
    // Keyboard backlight / CoreBrightness access (performed by the helper)
    func isKeyboardBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Screen brightness access (performed by the helper).
    // Single-display methods operate on CGMainDisplayID(); per-display
    // methods accept a CGDirectDisplayID (passed as UInt32).
    func isScreenBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    func currentScreenBrightness(forDisplayID displayID: UInt32, with reply: @escaping (NSNumber?) -> Void)
    func setScreenBrightness(_ value: Float, forDisplayID displayID: UInt32, with reply: @escaping (Bool) -> Void)
    func dismissNativeOSD(with reply: @escaping (Bool) -> Void)
}

