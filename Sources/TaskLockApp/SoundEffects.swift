import Foundation
import AppKit

struct SoundEffect: Identifiable, Hashable {
    let id: String
    let displayName: String
    let url: URL
}

@MainActor
final class SoundEffectsLibrary {
    static let shared = SoundEffectsLibrary()

    let effects: [SoundEffect]
    private let lookup: [String: SoundEffect]

    init(bundles: [Bundle] = SoundEffectsLibrary.defaultBundles) {
        let urls = SoundEffectsLibrary.collectAudioURLs(from: bundles)
        let normalizedEffects = SoundEffectsLibrary.buildEffects(from: urls)
        self.effects = normalizedEffects
        self.lookup = Dictionary(uniqueKeysWithValues: normalizedEffects.map { ($0.id, $0) })
    }

    func effect(with id: String) -> SoundEffect? {
        lookup[id]
    }

    private static let defaultBundles: [Bundle] = {
        #if SWIFT_PACKAGE
        return [Bundle.module, Bundle.main]
        #else
        return [Bundle.main]
        #endif
    }()

    private static func collectAudioURLs(from bundles: [Bundle]) -> [URL] {
        var seen = Set<String>()
        var collected: [URL] = []

        func append(_ url: URL) {
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return }
            collected.append(url)
        }

        for bundle in bundles {
            let directMatches = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: "sound_effects") ?? []
            directMatches.forEach(append)

            let rootMatches = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? []
            rootMatches.forEach(append)
        }

        return collected
    }

    private static func buildEffects(from urls: [URL]) -> [SoundEffect] {
        var seen = Set<String>()
        var results: [SoundEffect] = []

        let sorted = urls.sorted { lhs, rhs in
            lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        for url in sorted {
            let rawName = url.deletingPathExtension().lastPathComponent
            let normalizedName = normalizeBaseName(rawName)
            let identifier = makeIdentifier(from: normalizedName)
            guard seen.contains(identifier) == false else { continue }
            seen.insert(identifier)
            let displayName = makeDisplayName(from: normalizedName)
            results.append(SoundEffect(id: identifier, displayName: displayName, url: url))
        }
        let sortedResults = results.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }

        let withFallback: [SoundEffect]
        if sortedResults.isEmpty, let fallback = defaultFallbackURL() {
            withFallback = [SoundEffect(id: FocusStorage.defaultSoundEffectID, displayName: "Sound 10", url: fallback)]
        } else {
            withFallback = sortedResults
        }

        let noneEffect = SoundEffect(id: "none", displayName: "None", url: URL(fileURLWithPath: "/dev/null"))
        return [noneEffect] + withFallback
    }

    private static func defaultFallbackURL() -> URL? {
        for bundle in defaultBundles {
            if let url = bundle.url(
                forResource: "sound-10",
                withExtension: "mp3",
                subdirectory: "sound_effects"
            ) ?? bundle.url(forResource: "sound-10", withExtension: "mp3", subdirectory: nil) {
                return url
            }
        }
        return nil
    }

    private static func normalizeBaseName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\s*\(\d+\)$"#
        if let range = trimmed.range(of: pattern, options: .regularExpression) {
            return String(trimmed[..<range.lowerBound])
        }
        return trimmed
    }

    private static func makeIdentifier(from name: String) -> String {
        let lowered = name.lowercased()
        let cleaned = lowered.replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: "_",
            options: .regularExpression
        )
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "sound" : trimmed
    }

    private static func makeDisplayName(from name: String) -> String {
        let replaced = name.replacingOccurrences(
            of: #"[_-]+"#,
            with: " ",
            options: .regularExpression
        )
        let trimmed = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "Sound" }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("sound") {
            let suffixStart = trimmed.index(trimmed.startIndex, offsetBy: "sound".count, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
            let suffix = trimmed[suffixStart...].trimmingCharacters(in: .whitespaces)
            return suffix.isEmpty ? "Sound" : "Sound \(suffix)"
        }

        return trimmed.capitalized
    }
}

@MainActor
final class SoundEffectPlayer {
    private let library: SoundEffectsLibrary
    private var sounds: [String: NSSound] = [:]

    init(library: SoundEffectsLibrary = .shared) {
        self.library = library
    }

    func prepare(effectID: String) {
        _ = sound(for: effectID)
    }

    func play(effectID: String) {
        guard let sound = sound(for: effectID) else { return }
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }

    private func sound(for effectID: String) -> NSSound? {
        if let cached = sounds[effectID] {
            return cached
        }
        guard let effect = library.effect(with: effectID), effect.id != "none" else {
            return nil
        }

        if effect.url.isFileURL == false {
            return nil
        }

        guard let sound = NSSound(contentsOf: effect.url, byReference: true) else {
            return nil
        }
        sound.loops = false
        sounds[effectID] = sound
        return sound
    }
}
