import Foundation

/// Utility for creating delayed async tasks with cleaner syntax
enum DelayedTask {
    /// Creates a task that executes an action after a delay in milliseconds
    @MainActor
    @discardableResult
    static func after(
        milliseconds: UInt64,
        action: @MainActor @escaping () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    /// Creates a task that executes an action after a delay in nanoseconds
    @MainActor
    @discardableResult
    static func after(
        nanoseconds: UInt64,
        action: @MainActor @escaping () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
