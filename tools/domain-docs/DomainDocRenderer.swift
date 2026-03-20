import Foundation

enum DomainDocRenderer {
    private static let maxBridgeTypeDepth = 2

    static func renderMarkdown(title: String, graph: DomainGraph) -> String {
        let projection = projectEntityGraph(graph: graph)
        let mermaid = renderMermaidClassDiagram(projection: projection)
        return """
        # \(title)

        この文書は `scripts/generate_domain_docs.sh` により自動生成されます。手動編集はしないでください。

        - entity ノード数: \(projection.nodes.count)
        - entity 間参照数: \(projection.edges.count)

        ```mermaid
        \(mermaid)
        ```
        """
    }

    fileprivate static func renderMermaidClassDiagram(projection: EntityProjection) -> String {
        var lines = ["classDiagram"]

        for node in projection.nodes {
            lines.append("class \(node.typeName) {")
            lines.append("  <<\(node.declarationKind.rawValue)>>")
            for member in node.members {
                switch member.kind {
                case .property:
                    let typeText = member.typeText ?? "Unknown"
                    lines.append("  \(member.name): \(typeText)")
                case .enumCase:
                    if let typeText = member.typeText, !typeText.isEmpty {
                        lines.append("  \(member.name)(\(typeText))")
                    } else {
                        lines.append("  \(member.name)")
                    }
                }
            }
            lines.append("}")
        }

        for edge in projection.edges {
            let cardinality = edge.cardinality == .many ? "*" : "1"
            lines.append("\(edge.fromTypeName) \"1\" --> \"\(cardinality)\" \(edge.toTypeName) : \(edge.label)")
        }

        return lines.joined(separator: "\n")
    }

    private static func projectEntityGraph(graph: DomainGraph) -> EntityProjection {
        let entityNodes = graph.nodes.filter(\.isEntity).sorted { $0.typeName < $1.typeName }
        let entityTypeNames = Set(entityNodes.map(\.typeName))
        let edgesByFromTypeName = Dictionary(grouping: graph.edges, by: \.fromTypeName)

        var projectedEdgesBySelectionKey: [String: ProjectedEdge] = [:]

        for entityNode in entityNodes {
            let candidates = collectProjectedEdges(
                fromTypeName: entityNode.typeName,
                entityTypeNames: entityTypeNames,
                edgesByFromTypeName: edgesByFromTypeName
            )

            for candidate in candidates {
                if let current = projectedEdgesBySelectionKey[candidate.selectionKey] {
                    projectedEdgesBySelectionKey[candidate.selectionKey] = preferProjectedEdge(current, candidate)
                } else {
                    projectedEdgesBySelectionKey[candidate.selectionKey] = candidate
                }
            }
        }

        let projectedEdges = projectedEdgesBySelectionKey.values.sorted(by: compareProjectedEdges)
        let visibleMemberNamesByTypeName = Dictionary(grouping: projectedEdges.flatMap { edge in
            [(edge.fromTypeName, edge.sourceMemberName)]
        }, by: \.0).mapValues { groupedEntries in
            Set(groupedEntries.map(\.1))
        }

        let projectedNodes = entityNodes.map { node in
            ProjectedNode(
                typeName: node.typeName,
                declarationKind: node.declarationKind,
                members: node.members.filter { member in
                    visibleMemberNamesByTypeName[node.typeName]?.contains(member.name) ?? false
                }
            )
        }

        return EntityProjection(nodes: projectedNodes, edges: projectedEdges)
    }

    private static func collectProjectedEdges(
        fromTypeName: String,
        entityTypeNames: Set<String>,
        edgesByFromTypeName: [String: [DomainEdge]]
    ) -> [ProjectedEdge] {
        guard let rootEdges = edgesByFromTypeName[fromTypeName] else {
            return []
        }

        var projectedEdges: [ProjectedEdge] = []

        for edge in rootEdges.sorted(by: compareEdges) {
            if entityTypeNames.contains(edge.toTypeName) {
                projectedEdges.append(
                    ProjectedEdge(
                        fromTypeName: fromTypeName,
                        toTypeName: edge.toTypeName,
                        sourceMemberName: edge.memberName,
                        bridgeTypeNames: [],
                        cardinality: edge.cardinality
                    )
                )
                continue
            }

            projectedEdges.append(
                contentsOf: collectBridgedProjectedEdges(
                    fromTypeName: fromTypeName,
                    sourceMemberName: edge.memberName,
                    currentTypeName: edge.toTypeName,
                    currentCardinality: edge.cardinality,
                    bridgeTypeNames: [edge.toTypeName],
                    remainingBridgeDepth: maxBridgeTypeDepth - 1,
                    visitedTypeNames: [fromTypeName, edge.toTypeName],
                    entityTypeNames: entityTypeNames,
                    edgesByFromTypeName: edgesByFromTypeName
                )
            )
        }

        return projectedEdges
    }

