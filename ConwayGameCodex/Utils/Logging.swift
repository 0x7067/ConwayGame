import OSLog

extension Logger {
    static let gameEngine = Logger(subsystem: "ConwayGameCodex", category: "GameEngine")
    static let persistence = Logger(subsystem: "ConwayGameCodex", category: "Persistence")
    static let service = Logger(subsystem: "ConwayGameCodex", category: "Service")
}

