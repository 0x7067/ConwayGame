import Foundation
import Vapor

public final class ConfigurableCORSMiddleware: Middleware {
    private let config: APIConfiguration

    public init(config: APIConfiguration) {
        self.config = config
    }

    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Handle preflight OPTIONS request
        if request.method == .OPTIONS {
            return request.eventLoop.makeSucceededFuture(createCORSResponse(for: request))
        }

        // Chain to next middleware/handler and add CORS headers to response
        return next.respond(to: request).map { response in
            self.addCORSHeaders(to: response, for: request)
            return response
        }
    }

    private func createCORSResponse(for request: Request) -> Response {
        let response = Response(status: .ok)
        addCORSHeaders(to: response, for: request)
        return response
    }

    private func addCORSHeaders(to response: Response, for request: Request) {
        // Set Access-Control-Allow-Origin based on configuration
        if config.corsAllowedOrigins.contains("*") {
            response.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: "*")
        } else {
            // Check if request origin is in allowed list
            if let origin = request.headers.first(name: .origin),
               config.corsAllowedOrigins.contains(origin)
            {
                response.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: origin)
            } else if let firstAllowed = config.corsAllowedOrigins.first {
                // Fallback to first allowed origin if no match
                response.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: firstAllowed)
            }
        }

        // Set other CORS headers
        response.headers.replaceOrAdd(name: .accessControlAllowMethods, value: "GET, POST, OPTIONS")
        response.headers.replaceOrAdd(
            name: .accessControlAllowHeaders,
            value: "Accept, Authorization, Content-Type, Origin, X-Requested-With")
        response.headers.replaceOrAdd(name: .accessControlMaxAge, value: "3600")

        // Add security headers for production
        if config.isProductionCORS {
            response.headers.replaceOrAdd(name: .accessControlAllowCredentials, value: "false")
        }
    }
}
