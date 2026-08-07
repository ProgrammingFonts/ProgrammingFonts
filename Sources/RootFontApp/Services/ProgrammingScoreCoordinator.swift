import Foundation

@MainActor
final class ProgrammingScoreCoordinator {
    private var debounceTask: Task<Void, Never>?
    private var recalculationTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    func scheduleDebounced(
        delayNanoseconds: UInt64,
        action: @escaping @MainActor () -> Void
    ) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.debounceTask = nil
            action()
        }
    }

    func flushDebounce(action: @escaping @MainActor () -> Void) {
        debounceTask?.cancel()
        debounceTask = nil
        action()
    }

    func schedule(
        calculation: @escaping @Sendable () -> [FontItem],
        apply: @escaping @MainActor ([FontItem]) -> Void,
        completion: @escaping @MainActor () -> Void
    ) {
        generation &+= 1
        let expectedGeneration = generation
        recalculationTask?.cancel()
        recalculationTask = Task { @MainActor [weak self] in
            let updated = await Task.detached(
                priority: .userInitiated,
                operation: calculation
            ).value
            guard let self,
                  !Task.isCancelled,
                  expectedGeneration == self.generation else {
                return
            }
            apply(updated)
            self.recalculationTask = nil
            completion()
        }
    }

    func waitUntilIdle() async {
        if let debounceTask {
            await debounceTask.value
        }
        if let recalculationTask {
            await recalculationTask.value
        }
    }

    func cancel() {
        generation &+= 1
        debounceTask?.cancel()
        debounceTask = nil
        recalculationTask?.cancel()
        recalculationTask = nil
    }
}
