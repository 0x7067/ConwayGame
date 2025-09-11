import Vapor
import XCTVapor
import XCTest

extension Application {
    @discardableResult
    func perform(_ method: HTTPMethod, _ path: String, beforeRequest: (inout XCTHTTPRequest) throws -> Void = { _ in }) async throws -> XCTHTTPResponse {
        var output: XCTHTTPResponse!
        try await self.test(method, path, beforeRequest: beforeRequest, afterResponse: { res in
            output = res
        })
        return output
    }

    @discardableResult
    func perform(_ method: HTTPMethod, _ path: String, expecting status: HTTPStatus, beforeRequest: (inout XCTHTTPRequest) throws -> Void = { _ in }) async throws -> XCTHTTPResponse {
        let res = try await perform(method, path, beforeRequest: beforeRequest)
        XCTAssertEqual(res.status, status)
        return res
    }

    func decode<T: Decodable>(_ method: HTTPMethod, _ path: String, expecting status: HTTPStatus = .ok, beforeRequest: (inout XCTHTTPRequest) throws -> Void = { _ in }) async throws -> T {
        let res = try await perform(method, path, expecting: status, beforeRequest: beforeRequest)
        return try res.content.decode(T.self)
    }
}
