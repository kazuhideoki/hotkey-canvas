import Foundation

enum DomainDeclarationKind: String, Codable {
    case structDecl = "struct"
    case enumDecl = "enum"
}

enum DomainMemberKind: String, Codable {
    case property
    case enumCase
}

enum DomainReferenceOrigin: String, Codable {
    case direct
    case identifier
    case mixed
}

enum DomainCardinality: String, Codable {
    case one
    case many
}

enum DomainContainerKind: String, Codable {
    case scalar
    case optional
    case array
    case set
    case dictionaryKey
    case dictionaryValue
    case dictionary
}

struct DomainGraph: Codable {
    let nodes: [DomainNode]
    let edges: [DomainEdge]
}

struct DomainNode: Codable {
    let typeName: String
    let declarationKind: DomainDeclarationKind
    let sourcePath: String
    let sourceLine: Int
    let isEntity: Bool
    let members: [DomainMember]
}

struct DomainMember: Codable {
    let name: String
    let kind: DomainMemberKind
    let typeText: String?
}

struct DomainEdge: Codable {
    let fromTypeName: String
    let toTypeName: String
    let memberName: String
    let memberKind: DomainMemberKind
    let origin: DomainReferenceOrigin
    let cardinality: DomainCardinality
    let containerKind: DomainContainerKind
    let viaTypeNames: [String]
}
