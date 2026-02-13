public protocol AppLogger: Sendable {
    func info(_ message: String)
}

public struct ConsoleLogger: AppLogger {
    public init() {}

    public func info(_ message: String) {
        print(message)
    }
}
