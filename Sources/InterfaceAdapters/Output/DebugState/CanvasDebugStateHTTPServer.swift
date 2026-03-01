// Background: Local automation tools need an on-demand transport to fetch app state while the desktop app is running.
// Responsibility: Expose read-only debug state endpoints over localhost HTTP in development runs.
import Application
import Foundation
import Network

/// Runtime configuration for localhost debug state API.
public struct CanvasDebugStateHTTPServerConfiguration: Sendable {
    public let port: UInt16
    public let bearerToken: String

    /// Creates HTTP server configuration.
    /// - Parameters:
    ///   - port: Local listening port.
    ///   - bearerToken: Authorization token required by requests.
    public init(port: UInt16, bearerToken: String) {
        self.port = port
        self.bearerToken = bearerToken
    }
}

/// Lightweight localhost HTTP server that serves versioned debug state JSON.
public final class CanvasDebugStateHTTPServer {
    private let configuration: CanvasDebugStateHTTPServerConfiguration
    private let fetchResultsBySessionID: @Sendable () async -> [CanvasSessionID: ApplyResult]
    private let queue: DispatchQueue
    private var listener: NWListener?

    /// Creates server instance.
    /// - Parameters:
    ///   - configuration: Server network and authorization settings.
    ///   - fetchResultsBySessionID: Async provider that returns latest session state.
    public init(
        configuration: CanvasDebugStateHTTPServerConfiguration,
        fetchResultsBySessionID: @escaping @Sendable () async -> [CanvasSessionID: ApplyResult]
    ) {
        self.configuration = configuration
        self.fetchResultsBySessionID = fetchResultsBySessionID
        queue = DispatchQueue(label: "hotkey-canvas.debug-state.http")
    }

    /// Starts listening on localhost.
    /// - Throws: When listener creation or start fails.
    public func start() throws {
        guard listener == nil else {
            return
        }
        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw CanvasDebugStateHTTPServerError.invalidPort(configuration.port)
        }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host.ipv4(.loopback),
            port: port
        )

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        try waitUntilReady(listener: listener)
        self.listener = listener
    }

    /// Stops listening and closes active acceptor.
    public func stop() {
        listener?.cancel()
        listener = nil
    }
}

