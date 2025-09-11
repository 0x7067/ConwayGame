import Foundation
import Vapor

print("Starting Conway API...")

// Try basic Vapor setup
let app = Application(.development)
defer { app.shutdown() }

app.get("hello") { req in
    return "Hello, Conway!"
}

print("API configured, starting server...")
try app.run()