import Foundation
import Vapor

public final class MetricsMiddleware: AsyncMiddleware {
    private let metrics: MetricsCollector

    public init(metrics: MetricsCollector = InMemoryMetricsCollector()) {
        self.metrics = metrics
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let startTime = Date()
        let endpoint = getEndpointKey(from: request)
        let method = request.method.rawValue

        // Track request count
        await metrics.incrementCounter(name: "http_requests_total", tags: [
            "method": method,
            "endpoint": endpoint
        ])

        do {
            let response = try await next.respond(to: request)
            let duration = Date().timeIntervalSince(startTime)

            // Track response metrics
            await metrics.recordHistogram(name: "http_request_duration_seconds", value: duration, tags: [
                "method": method,
                "endpoint": endpoint,
                "status": "\(response.status.code)"
            ])

            await metrics.incrementCounter(name: "http_responses_total", tags: [
                "method": method,
                "endpoint": endpoint,
                "status": "\(response.status.code)"
            ])

            // Add performance headers
            response.headers.replaceOrAdd(name: "X-Response-Time", value: String(format: "%.3fms", duration * 1000))

            return response

        } catch {
            let duration = Date().timeIntervalSince(startTime)

            // Track error metrics
            await metrics.incrementCounter(name: "http_errors_total", tags: [
                "method": method,
                "endpoint": endpoint,
                "error": "\(type(of: error))"
            ])

            await metrics.recordHistogram(name: "http_request_duration_seconds", value: duration, tags: [
                "method": method,
                "endpoint": endpoint,
                "status": "error"
            ])

            throw error
        }
    }

    private func getEndpointKey(from request: Request) -> String {
        let path = request.url.path

        // Normalize paths to avoid high cardinality
        if path.hasPrefix("/api/game/simulate") {
            return "/api/game/simulate"
        } else if path.hasPrefix("/api/game/step") {
            return "/api/game/step"
        } else if path.hasPrefix("/api/game/validate") {
            return "/api/game/validate"
        } else if path.hasPrefix("/api/patterns/") {
            return "/api/patterns/{name}"
        } else if path == "/api/patterns" {
            return "/api/patterns"
        } else if path == "/api/rules" {
            return "/api/rules"
        } else if path == "/health" {
            return "/health"
        } else if path == "/api" {
            return "/api"
        } else {
            return "/other"
        }
    }
}

// MARK: - Metrics Collector

public protocol MetricsCollector {
    func incrementCounter(name: String, tags: [String: String]) async
    func recordHistogram(name: String, value: Double, tags: [String: String]) async
    func recordGauge(name: String, value: Double, tags: [String: String]) async
    func getMetrics() async -> [Metric]
}

public struct Metric: Codable, Sendable {
    public let name: String
    public let type: MetricType
    public let value: Double
    public let tags: [String: String]
    public let timestamp: Date

    public init(name: String, type: MetricType, value: Double, tags: [String: String] = [:]) {
        self.name = name
        self.type = type
        self.value = value
        self.tags = tags
        self.timestamp = Date()
    }
}

public enum MetricType: String, CaseIterable, Codable, Sendable {
    case counter
    case histogram
    case gauge
}

// MARK: - In-Memory Metrics Collector

public actor InMemoryMetricsCollector: MetricsCollector {
    private var counters: [String: Double] = [:]
    private var histograms: [String: [Double]] = [:]
    private var gauges: [String: Double] = [:]

    public init() {}

    public func incrementCounter(name: String, tags: [String: String]) async {
        let key = metricKey(name: name, tags: tags)
        counters[key] = (counters[key] ?? 0) + 1
    }

    public func recordHistogram(name: String, value: Double, tags: [String: String]) async {
        let key = metricKey(name: name, tags: tags)
        histograms[key, default: []].append(value)

        // Keep only recent values to prevent memory growth
        if histograms[key]!.count > 1000 {
            histograms[key] = Array(histograms[key]!.suffix(1000))
        }
    }

    public func recordGauge(name: String, value: Double, tags: [String: String]) async {
        let key = metricKey(name: name, tags: tags)
        gauges[key] = value
    }

    public func getMetrics() async -> [Metric] {
        var metrics: [Metric] = []

        // Add counters
        for (key, value) in counters {
            let (name, tags) = parseMetricKey(key)
            metrics.append(Metric(name: name, type: .counter, value: value, tags: tags))
        }

        // Add histogram summaries (average, count, etc.)
        for (key, values) in histograms {
            let (name, tags) = parseMetricKey(key)
            if !values.isEmpty {
                let sum = values.reduce(0, +)
                let avg = sum / Double(values.count)
                let max = values.max() ?? 0
                let min = values.min() ?? 0

                var avgTags = tags
                avgTags["stat"] = "avg"
                metrics.append(Metric(name: name, type: .histogram, value: avg, tags: avgTags))

                var countTags = tags
                countTags["stat"] = "count"
                metrics.append(Metric(name: name, type: .histogram, value: Double(values.count), tags: countTags))

                var maxTags = tags
                maxTags["stat"] = "max"
                metrics.append(Metric(name: name, type: .histogram, value: max, tags: maxTags))

                var minTags = tags
                minTags["stat"] = "min"
                metrics.append(Metric(name: name, type: .histogram, value: min, tags: minTags))
            }
        }

        // Add gauges
        for (key, value) in gauges {
            let (name, tags) = parseMetricKey(key)
            metrics.append(Metric(name: name, type: .gauge, value: value, tags: tags))
        }

        return metrics
    }

    private func metricKey(name: String, tags: [String: String]) -> String {
        let tagString = tags.keys.sorted().map { "\($0)=\(tags[$0]!)" }.joined(separator: ",")
        return tagString.isEmpty ? name : "\(name){\(tagString)}"
    }

    private func parseMetricKey(_ key: String) -> (name: String, tags: [String: String]) {
        if let braceIndex = key.firstIndex(of: "{") {
            let name = String(key[..<braceIndex])
            let tagString = String(key[key.index(after: braceIndex)..<key.index(before: key.endIndex)])

            var tags: [String: String] = [:]
            for tagPair in tagString.split(separator: ",") {
                let parts = tagPair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    tags[String(parts[0])] = String(parts[1])
                }
            }
            return (name, tags)
        } else {
            return (key, [:])
        }
    }
}

// MARK: - Metrics Endpoint Controller

public struct MetricsController: RouteCollection {
    private let metrics: MetricsCollector

    public init(metrics: MetricsCollector) {
        self.metrics = metrics
    }

    public func boot(routes: RoutesBuilder) throws {
        routes.get("metrics", use: getMetrics)
    }

    func getMetrics(req: Request) async throws -> MetricsResponse {
        let allMetrics = await metrics.getMetrics()
        return MetricsResponse(metrics: allMetrics, timestamp: Date())
    }
}

public struct MetricsResponse: Content {
    public let metrics: [Metric]
    public let timestamp: Date
}

// MARK: - Application Extension

extension Application {
    private struct MetricsCollectorKey: StorageKey {
        typealias Value = MetricsCollector
    }

    public var metricsCollector: MetricsCollector {
        get {
            self.storage[MetricsCollectorKey.self] ?? InMemoryMetricsCollector()
        }
        set {
            self.storage[MetricsCollectorKey.self] = newValue
        }
    }
}
