import ConwayGameEngine
import Foundation
import Vapor

// MARK: - Application Bootstrap

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = try await Application.make(env)
defer { Task { try await app.asyncShutdown() } }

// Configure the application
try configure(app)

// Start the server
try await app.execute()
