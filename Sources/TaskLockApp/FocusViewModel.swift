import SwiftUI
import Combine
import CoreGraphics

@MainActor
final class FocusViewModel: ObservableObject {
    @Published var focusText: String {
        didSet {
            guard oldValue != focusText else { return }
            scheduleFocusTextSave()
        }
    }

    @Published var pulseInterval: TimeInterval {
        didSet {
            guard oldValue != pulseInterval else { return }
            storage.savePulseInterval(pulseInterval)
            if isPulseActive {
                pulseController.schedule(interval: pulseInterval)
            }
        }
    }
    @Published var selectedSoundEffectID: String {
        didSet {
            guard oldValue != selectedSoundEffectID else { return }
            let resolvedID = resolveSoundEffectID(selectedSoundEffectID)
            if resolvedID != selectedSoundEffectID {
                selectedSoundEffectID = resolvedID
                return
            }
            storage.saveSoundEffectID(resolvedID)
            soundPlayer.prepare(effectID: resolvedID)
        }
    }
    @Published var pulseIntensity: CGFloat {
        didSet {
            guard oldValue != pulseIntensity else { return }
            storage.savePulseIntensity(pulseIntensity)
        }
    }
    @Published var pulseRange: CGFloat {
        didSet {
            guard oldValue != pulseRange else { return }
            storage.savePulseRange(pulseRange)
        }
    }
    @Published private(set) var soundEffects: [SoundEffect]

    @Published private(set) var pulseEventID = UUID()
    @Published private(set) var viewHeight: CGFloat = Layout.defaultWindowHeight
    @Published var isEditing: Bool = true {
        didSet {
            guard oldValue != isEditing else { return }
            if isEditing {
                requestedEditorFocusID = UUID()
            } else {
                requestedEditorBlurID = UUID()
            }
        }
    }
    @Published private(set) var requestedEditorFocusID = UUID()
    @Published private(set) var requestedEditorBlurID = UUID()

    private let storage: FocusStorageProtocol
    private let pulseController: PulseControlling
    private let soundPlayer: SoundEffectPlayer
    private let soundLibrary: SoundEffectsLibrary
    private var cancellables = Set<AnyCancellable>()
    private(set) var savedTextHeight: CGFloat
    private var hasHandledInitialPulse = false
    private var isPulseActive = true
    private var isInStartupPhase = true
    private var focusTextSaveTask: Task<Void, Never>?
    private var windowPositionSaveTask: Task<Void, Never>?
    private var pendingWindowOrigin: CGPoint?
    private enum PersistenceDebounce {
        static let focusText: UInt64 = 300_000_000 // 300ms
        static let windowPosition: UInt64 = 350_000_000 // 350ms
    }

