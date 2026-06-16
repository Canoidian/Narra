import Foundation

func runWithTimeout<T>(
    timeout: Duration,
    operation: @escaping @Sendable () async throws -> T
) async -> T? {
    await withTaskGroup(of: TimeoutOutcome<T>.self) { group in
        group.addTask {
            do {
                return .value(try await operation())
            } catch {
                return .fallback
            }
        }

        group.addTask {
            _ = try? await Task.sleep(for: timeout)
            return .fallback
        }

        let firstResult = await group.next() ?? .fallback
        group.cancelAll()

        switch firstResult {
        case .value(let value):
            return value
        case .fallback:
            return nil
        }
    }
}

// `T` is allowed to be non-Sendable. The outcome enum carries the value
// across the task-group boundary, but each instance is produced by one
// child task and consumed exactly once by the parent via `group.next()`
// — there is no concurrent access, so the @unchecked annotation is safe.
private enum TimeoutOutcome<T>: @unchecked Sendable {
    case value(T)
    case fallback
}
