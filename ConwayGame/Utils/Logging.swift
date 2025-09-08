import OSLog

extension Logger {
    static let gameEngine = Logger(subsystem: "ConwayGame", category: "GameEngine")
    static let persistence = Logger(subsystem: "ConwayGame", category: "Persistence")
    static let service = Logger(subsystem: "ConwayGame", category: "Service")
}