    init(
        storage: FocusStorageProtocol = FocusStorage(),
        pulseController: PulseControlling = PulseController(),
        soundLibrary: SoundEffectsLibrary = .shared,
        soundPlayer: SoundEffectPlayer? = nil
    ) {
        self.storage = storage
        self.pulseController = pulseController
        self.soundLibrary = soundLibrary
        self.soundEffects = soundLibrary.effects
        let player = soundPlayer ?? SoundEffectPlayer(library: soundLibrary)
        self.soundPlayer = player
        self.focusText = storage.focusText
        self.pulseInterval = storage.pulseInterval
        self.pulseIntensity = storage.pulseIntensity
        self.pulseRange = storage.pulseRange
        self.savedTextHeight = Layout.clampTextHeight(storage.textHeight)
        let estimatedHeight = Layout.estimatedWindowHeight(forTextHeight: self.savedTextHeight)
        let storedWindowHeight = storage.storedWindowHeight ?? estimatedHeight
        self.viewHeight = Layout.clampWindowHeight(storedWindowHeight)
        let storedSoundID = storage.soundEffectID
        let resolvedSoundID = soundLibrary.effect(with: storedSoundID)?.id
            ?? soundLibrary.effect(with: FocusStorage.defaultSoundEffectID)?.id
            ?? soundLibrary.effects.first?.id
            ?? FocusStorage.defaultSoundEffectID
        self.selectedSoundEffectID = resolvedSoundID

        requestedEditorFocusID = UUID()

        pulseController.pulsePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] identifier in
                guard let self else { return }
                self.pulseEventID = identifier
                if self.hasHandledInitialPulse {
                    self.soundPlayer.play(effectID: self.selectedSoundEffectID)
                } else {
                    self.hasHandledInitialPulse = true
                }
            }
            .store(in: &cancellables)

        pulseController.schedule(interval: pulseInterval)
        pulseController.triggerNow()
        if resolvedSoundID != storedSoundID {
            storage.saveSoundEffectID(resolvedSoundID)
        }
        player.prepare(effectID: resolvedSoundID)
    }

    deinit {
        focusTextSaveTask?.cancel()
        windowPositionSaveTask?.cancel()
    }

    func updateContentHeight(_ rawHeight: CGFloat) {
        let clamped = Layout.clampWindowHeight(rawHeight)
        guard abs(clamped - viewHeight) > 0.5 else { return }
        viewHeight = clamped

        if !isInStartupPhase {
            storage.saveWindowHeight(clamped)
        }
    }

    func updateTextHeightCache(_ rawHeight: CGFloat) {
        let clamped = Layout.clampTextHeight(rawHeight)
        guard abs(clamped - savedTextHeight) > 0.5 else { return }
        savedTextHeight = clamped
        storage.saveTextHeight(clamped)
    }

    func resetDefaults() {
        pulseInterval = FocusStorage.defaultPulseInterval
        pulseIntensity = FocusStorage.defaultPulseIntensity
        pulseRange = FocusStorage.defaultPulseRange
        selectedSoundEffectID = resolveSoundEffectID(FocusStorage.defaultSoundEffectID)
        focusText = FocusStorage.defaultFocusText
    }

    func commitEditing() {
        guard isEditing else { return }
        withAnimation(Layout.Animation.editingTransition) {
            isEditing = false
        }
        flushPendingFocusTextSave()
    }

    func beginEditing() {
        guard isEditing == false else { return }
        withAnimation(Layout.Animation.editingTransition) {
            isEditing = true
        }
    }

    func previewSelectedSound() {
        soundPlayer.play(effectID: selectedSoundEffectID)
    }

    func saveWindowPosition(x: CGFloat, y: CGFloat) {
        pendingWindowOrigin = CGPoint(x: x, y: y)
        scheduleWindowPositionSave()
    }

    var windowOriginX: CGFloat? {
        storage.windowOriginX
    }

    var windowOriginY: CGFloat? {
        storage.windowOriginY
    }

    func endStartupPhase() {
        isInStartupPhase = false
    }

    func setPulseActive(_ isActive: Bool) {
        guard isPulseActive != isActive else { return }
        isPulseActive = isActive
        if isActive {
            pulseController.schedule(interval: pulseInterval)
            pulseController.triggerNow()
        } else {
            pulseController.cancel()
            hasHandledInitialPulse = false
        }
    }

    private func resolveSoundEffectID(_ candidate: String) -> String {
        if let match = soundLibrary.effect(with: candidate)?.id {
            return match
        }
        if let fallback = soundLibrary.effect(with: FocusStorage.defaultSoundEffectID)?.id {
            return fallback
        }
        return soundLibrary.effects.first?.id ?? FocusStorage.defaultSoundEffectID
    }

    private func scheduleFocusTextSave() {
        let textToSave = focusText
        focusTextSaveTask?.cancel()
        focusTextSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: PersistenceDebounce.focusText)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                self?.persistFocusText(textToSave)
            }
        }
    }

    private func flushPendingFocusTextSave() {
        focusTextSaveTask?.cancel()
        focusTextSaveTask = nil
        persistFocusText(focusText)
    }

    @MainActor
    private func persistFocusText(_ text: String) {
        storage.saveFocusText(text)
    }

    private func scheduleWindowPositionSave() {
        windowPositionSaveTask?.cancel()
        windowPositionSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: PersistenceDebounce.windowPosition)
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                self?.persistPendingWindowOrigin()
            }
        }
    }

    @MainActor
    private func persistPendingWindowOrigin() {
        guard let pendingWindowOrigin else { return }
        self.pendingWindowOrigin = nil
        storage.saveWindowOriginX(pendingWindowOrigin.x)
        storage.saveWindowOriginY(pendingWindowOrigin.y)
    }
}
