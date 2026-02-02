import Foundation
import Combine

// MARK: - Protocol

protocol PulseControlling {
    var pulsePublisher: AnyPublisher<UUID, Never> { get }
    func schedule(interval: TimeInterval)
    func triggerNow()
    func cancel()
}

// MARK: - Implementation

final class PulseController: PulseControlling {
    private let subject = PassthroughSubject<UUID, Never>()
    private var timerCancellable: AnyCancellable?

    var pulsePublisher: AnyPublisher<UUID, Never> {
        subject.eraseToAnyPublisher()
    }

    func schedule(interval: TimeInterval) {
        timerCancellable?.cancel()
        guard interval > 0 else { return }
        timerCancellable = Timer
            .publish(
                every: interval,
                tolerance: min(2, interval * 0.05),
                on: .main,
                in: .common
            )
            .autoconnect()
            .sink { [weak self] _ in
                self?.subject.send(UUID())
            }
    }

    func triggerNow() {
        subject.send(UUID())
    }

    func cancel() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
