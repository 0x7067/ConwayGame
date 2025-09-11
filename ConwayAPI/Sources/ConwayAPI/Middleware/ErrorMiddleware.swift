import Foundation
import Vapor

struct APIErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Generate correlation ID for this request
        let correlationId = UUID().uuidString.lowercased()
        request.storage[CorrelationIDKey.self] = correlationId
        
        do {
            let response = try await next.respond(to: request)
            // Add correlation ID to successful responses
            response.headers.replaceOrAdd(name: "X-Correlation-ID", value: correlationId)
            return response
        } catch {
            let errorResponse = try await handleError(error, for: request)
            // Add correlation ID to error responses
            errorResponse.headers.replaceOrAdd(name: "X-Correlation-ID", value: correlationId)
            return errorResponse
        }
    }
    
    private func handleError(_ error: Error, for request: Request) async throws -> Response {
        let status: HTTPResponseStatus
        let errorResponse: ErrorResponse
        
        switch error {
        case let abort as AbortError:
            status = abort.status
            errorResponse = ErrorResponse(
                error: abort.status.reasonPhrase,
                message: abort.reason
            )
            
        case let decodingError as DecodingError:
            status = .badRequest
            errorResponse = ErrorResponse(
                error: "DecodingError",
                message: decodingErrorMessage(decodingError)
            )
            
        case let validationError as GridValidationError:
            status = .badRequest
            errorResponse = ErrorResponse(
                error: "ValidationError",
                message: validationError.localizedDescription
            )
            
        default:
            status = .internalServerError
            errorResponse = ErrorResponse(
                error: "InternalServerError",
                message: "An unexpected error occurred"
            )
            
            // Log the actual error for debugging with correlation ID
            let correlationId = request.storage[CorrelationIDKey.self] ?? "unknown"
            request.logger.error("Unhandled error [correlation-id: \(correlationId)]: \(error)")
        }
        
        let response = Response(status: status)
        try response.content.encode(errorResponse)
        response.headers.contentType = .json
        
        return response
    }
    
    private func decodingErrorMessage(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            
        case .valueNotFound(let type, let context):
            return "Missing required field: \(context.codingPath.map(\.stringValue).joined(separator: ".")) of type \(type)"
            
        case .keyNotFound(let key, let context):
            return "Missing required field: \(key.stringValue)"
            
        case .dataCorrupted(let context):
            return "Invalid data at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
            
        @unknown default:
            return "Invalid request data format"
        }
    }
}

// MARK: - Correlation ID Storage

struct CorrelationIDKey: StorageKey {
    typealias Value = String
}

extension Request {
    public var correlationID: String {
        return storage[CorrelationIDKey.self] ?? "unknown"
    }
}

// MARK: - CORS Middleware

struct SimpleCORSMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Handle preflight requests
        if request.method == .OPTIONS {
            let response = Response(status: .ok)
            addCORSHeaders(to: response)
            return response
        }
        
        let response = try await next.respond(to: request)
        addCORSHeaders(to: response)
        
        return response
    }
    
    private func addCORSHeaders(to response: Response) {
        response.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: "*")
        response.headers.replaceOrAdd(name: .accessControlAllowMethods, value: "GET, POST, OPTIONS")
        response.headers.replaceOrAdd(name: .accessControlAllowHeaders, value: "Content-Type, Authorization")
        response.headers.replaceOrAdd(name: .accessControlMaxAge, value: "86400")
    }
}

// MARK: - Content Type Middleware

struct JSONContentTypeMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        
        // Ensure JSON responses have correct content type
        if response.headers.contentType == nil {
            response.headers.contentType = .json
        }
        
        return response
    }
}
