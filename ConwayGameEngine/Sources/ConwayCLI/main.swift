import Foundation
import ConwayGameEngine

struct ConwayCLI {
    static func main() async throws {
        let args = CommandLine.arguments
        
        if args.count < 2 {
            printUsage()
            return
        }
        
        let command = args[1]
        
        switch command {
        case "run":
            try await runSimulation(args: Array(args.dropFirst(2)))
        case "pattern":
            try await runPattern(args: Array(args.dropFirst(2)))
        case "help", "--help", "-h":
            printUsage()
        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }
    
    private static func printUsage() {
        print("""
        Conway's Game of Life CLI
        
        USAGE:
            conway-cli <command> [options]
        
        COMMANDS:
            run <width> <height> <generations> [pattern]
                Run a simulation with specified dimensions and generations
                Optional pattern: random, empty, or pattern name
        
            pattern <name>
                Run a predefined pattern simulation
        
        EXAMPLES:
            conway-cli run 20 20 50 random
            conway-cli run 10 10 25 empty  
            conway-cli pattern glider
        """)
    }
    
    private static func runSimulation(args: [String]) async throws {
        guard args.count >= 3 else {
            print("Error: run command requires width, height, and generations")
            printUsage()
            return
        }
        
        guard let width = Int(args[0]),
              let height = Int(args[1]),
              let generations = Int(args[2]),
              width > 0, height > 0, generations >= 0 else {
            print("Error: Invalid dimensions or generation count")
            return
        }
        
        let patternType = args.count > 3 ? args[3] : "random"
        let initialGrid = createGrid(width: width, height: height, pattern: patternType)
        
        let engine = ConwayGameEngine()
        let detector = DefaultConvergenceDetector()
        
        print("Starting Conway's Game of Life simulation")
        print("Dimensions: \(width)x\(height), Generations: \(generations)")
        print("Initial pattern: \(patternType)")
        print("─" * 50)
        
        var currentGrid = initialGrid
        var history: Set<String> = []
        
        // Show initial state
        print("Generation 0:")
        print(currentGrid.toString())
        print("Population: \(currentGrid.population)")
        print()
        
        for generation in 1...generations {
            let nextGrid = engine.computeNextState(currentGrid)
            let convergence = detector.checkConvergence(nextGrid, history: history)
            
            history.insert(BoardHashing.hash(for: currentGrid))
            currentGrid = nextGrid
            
            print("Generation \(generation):")
            print(currentGrid.toString())
            print("Population: \(currentGrid.population)")
            
            switch convergence {
            case .extinct:
                print("🪦 Game ended - all cells died (extinction)")
                return
            case .cyclical(let period):
                print("🔄 Game ended - pattern is cyclical (period: \(period))")
                return
            case .continuing:
                break
            }
            
            if generation < generations {
                print()
                // Add small delay for better visualization
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }
        
        print("✅ Simulation completed after \(generations) generations")
    }
    
    private static func runPattern(args: [String]) async throws {
        guard args.count >= 1 else {
            print("Error: pattern command requires a pattern name")
            print("Available patterns: \(Pattern.allCases.map(\.rawValue).joined(separator: ", "))")
            return
        }
        
        let patternName = args[0]
        guard let pattern = Pattern.named(patternName) else {
            print("Error: Unknown pattern '\(patternName)'")
            print("Available patterns: \(Pattern.allCases.map(\.rawValue).joined(separator: ", "))")
            return
        }
        
        print("Running pattern: \(pattern.displayName)")
        print("Description: \(pattern.description)")
        print("─" * 50)
        
        let engine = ConwayGameEngine()
        var currentGrid = pattern.cells
        
        print("Generation 0:")
        print(currentGrid.toString())
        print("Population: \(currentGrid.population)")
        print()
        
        // Run for a reasonable number of generations to show the pattern behavior
        let maxGenerations = 50
        for generation in 1...maxGenerations {
            let nextGrid = engine.computeNextState(currentGrid)
            
            // Check if pattern has stabilized (no changes)
            if nextGrid as AnyObject === currentGrid as AnyObject {
                print("🎯 Pattern stabilized at generation \(generation)")
                break
            }
            
            currentGrid = nextGrid
            
            if generation <= 10 || generation % 5 == 0 {
                print("Generation \(generation):")
                print(currentGrid.toString())
                print("Population: \(currentGrid.population)")
                print()
            }
            
            // Small delay for visualization
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    private static func createGrid(width: Int, height: Int, pattern: String) -> CellsGrid {
        switch pattern.lowercased() {
        case "empty":
            return CellsGrid.empty(width: width, height: height)
        case "random":
            return generateRandomGrid(width: width, height: height)
        default:
            // Try to get a predefined pattern, fallback to random
            if let patternEnum = Pattern.named(pattern) {
                return patternEnum.cells
            } else {
                print("Warning: Unknown pattern '\(pattern)', using random instead")
                return generateRandomGrid(width: width, height: height)
            }
        }
    }
    
    private static func generateRandomGrid(width: Int, height: Int) -> CellsGrid {
        let density = 0.3 // 30% chance of cell being alive
        return (0..<height).map { _ in
            (0..<width).map { _ in
                Double.random(in: 0...1) < density
            }
        }
    }
}

// MARK: - String Extension for Repetition
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// Entry point
try await ConwayCLI.main()