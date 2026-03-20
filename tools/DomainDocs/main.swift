import Foundation

struct CommandLineOptions {
    let repoRoot: String
    let includeDirectories: [String]
    let jsonOutputPath: String
    let markdownOutputPath: String
    let title: String
}

enum DomainDocCLIError: Error {
    case invalidArguments(String)
}

struct DomainDocCLI {
    static func run() throws {
        let options = try parseArguments(Array(CommandLine.arguments.dropFirst()))
        let graph = try DomainDocExtractor.generateGraph(
            repoRoot: options.repoRoot,
            includeDirectories: options.includeDirectories
        )
        try writeOutputs(graph: graph, options: options)
    }

    private static func parseArguments(_ arguments: [String]) throws -> CommandLineOptions {
        var repoRoot: String?
        var includeDirectories: [String] = []
        var jsonOutputPath: String?
        var markdownOutputPath: String?
        var title = "Domain Model Relations"

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            index += 1

            switch argument {
            case "--repo-root":
                repoRoot = try consumeValue(for: argument, arguments: arguments, index: &index)
            case "--include-dir":
                includeDirectories.append(try consumeValue(for: argument, arguments: arguments, index: &index))
            case "--json-output":
                jsonOutputPath = try consumeValue(for: argument, arguments: arguments, index: &index)
            case "--markdown-output":
                markdownOutputPath = try consumeValue(for: argument, arguments: arguments, index: &index)
            case "--title":
                title = try consumeValue(for: argument, arguments: arguments, index: &index)
            default:
                throw DomainDocCLIError.invalidArguments("Unknown argument: \(argument)")
            }
        }

        guard let repoRoot else {
            throw DomainDocCLIError.invalidArguments("--repo-root is required")
        }
        guard !includeDirectories.isEmpty else {
            throw DomainDocCLIError.invalidArguments("At least one --include-dir is required")
        }
        guard let jsonOutputPath else {
            throw DomainDocCLIError.invalidArguments("--json-output is required")
        }
        guard let markdownOutputPath else {
            throw DomainDocCLIError.invalidArguments("--markdown-output is required")
        }

        return CommandLineOptions(
            repoRoot: repoRoot,
            includeDirectories: includeDirectories,
            jsonOutputPath: jsonOutputPath,
            markdownOutputPath: markdownOutputPath,
            title: title
        )
    }

    private static func consumeValue(
        for flag: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        guard index < arguments.count else {
            throw DomainDocCLIError.invalidArguments("Missing value for \(flag)")
        }
        defer { index += 1 }
        return arguments[index]
    }

    private static func writeOutputs(graph: DomainGraph, options: CommandLineOptions) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: options.jsonOutputPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: options.markdownOutputPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(graph) + Data("\n".utf8)
        try jsonData.write(to: URL(fileURLWithPath: options.jsonOutputPath))

        let markdown = DomainDocRenderer.renderMarkdown(title: options.title, graph: graph) + "\n"
        try markdown.write(toFile: options.markdownOutputPath, atomically: true, encoding: .utf8)
    }
}

do {
    try DomainDocCLI.run()
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    Foundation.exit(1)
}
