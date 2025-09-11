import Foundation
import Vapor

public final class RateLimitingMiddleware: AsyncMiddleware {
    private let config: RateLimitConfiguration
    private let storage: RateLimitStorage
    
    public init(config: RateLimitConfiguration, storage: RateLimitStorage = InMemoryRateLimitStorage()) {
        self.config = config
        self.storage = storage
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let clientIP = getClientIP(from: request)
        let endpoint = getEndpointKey(from: request)
        let key = "\(clientIP):\(endpoint)"
        
        // Get appropriate limits for this endpoint
        let limits = config.limitsForEndpoint(endpoint)
        
        // Check rate limit
        let rateLimitInfo = await storage.checkRateLimit(
            key: key,
            windowSize: limits.windowSize,
            maxRequests: limits.maxRequests
        )
        
        // Add rate limit headers to response
        let response: Response
        if rateLimitInfo.isAllowed {
            response = try await next.respond(to: request)
        } else {
            response = Response(status: .tooManyRequests)
            try response.content.encode(RateLimitExceededResponse(
                error: "Rate limit exceeded",
                message: "Too many requests. Try again later.",
                retryAfter: rateLimitInfo.resetTime
            ))
            response.headers.contentType = .json
        }
        
        // Add rate limiting headers
        response.headers.replaceOrAdd(name: "X-RateLimit-Limit", value: "\(limits.maxRequests)")
        response.headers.replaceOrAdd(name: "X-RateLimit-Remaining", value: "\(rateLimitInfo.remaining)")
        response.headers.replaceOrAdd(name: "X-RateLimit-Reset", value: "\(rateLimitInfo.resetTime)")
        
        return response
    }
    
    private func getClientIP(from request: Request) -> String {
        // Check for forwarded headers first (for load balancers/proxies)
        if let forwardedFor = request.headers.first(name: "X-Forwarded-For") {
            return forwardedFor.split(separator: ",").first?.trimmingCharacters(in: .whitespaces) ?? "unknown"
        }
        
        if let realIP = request.headers.first(name: "X-Real-IP") {
            return realIP
        }
        
        // Fallback to remote address
        return request.remoteAddress?.hostname ?? "unknown"
    }
    
    private func getEndpointKey(from request: Request) -> String {
        let path = request.url.path
        
        // Classify endpoints into categories for different rate limits
        if path.hasPrefix("/api/game/simulate") {
            return "game.simulate"
        } else if path.hasPrefix("/api/game/") {
            return "game.general"
        } else if path.hasPrefix("/api/patterns") {
            return "patterns"
        } else if path.hasPrefix("/api/rules") {
            return "rules"
        } else if path == "/health" {
            return "health"
        } else {
            return "general"
        }
    }
}

// MARK: - Rate Limit Configuration

public struct RateLimitConfiguration {
    public let defaultLimits: RateLimits
    public let endpointLimits: [String: RateLimits]
    
    public init(
        defaultLimits: RateLimits = RateLimits(maxRequests: 100, windowSize: 60),
        endpointLimits: [String: RateLimits] = [:]
    ) {
        self.defaultLimits = defaultLimits
        self.endpointLimits = endpointLimits
    }
    
    public func limitsForEndpoint(_ endpoint: String) -> RateLimits {
        return endpointLimits[endpoint] ?? defaultLimits
    }
    
