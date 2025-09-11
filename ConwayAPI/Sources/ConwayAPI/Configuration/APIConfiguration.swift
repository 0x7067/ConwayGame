import Foundation
import Vapor

public struct APIConfiguration {
    public let maxGridWidth: Int
    public let maxGridHeight: Int
    public let maxGenerations: Int
    public let corsAllowedOrigins: [String]
    public let apiVersion: String
    public let enableRequestLogging: Bool
    public let enableRateLimiting: Bool
    public let enableMetrics: Bool
    
    public init(
        maxGridWidth: Int = 200,
        maxGridHeight: Int = 200,
        maxGenerations: Int = 1000,
        corsAllowedOrigins: [String] = ["*"],
        apiVersion: String = "1.0.0",
        enableRequestLogging: Bool = true,
        enableRateLimiting: Bool = true,
        enableMetrics: Bool = true
    ) {
        self.maxGridWidth = maxGridWidth
        self.maxGridHeight = maxGridHeight
        self.maxGenerations = maxGenerations
        self.corsAllowedOrigins = corsAllowedOrigins
        self.apiVersion = apiVersion
        self.enableRequestLogging = enableRequestLogging
        self.enableRateLimiting = enableRateLimiting
        self.enableMetrics = enableMetrics
    }
    
    public static func fromEnvironment() -> APIConfiguration {
        let maxGridWidth = Environment.get("MAX_GRID_WIDTH").flatMap(Int.init) ?? 200
        let maxGridHeight = Environment.get("MAX_GRID_HEIGHT").flatMap(Int.init) ?? 200
        let maxGenerations = Environment.get("MAX_GENERATIONS").flatMap(Int.init) ?? 1000
        let apiVersion = Environment.get("API_VERSION") ?? "1.0.0"
        let enableRequestLogging = Environment.get("ENABLE_REQUEST_LOGGING").flatMap(Bool.init) ?? true
        let enableRateLimiting = Environment.get("ENABLE_RATE_LIMITING").flatMap(Bool.init) ?? true
        let enableMetrics = Environment.get("ENABLE_METRICS").flatMap(Bool.init) ?? true
        
        // Parse CORS origins from comma-separated string
        let corsOriginsString = Environment.get("CORS_ALLOWED_ORIGINS") ?? "*"
        let corsAllowedOrigins = corsOriginsString == "*" 
            ? ["*"] 
            : corsOriginsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        return APIConfiguration(
            maxGridWidth: maxGridWidth,
            maxGridHeight: maxGridHeight,
            maxGenerations: maxGenerations,
            corsAllowedOrigins: corsAllowedOrigins,
            apiVersion: apiVersion,
            enableRequestLogging: enableRequestLogging,
            enableRateLimiting: enableRateLimiting,
            enableMetrics: enableMetrics
        )
    }
    
    public var isProductionCORS: Bool {
        return !corsAllowedOrigins.contains("*")
    }
}

// MARK: - Application Extension

extension Application {
    private struct APIConfigurationKey: StorageKey {
        typealias Value = APIConfiguration
    }
    
    public var apiConfiguration: APIConfiguration {
        get {
            self.storage[APIConfigurationKey.self] ?? .fromEnvironment()
        }
        set {
            self.storage[APIConfigurationKey.self] = newValue
        }
    }
}

// MARK: - Request Extension

extension Request {
    public var apiConfiguration: APIConfiguration {
        return application.apiConfiguration
    }
}