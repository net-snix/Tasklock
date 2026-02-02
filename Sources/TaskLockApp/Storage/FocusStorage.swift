import Foundation
import CoreGraphics

// MARK: - Protocol

protocol FocusStorageProtocol {
    var focusText: String { get }
    var pulseInterval: TimeInterval { get }
    var pulseIntensity: CGFloat { get }
    var pulseRange: CGFloat { get }
    var soundEffectID: String { get }
    var storedWindowHeight: CGFloat? { get }
    var textHeight: CGFloat { get }
    var windowOriginX: CGFloat? { get }
    var windowOriginY: CGFloat? { get }

    func saveFocusText(_ text: String)
    func savePulseInterval(_ interval: TimeInterval)
    func savePulseIntensity(_ intensity: CGFloat)
    func savePulseRange(_ range: CGFloat)
    func saveSoundEffectID(_ identifier: String)
    func saveWindowHeight(_ height: CGFloat)
    func saveTextHeight(_ height: CGFloat)
    func saveWindowOriginX(_ x: CGFloat)
    func saveWindowOriginY(_ y: CGFloat)
}

// MARK: - Implementation

struct FocusStorage: FocusStorageProtocol {
    private enum Keys {
        static let pulseInterval = "pulseInterval"
        static let pulseIntensity = "pulseIntensity"
        static let soundEffectID = "soundEffectID"
        static let windowHeight = "windowHeight"
        static let textHeight = "textHeight"
        static let focusText = "focusText"
        static let windowOriginX = "windowOriginX"
        static let windowOriginY = "windowOriginY"
        static let pulseRange = "pulseRange"
    }

    static let defaultFocusText = "Stay locked in."
    static let defaultPulseInterval: TimeInterval = 60
    static let defaultPulseIntensity: CGFloat = 1.0
    static let defaultPulseRange: CGFloat = 0.5
    static let defaultSoundEffectID = "sound_10"
    static let defaultWindowHeight: CGFloat = Layout.defaultWindowHeight
    static let defaultTextHeight: CGFloat = Layout.minTextHeight

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var pulseInterval: TimeInterval {
        let stored = defaults.double(forKey: Keys.pulseInterval)
        return stored > 0 ? stored : Self.defaultPulseInterval
    }

    func savePulseInterval(_ interval: TimeInterval) {
        defaults.set(interval, forKey: Keys.pulseInterval)
    }

    var pulseIntensity: CGFloat {
        let stored = defaults.double(forKey: Keys.pulseIntensity)
        return stored > 0 ? CGFloat(stored) : Self.defaultPulseIntensity
    }

    func savePulseIntensity(_ intensity: CGFloat) {
        defaults.set(Double(intensity), forKey: Keys.pulseIntensity)
    }

    var pulseRange: CGFloat {
        let stored = defaults.double(forKey: Keys.pulseRange)
        return stored >= 0 && defaults.object(forKey: Keys.pulseRange) != nil
            ? CGFloat(stored)
            : Self.defaultPulseRange
    }

    func savePulseRange(_ range: CGFloat) {
        defaults.set(Double(range), forKey: Keys.pulseRange)
    }

    var soundEffectID: String {
        defaults.string(forKey: Keys.soundEffectID) ?? Self.defaultSoundEffectID
    }

    func saveSoundEffectID(_ identifier: String) {
        defaults.set(identifier, forKey: Keys.soundEffectID)
    }

    var storedWindowHeight: CGFloat? {
        guard defaults.object(forKey: Keys.windowHeight) != nil else { return nil }
        let stored = defaults.double(forKey: Keys.windowHeight)
        guard stored > 0 else { return nil }
        return CGFloat(stored)
    }

    func saveWindowHeight(_ height: CGFloat) {
        defaults.set(Double(height), forKey: Keys.windowHeight)
    }

    var textHeight: CGFloat {
        let stored = defaults.double(forKey: Keys.textHeight)
        return stored > 0 ? CGFloat(stored) : Self.defaultTextHeight
    }

    func saveTextHeight(_ height: CGFloat) {
        defaults.set(Double(height), forKey: Keys.textHeight)
    }

    var focusText: String {
        defaults.string(forKey: Keys.focusText) ?? Self.defaultFocusText
    }

    func saveFocusText(_ text: String) {
        defaults.set(text, forKey: Keys.focusText)
    }

    var windowOriginX: CGFloat? {
        guard defaults.object(forKey: Keys.windowOriginX) != nil else { return nil }
        return CGFloat(defaults.double(forKey: Keys.windowOriginX))
    }

    func saveWindowOriginX(_ x: CGFloat) {
        defaults.set(Double(x), forKey: Keys.windowOriginX)
    }

    var windowOriginY: CGFloat? {
        guard defaults.object(forKey: Keys.windowOriginY) != nil else { return nil }
        return CGFloat(defaults.double(forKey: Keys.windowOriginY))
    }

    func saveWindowOriginY(_ y: CGFloat) {
        defaults.set(Double(y), forKey: Keys.windowOriginY)
    }
}
