import Foundation
import SwiftParser
import SwiftSyntax

private struct DeclarationRecord {
    let typeName: String
    let declarationKind: DomainDeclarationKind
    let sourcePath: String
    let sourceLine: Int
    let isEntity: Bool
    let identifierOf: String?
    let members: [MemberRecord]
}

private struct MemberRecord {
    let name: String
    let kind: DomainMemberKind
    let typeText: String?
    let referenceCandidates: [ReferenceCandidate]
}

private struct ReferenceCandidate {
    let targetTypeName: String
    let origin: DomainReferenceOrigin
    let cardinality: DomainCardinality
    let containerKind: DomainContainerKind
    let viaTypeNames: [String]
}

struct DomainDocExtractor {
    static func generateGraph(
        repoRoot: String,
        includeDirectories: [String]
    ) throws -> DomainGraph {
        let swiftFiles = try collectSwiftFiles(includeDirectories: includeDirectories)
        var declarationRecords: [DeclarationRecord] = []

        for swiftFile in swiftFiles {
            let source = try String(contentsOfFile: swiftFile, encoding: .utf8)
            let sourceFile = Parser.parse(source: source)
            let relativePath = makeRelativePath(path: swiftFile, base: repoRoot)
            let collector = DeclarationCollector(sourcePath: relativePath, sourceFile: sourceFile)
            declarationRecords.append(contentsOf: collector.collect())
        }

        let identifierBindings: [(String, String)] = declarationRecords.compactMap { record in
            guard let identifierOf = record.identifierOf else {
                return nil
            }
            return (record.typeName, identifierOf)
        }
        let identifierTargets = Dictionary(uniqueKeysWithValues: identifierBindings)

        let graphableDeclarations = declarationRecords
            .map { $0.resolved(using: identifierTargets) }
            .filter { identifierTargets[$0.typeName] == nil }
            .sorted { left, right in
                if left.typeName == right.typeName {
                    return left.sourcePath < right.sourcePath
                }
                return left.typeName < right.typeName
            }
        let visibleTypeNames = Set(graphableDeclarations.map { $0.typeName })

        let nodes = graphableDeclarations.map { record in
            DomainNode(
                typeName: record.typeName,
                declarationKind: record.declarationKind,
                sourcePath: record.sourcePath,
                sourceLine: record.sourceLine,
                isEntity: record.isEntity,
                members: record.members.map { member in
                    DomainMember(
                        name: member.name,
                        kind: member.kind,
                        typeText: member.typeText
                    )
                }
            )
        }

        let edges = graphableDeclarations.flatMap { record in
            buildEdges(
                for: record,
                visibleTypeNames: visibleTypeNames
            )
        }.sorted { left, right in
            let leftKey = [
                left.fromTypeName,
                left.toTypeName,
                left.memberName,
                left.memberKind.rawValue,
                left.origin.rawValue,
                left.cardinality.rawValue,
                left.containerKind.rawValue,
                left.viaTypeNames.joined(separator: ",")
            ].joined(separator: "|")
            let rightKey = [
                right.fromTypeName,
                right.toTypeName,
                right.memberName,
                right.memberKind.rawValue,
                right.origin.rawValue,
                right.cardinality.rawValue,
                right.containerKind.rawValue,
                right.viaTypeNames.joined(separator: ",")
            ].joined(separator: "|")
            return leftKey < rightKey
        }

        return DomainGraph(nodes: nodes, edges: edges)
    }

    private static func buildEdges(
        for record: DeclarationRecord,
        visibleTypeNames: Set<String>
    ) -> [DomainEdge] {
        record.members.flatMap { member in
            let groupedCandidates = Dictionary(grouping: member.referenceCandidates.filter { candidate in
                visibleTypeNames.contains(candidate.targetTypeName)
            }, by: \.targetTypeName)

            return groupedCandidates.keys.sorted().compactMap { targetTypeName -> DomainEdge? in
                guard let candidates = groupedCandidates[targetTypeName] else {
                    return nil
                }
                if member.kind == .property && member.name == "id" && targetTypeName == record.typeName {
                    return nil
                }

                let origins = Set(candidates.map(\.origin))
                let origin: DomainReferenceOrigin
                if origins.count > 1 {
                    origin = .mixed
                } else {
                    origin = candidates.first?.origin ?? .direct
                }

                let cardinality: DomainCardinality = candidates.contains(where: { $0.cardinality == .many }) ? .many : .one
                let containerKinds = Set(candidates.map(\.containerKind))
                let containerKind = normalizeContainerKind(containerKinds)
                let viaTypeNames = candidates
                    .flatMap(\.viaTypeNames)
                    .reduce(into: [String]()) { partialResult, typeName in
                        if !partialResult.contains(typeName) {
                            partialResult.append(typeName)
                        }
                    }
                    .sorted()

                return DomainEdge(
                    fromTypeName: record.typeName,
                    toTypeName: targetTypeName,
                    memberName: member.name,
                    memberKind: member.kind,
                    origin: origin,
                    cardinality: cardinality,
                    containerKind: containerKind,
                    viaTypeNames: viaTypeNames
                )
            }
        }
    }

