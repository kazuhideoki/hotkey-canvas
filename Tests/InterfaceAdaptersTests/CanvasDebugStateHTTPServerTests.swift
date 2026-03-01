// Background: Debug-state API startup must fail fast when its port is not bindable.
// Responsibility: Ensure HTTP server start does not report success under port-conflict conditions.
import Application
import Darwin
import InterfaceAdapters
import Testing

private enum TestPortReservationError: Error {
    case socketCreationFailed
    case bindFailed
    case getsocknameFailed
}

@Test("CanvasDebugStateHTTPServer: start fails when port is already occupied")
func test_start_failsWhenPortIsAlreadyOccupied() throws {
    let port = try findAvailablePort()
    let firstServer = makeServer(port: port)
    try firstServer.start()
    defer {
        firstServer.stop()
    }

    let secondServer = makeServer(port: port)
    do {
        try secondServer.start()
        secondServer.stop()
        Issue.record("Expected port-conflict startup to throw")
    } catch let error as CanvasDebugStateHTTPServerError {
        switch error {
        case .listenerFailed, .startupTimedOut:
            break
        case .invalidPort, .startupStateUnavailable:
            Issue.record("Unexpected startup error: \(error)")
        }
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}

private func makeServer(port: UInt16) -> CanvasDebugStateHTTPServer {
    CanvasDebugStateHTTPServer(
        configuration: CanvasDebugStateHTTPServerConfiguration(
            port: port,
            bearerToken: "test-token"
        ),
        fetchResultsBySessionID: { [:] }
    )
}

private func findAvailablePort() throws -> UInt16 {
    let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard socketFileDescriptor >= 0 else {
        throw TestPortReservationError.socketCreationFailed
    }
    defer {
        _ = close(socketFileDescriptor)
    }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(0).bigEndian
    address.sin_addr = in_addr(s_addr: in_addr_t(INADDR_LOOPBACK).bigEndian)

    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            bind(socketFileDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        throw TestPortReservationError.bindFailed
    }

    var boundAddress = sockaddr_in()
    var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            getsockname(socketFileDescriptor, sockaddrPointer, &addressLength)
        }
    }
    guard nameResult == 0 else {
        throw TestPortReservationError.getsocknameFailed
    }

    return UInt16(bigEndian: boundAddress.sin_port)
}