extension CanvasDebugStateHTTPServer {
    private func waitUntilReady(listener: NWListener) throws {
        let startupSemaphore = DispatchSemaphore(value: 0)
        let startupLock = NSLock()
        var startupResult: Result<Void, CanvasDebugStateHTTPServerError>?

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                startupLock.lock()
                defer { startupLock.unlock() }
                guard startupResult == nil else {
                    return
                }
                startupResult = .success(())
                startupSemaphore.signal()
            case .failed(let error):
                startupLock.lock()
                defer { startupLock.unlock() }
                guard startupResult == nil else {
                    return
                }
                startupResult = .failure(.listenerFailed(error))
                startupSemaphore.signal()
            default:
                return
            }
        }

        listener.start(queue: queue)
        let waitResult = startupSemaphore.wait(timeout: .now() + .seconds(2))

        startupLock.lock()
        defer { startupLock.unlock() }
        switch waitResult {
        case .success:
            guard let startupResult else {
                listener.cancel()
                throw CanvasDebugStateHTTPServerError.startupStateUnavailable
            }
            switch startupResult {
            case .success:
                return
            case .failure(let error):
                listener.cancel()
                throw error
            }
        case .timedOut:
            listener.cancel()
            throw CanvasDebugStateHTTPServerError.startupTimedOut(configuration.port)
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulatedData: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            guard error == nil else {
                connection.cancel()
                return
            }

            var receivedData = accumulatedData
            if let data {
                receivedData.append(data)
            }

            if receivedData.count > 64_000 {
                self.send(
                    response: .json(
                        status: .payloadTooLarge,
                        body: self.errorBody(code: "request_too_large")
                    ),
                    on: connection
                )
                return
            }

            if let request = HTTPRequest.parse(from: receivedData) {
                Task {
                    let response = await self.route(request: request)
                    self.send(response: response, on: connection)
                }
                return
            }

            if isComplete {
                self.send(
                    response: .json(
                        status: .badRequest,
                        body: self.errorBody(code: "invalid_request")
                    ),
                    on: connection
                )
                return
            }

            self.receiveRequest(on: connection, accumulatedData: receivedData)
        }
    }

    private func route(request: HTTPRequest) async -> HTTPResponse {
        guard request.method == "GET" else {
            return .json(status: .methodNotAllowed, body: errorBody(code: "method_not_allowed"))
        }

        guard request.isAuthorized(expectedToken: configuration.bearerToken) else {
            return .json(status: .unauthorized, body: errorBody(code: "unauthorized"))
        }

        if let response = routeHealth(request: request) {
            return response
        }

        let resultsBySessionID = await fetchResultsBySessionID()

        if let response = routeSessions(request: request, resultsBySessionID: resultsBySessionID) {
            return response
        }

        if let response = routeDomainCatalog(request: request, resultsBySessionID: resultsBySessionID) {
            return response
        }

        if let response = routeDomainState(request: request, resultsBySessionID: resultsBySessionID) {
            return response
        }

        if let response = routeSessionState(request: request, resultsBySessionID: resultsBySessionID) {
            return response
        }

        return .json(status: .notFound, body: errorBody(code: "not_found"))
    }

    private func routeHealth(request: HTTPRequest) -> HTTPResponse? {
        guard request.path == "/debug/v1/health" else {
            return nil
        }
        return makeJSONResponse { try CanvasDebugStateJSONMapper.makeHealthPayload() }
    }

    private func routeSessions(
        request: HTTPRequest,
        resultsBySessionID: [CanvasSessionID: ApplyResult]
    ) -> HTTPResponse? {
        guard request.path == "/debug/v1/sessions" else {
            return nil
        }
        return makeJSONResponse {
            try CanvasDebugStateJSONMapper.makeSessionsPayload(resultsBySessionID: resultsBySessionID)
        }
    }

    private func routeDomainCatalog(
        request: HTTPRequest,
        resultsBySessionID: [CanvasSessionID: ApplyResult]
    ) -> HTTPResponse? {
        guard let sessionID = request.sessionIDForDomainsPath() else {
            return nil
        }
        let key = CanvasSessionID(rawValue: sessionID)
        guard resultsBySessionID[key] != nil else {
            return .json(status: .notFound, body: errorBody(code: "session_not_found"))
        }
        return makeJSONResponse {
            try CanvasDebugStateJSONMapper.makeDomainCatalogPayload(sessionID: key)
        }
    }

    private func routeDomainState(
        request: HTTPRequest,
        resultsBySessionID: [CanvasSessionID: ApplyResult]
    ) -> HTTPResponse? {
        guard let path = request.sessionAndDomainIDForDomainStatePath() else {
            return nil
        }
        let key = CanvasSessionID(rawValue: path.sessionID)
        guard let result = resultsBySessionID[key] else {
            return .json(status: .notFound, body: errorBody(code: "session_not_found"))
        }
        guard let domainID = CanvasDebugDomainID(rawValue: path.domainID) else {
            return .json(status: .notFound, body: errorBody(code: "domain_not_found"))
        }
        return makeJSONResponse {
            try CanvasDebugStateJSONMapper.makeDomainStatePayload(
                sessionID: key,
                result: result,
                domainID: domainID
            )
        }
    }

    private func routeSessionState(
        request: HTTPRequest,
        resultsBySessionID: [CanvasSessionID: ApplyResult]
    ) -> HTTPResponse? {
        guard let sessionID = request.sessionIDForStatePath() else {
            return nil
        }
        let key = CanvasSessionID(rawValue: sessionID)
        guard let result = resultsBySessionID[key] else {
            return .json(status: .notFound, body: errorBody(code: "session_not_found"))
        }
        return makeJSONResponse {
            try CanvasDebugStateJSONMapper.makeSessionStatePayload(sessionID: key, result: result)
        }
    }

    private func makeJSONResponse(_ bodyBuilder: () throws -> Data) -> HTTPResponse {
        do {
            return .json(status: .ok, body: try bodyBuilder())
        } catch {
            return .json(status: .internalServerError, body: errorBody(code: "serialization_failed"))
        }
    }

    private func send(response: HTTPResponse, on connection: NWConnection) {
        connection.send(
            content: response.httpData,
            completion: .contentProcessed { _ in
                connection.cancel()
            })
    }

    private func errorBody(code: String) -> Data {
        Data("{\"schemaVersion\":\"debug-state.v1\",\"error\":\"\(code)\"}".utf8)
    }
}

/// Debug state server startup errors.
public enum CanvasDebugStateHTTPServerError: Error {
    /// Provided port is invalid for `NWEndpoint.Port`.
    case invalidPort(UInt16)
    /// Listener reported asynchronous failure while starting.
    case listenerFailed(NWError)
    /// Listener did not become ready within startup timeout.
    case startupTimedOut(UInt16)
    /// Internal startup state became inconsistent.
    case startupStateUnavailable
}