    private static func normalizeContainerKind(_ containerKinds: Set<DomainContainerKind>) -> DomainContainerKind {
        if containerKinds == [.dictionaryKey, .dictionaryValue] {
            return .dictionary
        }
        if containerKinds.contains(.dictionaryValue) {
            return .dictionaryValue
        }
        if containerKinds.contains(.dictionaryKey) {
            return .dictionaryKey
        }
        if containerKinds.contains(.set) {
            return .set
        }
        if containerKinds.contains(.array) {
            return .array
        }
        if containerKinds.contains(.optional) {
            return .optional
        }
        return .scalar
    }

    private static func collectSwiftFiles(includeDirectories: [String]) throws -> [String] {
        var filePaths: [String] = []
        let fileManager = FileManager.default

        for directory in includeDirectories {
            guard let enumerator = fileManager.enumerator(atPath: directory) else {
                continue
            }

            while let next = enumerator.nextObject() as? String {
                guard next.hasSuffix(".swift") else {
                    continue
                }
                filePaths.append(URL(fileURLWithPath: directory).appendingPathComponent(next).path)
            }
        }

        return filePaths.sorted()
    }

    private static func makeRelativePath(path: String, base: String) -> String {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let standardizedBase = URL(fileURLWithPath: base).standardizedFileURL.path
        let baseURL = URL(fileURLWithPath: standardizedBase, isDirectory: true)
        return baseURL.relativePath(to: URL(fileURLWithPath: standardizedPath))
    }
}

private final class DeclarationCollector {
    private let sourcePath: String
    private let sourceFile: SourceFileSyntax
    private let locationConverter: SourceLocationConverter

    init(sourcePath: String, sourceFile: SourceFileSyntax) {
        self.sourcePath = sourcePath
        self.sourceFile = sourceFile
        self.locationConverter = SourceLocationConverter(fileName: sourcePath, tree: sourceFile)
    }

    func collect() -> [DeclarationRecord] {
        sourceFile.statements.compactMap { statement in
            if let structDecl = statement.item.as(StructDeclSyntax.self), isPublic(structDecl.modifiers) {
                return makeStructRecord(structDecl)
            }
            if let enumDecl = statement.item.as(EnumDeclSyntax.self), isPublic(enumDecl.modifiers) {
                return makeEnumRecord(enumDecl)
            }
            return nil
        }
    }

    private func makeStructRecord(_ structDecl: StructDeclSyntax) -> DeclarationRecord {
        let members = structDecl.memberBlock.members.flatMap { item in
            extractPropertyMembers(from: item.decl)
        }

        return DeclarationRecord(
            typeName: structDecl.name.text.trimmed,
            declarationKind: .structDecl,
            sourcePath: sourcePath,
            sourceLine: sourceLine(for: structDecl),
            isEntity: parseEntityFlag(from: structDecl.leadingTrivia),
            identifierOf: parseIdentifierTarget(from: structDecl.leadingTrivia),
            members: members
        )
    }

    private func makeEnumRecord(_ enumDecl: EnumDeclSyntax) -> DeclarationRecord {
        let members = enumDecl.memberBlock.members.flatMap { item in
            if let enumCaseDecl = item.decl.as(EnumCaseDeclSyntax.self) {
                return extractEnumCaseMembers(from: enumCaseDecl)
            }
            return extractPropertyMembers(from: item.decl)
        }

        return DeclarationRecord(
            typeName: enumDecl.name.text.trimmed,
            declarationKind: .enumDecl,
            sourcePath: sourcePath,
            sourceLine: sourceLine(for: enumDecl),
            isEntity: parseEntityFlag(from: enumDecl.leadingTrivia),
            identifierOf: parseIdentifierTarget(from: enumDecl.leadingTrivia),
            members: members
        )
    }

