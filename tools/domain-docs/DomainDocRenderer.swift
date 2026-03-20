import Foundation

enum DomainDocRenderer {
    static func renderMarkdown(title: String, graph: DomainGraph) -> String {
        let renderedGraph = filterToEntityGraph(graph: graph)
        let mermaid = renderMermaidClassDiagram(graph: renderedGraph)
        return """
        # \(title)

        この文書は `scripts/generate_domain_docs.sh` により自動生成されます。手動編集はしないでください。

        - entity ノード数: \(renderedGraph.nodes.count)
        - entity 間参照数: \(renderedGraph.edges.count)

        ```mermaid
        \(mermaid)
        ```
        """
    }

    static func renderMermaidClassDiagram(graph: DomainGraph) -> String {
        var lines = ["classDiagram"]

        for node in graph.nodes {
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

        for edge in graph.edges {
            let cardinality = edge.cardinality == .many ? "*" : "1"
            lines.append("\(edge.fromTypeName) \"1\" --> \"\(cardinality)\" \(edge.toTypeName) : \(edge.memberName)")
        }

        return lines.joined(separator: "\n")
    }

    private static func filterToEntityGraph(graph: DomainGraph) -> DomainGraph {
        let entityTypeNames = Set(graph.nodes.filter(\.isEntity).map(\.typeName))
        let nodes = graph.nodes.filter { entityTypeNames.contains($0.typeName) }
        let edges = graph.edges.filter { edge in
            entityTypeNames.contains(edge.fromTypeName) && entityTypeNames.contains(edge.toTypeName)
        }
        return DomainGraph(nodes: nodes, edges: edges)
    }
}