    public static func fromEnvironment() -> RateLimitConfiguration {
        let defaultMaxRequests = Environment.get("RATE_LIMIT_DEFAULT_MAX").flatMap(Int.init) ?? 100
        let defaultWindowSize = Environment.get("RATE_LIMIT_DEFAULT_WINDOW").flatMap(TimeInterval.init) ?? 60
        
        // Stricter limits for compute-intensive endpoints
        let simulateMaxRequests = Environment.get("RATE_LIMIT_SIMULATE_MAX").flatMap(Int.init) ?? 20
        let simulateWindowSize = Environment.get("RATE_LIMIT_SIMULATE_WINDOW").flatMap(TimeInterval.init) ?? 60
        
        let gameMaxRequests = Environment.get("RATE_LIMIT_GAME_MAX").flatMap(Int.init) ?? 50
        let gameWindowSize = Environment.get("RATE_LIMIT_GAME_WINDOW").flatMap(TimeInterval.init) ?? 60
        
        // More lenient limits for read-only endpoints
        let healthMaxRequests = Environment.get("RATE_LIMIT_HEALTH_MAX").flatMap(Int.init) ?? 300
        let healthWindowSize = Environment.get("RATE_LIMIT_HEALTH_WINDOW").flatMap(TimeInterval.init) ?? 60
        
        return RateLimitConfiguration(
            defaultLimits: RateLimits(maxRequests: defaultMaxRequests, windowSize: defaultWindowSize),
            endpointLimits: [
                "game.simulate": RateLimits(maxRequests: simulateMaxRequests, windowSize: simulateWindowSize),
                "game.general": RateLimits(maxRequests: gameMaxRequests, windowSize: gameWindowSize),
                "patterns": RateLimits(maxRequests: gameMaxRequests, windowSize: gameWindowSize),
                "rules": RateLimits(maxRequests: gameMaxRequests, windowSize: gameWindowSize),
                "health": RateLimits(maxRequests: healthMaxRequests, windowSize: healthWindowSize)
            ]
        )
    }
}

public struct RateLimits {
    public let maxRequests: Int
    public let windowSize: TimeInterval
    
    public init(maxRequests: Int, windowSize: TimeInterval) {
        self.maxRequests = maxRequests
        self.windowSize = windowSize
    }
}

// MARK: - Rate Limit Storage

public protocol RateLimitStorage {
    func checkRateLimit(key: String, windowSize: TimeInterval, maxRequests: Int) async -> RateLimitInfo
}

public struct RateLimitInfo {
    public let isAllowed: Bool
    public let remaining: Int
    public let resetTime: Int
    
    public init(isAllowed: Bool, remaining: Int, resetTime: Int) {
        self.isAllowed = isAllowed
        self.remaining = remaining
        self.resetTime = resetTime
    }
}

public actor InMemoryRateLimitStorage: RateLimitStorage {
    private var requestCounts: [String: [TimeInterval]] = [:]
    
    public init() {}
    
    public func checkRateLimit(key: String, windowSize: TimeInterval, maxRequests: Int) async -> RateLimitInfo {
        let now = Date().timeIntervalSince1970
        let windowStart = now - windowSize
        
        // Clean old entries and get current count
        var timestamps = requestCounts[key] ?? []
        timestamps = timestamps.filter { $0 > windowStart }
        
        let currentCount = timestamps.count
        let isAllowed = currentCount < maxRequests
        
        if isAllowed {
            // Add current request
            timestamps.append(now)
            requestCounts[key] = timestamps
        }
        
        let remaining = max(0, maxRequests - (isAllowed ? currentCount + 1 : currentCount))
        let resetTime = Int(windowStart + windowSize)
        
        return RateLimitInfo(
            isAllowed: isAllowed,
            remaining: remaining,
            resetTime: resetTime
        )
    }
}

// MARK: - Response Models

struct RateLimitExceededResponse: Content {
    let error: String
    let message: String
    let retryAfter: Int
    let timestamp: Date
    
    init(error: String, message: String, retryAfter: Int) {
        self.error = error
        self.message = message
        self.retryAfter = retryAfter
        self.timestamp = Date()
    }
}

// MARK: - Application Extension

extension Application {
    private struct RateLimitConfigurationKey: StorageKey {
        typealias Value = RateLimitConfiguration
    }
    
    public var rateLimitConfiguration: RateLimitConfiguration {
        get {
            self.storage[RateLimitConfigurationKey.self] ?? .fromEnvironment()
        }
        set {
            self.storage[RateLimitConfigurationKey.self] = newValue
        }
    }
}