    private func extractPropertyMembers(from decl: DeclSyntax) -> [MemberRecord] {
        guard let variableDecl = decl.as(VariableDeclSyntax.self) else {
            return []
        }
        guard !hasStaticModifier(variableDecl.modifiers) else {
            return []
        }

        return variableDecl.bindings.compactMap { binding in
            guard binding.accessorBlock == nil else {
                return nil
            }
            guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                return nil
            }
            guard let typeSyntax = binding.typeAnnotation?.type else {
                return nil
            }

            return MemberRecord(
                name: identifierPattern.identifier.text.trimmed,
                kind: .property,
                typeText: typeSyntax.trimmedDescription,
                referenceCandidates: ReferenceCollector.collect(from: typeSyntax)
            )
        }
    }

    private func extractEnumCaseMembers(from enumCaseDecl: EnumCaseDeclSyntax) -> [MemberRecord] {
        enumCaseDecl.elements.flatMap { element in
            guard let parameterClause = element.parameterClause else {
                return [MemberRecord]()
            }

            let typeTexts = parameterClause.parameters.map { $0.type.trimmedDescription }
            let candidates = parameterClause.parameters.flatMap { parameter in
                ReferenceCollector.collect(from: parameter.type)
            }

            return [
                MemberRecord(
                    name: element.name.text.trimmed,
                    kind: .enumCase,
                    typeText: typeTexts.joined(separator: ", "),
                    referenceCandidates: candidates
                )
            ]
        }
    }

    private func parseIdentifierTarget(from trivia: Trivia?) -> String? {
        parseDomainDocPattern(#"@domainDoc\s+identifierOf\(([A-Za-z_][A-Za-z0-9_]*)\)"#, captureGroup: 1, from: trivia)
    }

    private func parseEntityFlag(from trivia: Trivia?) -> Bool {
        parseDomainDocPattern(#"@domainDoc\s+entity\b"#, captureGroup: nil, from: trivia) != nil
    }

    private func parseDomainDocPattern(
        _ pattern: String,
        captureGroup: Int?,
        from trivia: Trivia?
    ) -> String? {
        guard let trivia else {
            return nil
        }

        let commentText = trivia.pieces.compactMap { piece -> String? in
            switch piece {
            case .lineComment(let text),
                 .docLineComment(let text),
                 .blockComment(let text),
                 .docBlockComment(let text):
                return text
            default:
                return nil
            }
        }.joined(separator: "\n")
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let fullRange = NSRange(commentText.startIndex..<commentText.endIndex, in: commentText)
        guard let match = regex.firstMatch(in: commentText, options: [], range: fullRange) else {
            return nil
        }
        guard let captureGroup else {
            return ""
        }
        guard let captureRange = Range(match.range(at: captureGroup), in: commentText) else {
            return ""
        }
        return String(commentText[captureRange])
    }

    private func sourceLine(for node: some SyntaxProtocol) -> Int {
        locationConverter.location(for: node.positionAfterSkippingLeadingTrivia).line
    }

    private func isPublic(_ modifiers: DeclModifierListSyntax?) -> Bool {
        modifiers?.contains(where: { modifier in
            let name = modifier.name.text.trimmed
            return name == "public" || name == "open"
        }) ?? false
    }

    private func hasStaticModifier(_ modifiers: DeclModifierListSyntax?) -> Bool {
        modifiers?.contains(where: { modifier in
            let name = modifier.name.text.trimmed
            return name == "static" || name == "class"
        }) ?? false
    }
}

private enum ReferenceCollector {
    static func collect(from typeSyntax: TypeSyntax) -> [ReferenceCandidate] {
        collect(
            from: typeSyntax,
            cardinality: .one,
            containerKind: .scalar
        )
    }

    private static func collect(
        from typeSyntax: TypeSyntax,
        cardinality: DomainCardinality,
        containerKind: DomainContainerKind
    ) -> [ReferenceCandidate] {
        if let identifierType = typeSyntax.as(IdentifierTypeSyntax.self) {
            return collect(from: identifierType, cardinality: cardinality, containerKind: containerKind)
        }
        if let optionalType = typeSyntax.as(OptionalTypeSyntax.self) {
            return collect(from: optionalType.wrappedType, cardinality: cardinality, containerKind: .optional)
        }
        if let implicitlyUnwrappedOptionalType = typeSyntax.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return collect(from: implicitlyUnwrappedOptionalType.wrappedType, cardinality: cardinality, containerKind: .optional)
        }
        if let arrayType = typeSyntax.as(ArrayTypeSyntax.self) {
            return collect(from: arrayType.element, cardinality: .many, containerKind: .array)
        }
        if let dictionaryType = typeSyntax.as(DictionaryTypeSyntax.self) {
            let keyCandidates = collect(from: dictionaryType.key, cardinality: .many, containerKind: .dictionaryKey)
            let valueCandidates = collect(from: dictionaryType.value, cardinality: .many, containerKind: .dictionaryValue)
            return keyCandidates + valueCandidates
        }
        if let attributedType = typeSyntax.as(AttributedTypeSyntax.self) {
            return collect(from: attributedType.baseType, cardinality: cardinality, containerKind: containerKind)
        }
        if let memberType = typeSyntax.as(MemberTypeSyntax.self) {
            return [
                ReferenceCandidate(
                    targetTypeName: memberType.name.text.trimmed,
                    origin: .direct,
                    cardinality: cardinality,
                    containerKind: containerKind,
                    viaTypeNames: []
                )
            ]
        }
        if let someOrAnyType = typeSyntax.as(SomeOrAnyTypeSyntax.self) {
            return collect(from: someOrAnyType.constraint, cardinality: cardinality, containerKind: containerKind)
        }
        if let compositionType = typeSyntax.as(CompositionTypeSyntax.self) {
            return compositionType.elements.flatMap { element in
                collect(from: element.type, cardinality: cardinality, containerKind: containerKind)
            }
        }
        if let tupleType = typeSyntax.as(TupleTypeSyntax.self) {
            return tupleType.elements.flatMap { element in
                collect(from: element.type, cardinality: cardinality, containerKind: containerKind)
            }
        }
        return []
    }

    private static func collect(
        from identifierType: IdentifierTypeSyntax,
        cardinality: DomainCardinality,
        containerKind: DomainContainerKind
    ) -> [ReferenceCandidate] {
        let typeName = identifierType.name.text.trimmed

        if typeName == "Array" || typeName == "Set" {
            guard let firstArgument = identifierType.genericArgumentClause?.arguments.first else {
                return []
            }
            let nestedContainerKind: DomainContainerKind = typeName == "Array" ? .array : .set
            return collect(from: firstArgument.argument, cardinality: .many, containerKind: nestedContainerKind)
        }

        if typeName == "Optional" {
            guard let firstArgument = identifierType.genericArgumentClause?.arguments.first else {
                return []
            }
            return collect(from: firstArgument.argument, cardinality: cardinality, containerKind: .optional)
        }

        var candidates: [ReferenceCandidate] = [
            ReferenceCandidate(
                targetTypeName: typeName,
                origin: .direct,
                cardinality: cardinality,
                containerKind: containerKind,
                viaTypeNames: []
            )
        ]

        if let arguments = identifierType.genericArgumentClause?.arguments {
            candidates.append(contentsOf: arguments.flatMap { argument in
                collect(from: argument.argument, cardinality: cardinality, containerKind: containerKind)
            })
        }

        return candidates
    }
}