    private static func collectBridgedProjectedEdges(
        fromTypeName: String,
        sourceMemberName: String,
        currentTypeName: String,
        currentCardinality: DomainCardinality,
        bridgeTypeNames: [String],
        remainingBridgeDepth: Int,
        visitedTypeNames: Set<String>,
        entityTypeNames: Set<String>,
        edgesByFromTypeName: [String: [DomainEdge]]
    ) -> [ProjectedEdge] {
        guard remainingBridgeDepth >= 0 else {
            return []
        }
        guard let outgoingEdges = edgesByFromTypeName[currentTypeName] else {
            return []
        }

        var projectedEdges: [ProjectedEdge] = []

        for edge in outgoingEdges.sorted(by: compareEdges) {
            let cardinality = normalizeCardinality(currentCardinality, edge.cardinality)
            if entityTypeNames.contains(edge.toTypeName) {
                projectedEdges.append(
                    ProjectedEdge(
                        fromTypeName: fromTypeName,
                        toTypeName: edge.toTypeName,
                        sourceMemberName: sourceMemberName,
                        bridgeTypeNames: bridgeTypeNames,
                        cardinality: cardinality
                    )
                )
                continue
            }

            guard !visitedTypeNames.contains(edge.toTypeName) else {
                continue
            }

            guard remainingBridgeDepth > 0 else {
                continue
            }

            var nextVisitedTypeNames = visitedTypeNames
            nextVisitedTypeNames.insert(edge.toTypeName)
            projectedEdges.append(
                contentsOf: collectBridgedProjectedEdges(
                    fromTypeName: fromTypeName,
                    sourceMemberName: sourceMemberName,
                    currentTypeName: edge.toTypeName,
                    currentCardinality: cardinality,
                    bridgeTypeNames: bridgeTypeNames + [edge.toTypeName],
                    remainingBridgeDepth: remainingBridgeDepth - 1,
                    visitedTypeNames: nextVisitedTypeNames,
                    entityTypeNames: entityTypeNames,
                    edgesByFromTypeName: edgesByFromTypeName
                )
            )
        }

        return projectedEdges
    }

    private static func normalizeCardinality(
        _ left: DomainCardinality,
        _ right: DomainCardinality
    ) -> DomainCardinality {
        if left == .many || right == .many {
            return .many
        }
        return .one
    }

    private static func compareEdges(_ left: DomainEdge, _ right: DomainEdge) -> Bool {
        [
            left.fromTypeName,
            left.toTypeName,
            left.memberName,
            left.memberKind.rawValue,
            left.origin.rawValue,
            left.cardinality.rawValue,
            left.containerKind.rawValue,
            left.viaTypeNames.joined(separator: ",")
        ].joined(separator: "|") < [
            right.fromTypeName,
            right.toTypeName,
            right.memberName,
            right.memberKind.rawValue,
            right.origin.rawValue,
            right.cardinality.rawValue,
            right.containerKind.rawValue,
            right.viaTypeNames.joined(separator: ",")
        ].joined(separator: "|")
    }

    private static func compareProjectedEdges(_ left: ProjectedEdge, _ right: ProjectedEdge) -> Bool {
        left.sortKey < right.sortKey
    }

    private static func preferProjectedEdge(_ current: ProjectedEdge, _ candidate: ProjectedEdge) -> ProjectedEdge {
        if candidate.bridgeTypeNames.count != current.bridgeTypeNames.count {
            return candidate.bridgeTypeNames.count < current.bridgeTypeNames.count ? candidate : current
        }
        if candidate.pathSignature != current.pathSignature {
            return candidate.pathSignature < current.pathSignature ? candidate : current
        }
        if candidate.cardinality != current.cardinality {
            return candidate.cardinality == .many ? candidate : current
        }
        return candidate.sortKey < current.sortKey ? candidate : current
    }
}

private struct EntityProjection {
    let nodes: [ProjectedNode]
    let edges: [ProjectedEdge]
}

private struct ProjectedNode {
    let typeName: String
    let declarationKind: DomainDeclarationKind
    let members: [DomainMember]
}

private struct ProjectedEdge {
    let fromTypeName: String
    let toTypeName: String
    let sourceMemberName: String
    let bridgeTypeNames: [String]
    let cardinality: DomainCardinality
    
    var label: String {
        guard !bridgeTypeNames.isEmpty else {
            return sourceMemberName
        }
        return "\(sourceMemberName) via \(bridgeTypeNames.joined(separator: ", "))"
    }

    var selectionKey: String {
        "\(fromTypeName)|\(toTypeName)|\(sourceMemberName)"
    }

    var pathSignature: String {
        bridgeTypeNames.joined(separator: "->")
    }

    var sortKey: String {
        [
            fromTypeName,
            toTypeName,
            sourceMemberName,
            pathSignature,
            cardinality.rawValue
        ].joined(separator: "|")
    }
}
