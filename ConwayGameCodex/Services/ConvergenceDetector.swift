import Foundation

public protocol ConvergenceDetector {
    // Checks convergence against a provided state history set.
    func checkConvergence(_ state: CellsGrid, history: Set<String>) -> ConvergenceType
}

public final class DefaultConvergenceDetector: ConvergenceDetector {
    public init() {}

    public func checkConvergence(_ state: CellsGrid, history: Set<String>) -> ConvergenceType {
        // Extinction
        if isExtinct(state) { return .extinct }
        let hash = BoardHashing.hash(for: state)
        if history.contains(hash) {
            // We cannot precisely compute period without index positions; return generic cycle
            return .cyclical(period: 0)
        }
        return .continuing
    }

    @inline(__always)
    private func isExtinct(_ state: CellsGrid) -> Bool {
        for row in state { if row.contains(true) { return false } }
        return true
    }
}