private extension ReferenceCollector {
    static func collect(
        from genericArgument: GenericArgumentSyntax.Argument,
        cardinality: DomainCardinality,
        containerKind: DomainContainerKind
    ) -> [ReferenceCandidate] {
        guard let nestedType = genericArgument.as(TypeSyntax.self) else {
            return []
        }
        return collect(from: nestedType, cardinality: cardinality, containerKind: containerKind)
    }
}

private extension Array where Element == ReferenceCandidate {
    func resolvingIdentifierTargets(using identifierTargets: [String: String]) -> [ReferenceCandidate] {
        map { candidate in
            guard let targetTypeName = identifierTargets[candidate.targetTypeName] else {
                return candidate
            }
            return ReferenceCandidate(
                targetTypeName: targetTypeName,
                origin: .identifier,
                cardinality: candidate.cardinality,
                containerKind: candidate.containerKind,
                viaTypeNames: [candidate.targetTypeName]
            )
        }
    }
}

private extension URL {
    func relativePath(to other: URL) -> String {
        let baseComponents = standardizedFileURL.pathComponents
        let targetComponents = other.standardizedFileURL.pathComponents
        var sharedIndex = 0

        while sharedIndex < min(baseComponents.count, targetComponents.count) &&
            baseComponents[sharedIndex] == targetComponents[sharedIndex]
        {
            sharedIndex += 1
        }

        let parentComponents = Array(repeating: "..", count: max(baseComponents.count - sharedIndex, 0))
        let remainingComponents = Array(targetComponents.dropFirst(sharedIndex))
        let relativeComponents = parentComponents + remainingComponents
        return relativeComponents.isEmpty ? "." : NSString.path(withComponents: relativeComponents)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension MemberRecord {
    func resolved(using identifierTargets: [String: String]) -> MemberRecord {
        MemberRecord(
            name: name,
            kind: kind,
            typeText: typeText,
            referenceCandidates: referenceCandidates.resolvingIdentifierTargets(using: identifierTargets)
        )
    }
}

private extension DeclarationRecord {
    func resolved(using identifierTargets: [String: String]) -> DeclarationRecord {
        DeclarationRecord(
            typeName: typeName,
            declarationKind: declarationKind,
            sourcePath: sourcePath,
            sourceLine: sourceLine,
            isEntity: isEntity,
            identifierOf: identifierOf,
            members: members.map { $0.resolved(using: identifierTargets) }
        )
    }
}