extension CanvasDebugStateHTTPServer {
    private struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]

        static func parse(from data: Data) -> HTTPRequest? {
            guard let headerBoundary = data.range(of: Data("\r\n\r\n".utf8)) else {
                return nil
            }
            let headerData = data[..<headerBoundary.lowerBound]
            guard let headerText = String(data: headerData, encoding: .utf8) else {
                return nil
            }

            let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
            guard let requestLine = lines.first else {
                return nil
            }

            let requestTokens = requestLine.split(separator: " ", omittingEmptySubsequences: true)
            guard requestTokens.count >= 2 else {
                return nil
            }

            let method = String(requestTokens[0])
            let target = String(requestTokens[1])
            let path =
                target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)
                ?? target

            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                guard let separator = line.firstIndex(of: ":") else {
                    continue
                }
                let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
                headers[key] = value
            }

            return HTTPRequest(method: method, path: path, headers: headers)
        }

        func isAuthorized(expectedToken: String) -> Bool {
            guard let authorization = headers["authorization"] else {
                return false
            }
            return authorization == "Bearer \(expectedToken)"
        }

        func sessionIDForStatePath() -> String? {
            let prefix = "/debug/v1/sessions/"
            let suffix = "/state"
            guard path.hasPrefix(prefix), path.hasSuffix(suffix) else {
                return nil
            }

            let start = path.index(path.startIndex, offsetBy: prefix.count)
            let end = path.index(path.endIndex, offsetBy: -suffix.count)
            guard start < end else {
                return nil
            }
            return String(path[start..<end])
        }

        func sessionIDForDomainsPath() -> String? {
            let prefix = "/debug/v1/sessions/"
            let suffix = "/domains"
            guard path.hasPrefix(prefix), path.hasSuffix(suffix) else {
                return nil
            }

            let start = path.index(path.startIndex, offsetBy: prefix.count)
            let end = path.index(path.endIndex, offsetBy: -suffix.count)
            guard start < end else {
                return nil
            }
            return String(path[start..<end])
        }

        func sessionAndDomainIDForDomainStatePath() -> (sessionID: String, domainID: String)? {
            let prefix = "/debug/v1/sessions/"
            let marker = "/domains/"
            guard path.hasPrefix(prefix), let markerRange = path.range(of: marker) else {
                return nil
            }

            let sessionStart = path.index(path.startIndex, offsetBy: prefix.count)
            let sessionEnd = markerRange.lowerBound
            guard sessionStart < sessionEnd else {
                return nil
            }
            let domainStart = markerRange.upperBound
            guard domainStart < path.endIndex else {
                return nil
            }
            let sessionID = String(path[sessionStart..<sessionEnd])
            let domainID = String(path[domainStart...])
            guard !sessionID.isEmpty, !domainID.isEmpty else {
                return nil
            }
            return (sessionID, domainID)
        }
    }

    private struct HTTPResponse {
        let status: HTTPStatus
        let headers: [String: String]
        let body: Data

        static func json(status: HTTPStatus, body: Data) -> HTTPResponse {
            var headers: [String: String] = [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": "\(body.count)",
                "Connection": "close",
            ]
            if status == .unauthorized {
                headers["WWW-Authenticate"] = "Bearer"
            }
            return HTTPResponse(status: status, headers: headers, body: body)
        }

        var httpData: Data {
            var data = Data("HTTP/1.1 \(status.rawValue) \(status.reasonPhrase)\r\n".utf8)
            for header in headers.keys.sorted() {
                guard let value = headers[header] else {
                    continue
                }
                data.append(Data("\(header): \(value)\r\n".utf8))
            }
            data.append(Data("\r\n".utf8))
            data.append(body)
            return data
        }
    }

    private enum HTTPStatus: Int {
        case ok = 200
        case badRequest = 400
        case unauthorized = 401
        case notFound = 404
        case methodNotAllowed = 405
        case payloadTooLarge = 413
        case internalServerError = 500

        var reasonPhrase: String {
            switch self {
            case .ok:
                return "OK"
            case .badRequest:
                return "Bad Request"
            case .unauthorized:
                return "Unauthorized"
            case .notFound:
                return "Not Found"
            case .methodNotAllowed:
                return "Method Not Allowed"
            case .payloadTooLarge:
                return "Payload Too Large"
            case .internalServerError:
                return "Internal Server Error"
            }
        }
    }
}
