import { readdir } from 'node:fs/promises';
import path from 'node:path';
import ts from 'typescript';
import { z } from 'zod';

const domainDocSourceSchema = z.object({
  directory: z.string().min(1),
  filePattern: z.string().min(1),
});

const domainDocEntityDomainSchema = z.object({
  typeName: z.string().min(1),
  domain: z.string().min(1).nullable(),
});

const domainDocKindSchema = z.enum(['entity', 'valueObject']);

const domainDocRelationHintSchema = z.object({
  from: z.string().regex(/^[A-Za-z0-9_]+\.[A-Za-z0-9_]+$/),
  to: z.string().min(1),
  kind: z.enum(['reference']),
});

const domainDocConfigSchema = z.object({
  sourcePathBaseDirectory: z.string().min(1),
  sources: z.array(domainDocSourceSchema).min(1),
  entityDomains: z.array(domainDocEntityDomainSchema),
  relationHints: z.array(domainDocRelationHintSchema),
});

const domainGraphPropertySchema = z.object({
  name: z.string().min(1),
  typeText: z.string().min(1),
});

const domainGraphNodeSchema = z.object({
  declarationId: z.string().min(1),
  typeName: z.string().min(1),
  kind: z.enum(['entity', 'valueObject']),
  shape: z.enum(['object', 'union']),
  domain: z.string().min(1).nullable(),
  sourcePath: z.string().min(1),
  sourceLine: z.number().int().positive(),
  properties: z.array(domainGraphPropertySchema),
});

const domainGraphEdgeSchema = z.object({
  fromDeclarationId: z.string().min(1),
  toDeclarationId: z.string().min(1),
  fromTypeName: z.string().min(1),
  toTypeName: z.string().min(1),
  kind: z.enum(['composition', 'reference']),
  cardinality: z.enum(['one', 'many']),
  propertyName: z.string().min(1),
});

const domainGraphSchema = z.object({
  nodes: z.array(domainGraphNodeSchema),
  edges: z.array(domainGraphEdgeSchema),
});

export type DomainDocConfig = z.infer<typeof domainDocConfigSchema>;
export type DomainGraph = z.infer<typeof domainGraphSchema>;
type DomainGraphNode = z.infer<typeof domainGraphNodeSchema>;
type DomainGraphEdge = z.infer<typeof domainGraphEdgeSchema>;

type TypeDeclaration = ts.InterfaceDeclaration | ts.TypeAliasDeclaration;
type IndexedDeclaration = Readonly<{
  declarationId: string;
  typeName: string;
  declaration: TypeDeclaration;
  domainDocKind: z.infer<typeof domainDocKindSchema> | null;
  sourcePath: string;
  sourceLine: number;
}>;
type Cardinality = 'one' | 'many';
type NodeShape = 'object' | 'union' | 'collection' | 'scalar';

type PropertyMetadata = Readonly<{
  property: z.infer<typeof domainGraphPropertySchema>;
  relationCandidates: ReadonlyArray<RelationCandidate>;
}>;

type RelationCandidate = Readonly<{
  targetDeclarationId: string;
  targetTypeName: string;
  cardinality: Cardinality;
}>;

type GraphBuildContext = Readonly<{
  declarationsById: Map<string, IndexedDeclaration>;
  declarationIdBySymbol: Map<ts.Symbol, string>;
  typeChecker: ts.TypeChecker;
  entityDomainByTypeName: Map<
    string,
    z.infer<typeof domainDocEntityDomainSchema>
  >;
  nodesByDeclarationId: Map<string, DomainGraphNode>;
  orderedDeclarationIds: string[];
  edges: DomainGraphEdge[];
  edgeKeys: Set<string>;
}>;

const collectionWrapperNames = new Set(['Array', 'ReadonlyArray']);
const passthroughWrapperNames = new Set(['Readonly']);
const typePrinter = ts.createPrinter({ removeComments: true });

/**
 * Domain ドキュメント生成設定を検証する。
 */
export const parseDomainDocConfig = (
  config: DomainDocConfig,
): DomainDocConfig => domainDocConfigSchema.parse(config);

/**
 * 指定設定からドメイン関係グラフを構築する。
 */
export const generateDomainGraph = async (
  inputConfig: DomainDocConfig,
): Promise<DomainGraph> => {
  const config = parseDomainDocConfig(inputConfig);
  const selectedFiles = await collectSelectedFiles(config.sources);
  const { declarationsById, declarationIdBySymbol, typeChecker } =
    collectDeclarationsById(selectedFiles, config.sourcePathBaseDirectory);
  const entityDomainByTypeName = createEntityDomainIndex(config);
  const annotatedEntityDeclarationIds = collectAnnotatedDeclarationIds(
    declarationsById,
    'entity',
  );
  if (annotatedEntityDeclarationIds.length === 0) {
    throw new Error('No @domainDocKind entity declarations found');
  }
  const context: GraphBuildContext = {
    declarationsById,
    declarationIdBySymbol,
    typeChecker,
    entityDomainByTypeName,
    nodesByDeclarationId: new Map<string, DomainGraphNode>(),
    orderedDeclarationIds: [],
    edges: [],
    edgeKeys: new Set<string>(),
  };

  for (const declarationId of annotatedEntityDeclarationIds) {
    const declaration = declarationsById.get(declarationId);
    if (declaration == null) {
      throw new Error(`Annotated declaration not found: ${declarationId}`);
    }
    ensureNode(
      context,
      declarationId,
      entityDomainByTypeName.get(declaration.typeName)?.domain ?? null,
      true,
    );
  }

  for (const relationHint of config.relationHints) {
    addHintedReference(context, relationHint);
  }

  const graph = domainGraphSchema.parse({
    nodes: context.orderedDeclarationIds.map((declarationId) => {
      const node = context.nodesByDeclarationId.get(declarationId);
      if (node == null) {
        throw new Error(`Graph node not found: ${declarationId}`);
      }
      return node;
    }),
    edges: context.edges,
  });

  return graph;
};

/**
 * Domain グラフを Mermaid classDiagram へ変換する。
 */
export const renderMermaidClassDiagram = (graph: DomainGraph): string => {
  const lines = ['classDiagram'];
  const entityNodes = graph.nodes.filter((node) => node.kind === 'entity');
  const entityTypeNames = new Set(
    entityNodes.map((entityNode) => entityNode.typeName),
  );

  for (const node of entityNodes) {
    lines.push(`class ${node.typeName} {`);
    if (node.shape === 'union') {
      lines.push('  <<union>>');
    }

    for (const property of node.properties) {
      lines.push(`  ${property.name}: ${property.typeText}`);
    }

    lines.push('}');
  }

  for (const edge of graph.edges) {
    if (
      !entityTypeNames.has(edge.fromTypeName) ||
      !entityTypeNames.has(edge.toTypeName)
    ) {
      continue;
    }

    const arrow = edge.kind === 'composition' ? '*--' : '-->';
    const toCardinality = edge.cardinality === 'many' ? '*' : '1';
    lines.push(
      `${edge.fromTypeName} "1" ${arrow} "${toCardinality}" ${edge.toTypeName} : ${edge.propertyName}`,
    );
  }

  return `${lines.join('\n')}\n`;
};

/**
 * Mermaid を埋め込んだ Markdown 文書を生成する。
 */
export const renderDomainDocMarkdown = (
  title: string,
  graph: DomainGraph,
  mermaid: string,
): string => {
  const entityTypeNames = new Set(
    graph.nodes
      .filter((node) => node.kind === 'entity')
      .map((node) => node.typeName),
  );
  const nodeCount = entityTypeNames.size;
  const edgeCount = graph.edges.filter(
    (edge) =>
      entityTypeNames.has(edge.fromTypeName) &&
      entityTypeNames.has(edge.toTypeName),
  ).length;

  return `# ${title}

この文書は \`backend/scripts/generate-domain-doc.ts\` により自動生成されます。手動編集はしないでください。

- 表示対象: entity のみ
- ノード数: ${nodeCount}
- 関係数: ${edgeCount}

\`\`\`mermaid
${mermaid.trimEnd()}
\`\`\`
`;
};

const collectSelectedFiles = async (
  sources: ReadonlyArray<z.infer<typeof domainDocSourceSchema>>,
): Promise<ReadonlyArray<string>> => {
  const filePaths = new Set<string>();

  for (const source of sources) {
    const matcher = new RegExp(source.filePattern);
    const directoryEntries = await collectFilesRecursively(source.directory);

    for (const filePath of directoryEntries) {
      const normalizedFilePath = path.normalize(filePath);
      const relativePath = path.relative(source.directory, normalizedFilePath);

      if (matcher.test(relativePath)) {
        filePaths.add(normalizedFilePath);
      }
    }
  }

  return [...filePaths].sort((left, right) => left.localeCompare(right));
};

const collectFilesRecursively = async (
  directory: string,
): Promise<ReadonlyArray<string>> => {
  const entries = await readdir(directory, { withFileTypes: true });
  const filePaths: string[] = [];

  for (const entry of entries) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      const nestedFiles = await collectFilesRecursively(fullPath);
      filePaths.push(...nestedFiles);
      continue;
    }

    if (entry.isFile()) {
      filePaths.push(fullPath);
    }
  }

  return filePaths.sort((left, right) => left.localeCompare(right));
};

const collectDeclarationsById = (
  selectedFiles: ReadonlyArray<string>,
  sourcePathBaseDirectory: string,
): Readonly<{
  declarationsById: Map<string, IndexedDeclaration>;
  declarationIdBySymbol: Map<ts.Symbol, string>;
  typeChecker: ts.TypeChecker;
}> => {
  const program = ts.createProgram({
    rootNames: [...selectedFiles],
    options: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.ESNext,
      moduleResolution: ts.ModuleResolutionKind.Node10,
      strict: true,
      skipLibCheck: true,
      esModuleInterop: true,
    },
  });
  const typeChecker = program.getTypeChecker();
  const selectedFileSet = new Set(
    selectedFiles.map((filePath) => path.normalize(filePath)),
  );
  const normalizedSourcePathBaseDirectory = path.resolve(
    sourcePathBaseDirectory,
  );
  const declarationsById = new Map<string, IndexedDeclaration>();
  const declarationIdBySymbol = new Map<ts.Symbol, string>();

  for (const sourceFile of program.getSourceFiles()) {
    const normalizedSourcePath = path.normalize(sourceFile.fileName);
    if (!selectedFileSet.has(normalizedSourcePath)) {
      continue;
    }

    for (const statement of sourceFile.statements) {
      if (
        (ts.isTypeAliasDeclaration(statement) ||
          ts.isInterfaceDeclaration(statement)) &&
        isExportedStatement(statement)
      ) {
        const declarationName = statement.name.text;
        const sourcePath = toPortableRelativePath(
          normalizedSourcePathBaseDirectory,
          normalizedSourcePath,
        );
        const declarationId = createDeclarationId(sourcePath, declarationName);

        declarationsById.set(declarationId, {
          declarationId,
          typeName: declarationName,
          declaration: statement,
          domainDocKind: readDomainDocKind(statement),
          sourcePath,
          sourceLine: getNodeStartLine(sourceFile, statement),
        });
        const symbol = typeChecker.getSymbolAtLocation(statement.name);
        if (symbol != null) {
          declarationIdBySymbol.set(symbol, declarationId);
        }
      }
    }
  }

  return {
    declarationsById,
    declarationIdBySymbol,
    typeChecker,
  };
};

const createEntityDomainIndex = (
  config: DomainDocConfig,
): Map<string, z.infer<typeof domainDocEntityDomainSchema>> => {
  const entityDomainByTypeName = new Map<
    string,
    z.infer<typeof domainDocEntityDomainSchema>
  >();

  for (const entityDomain of config.entityDomains) {
    entityDomainByTypeName.set(entityDomain.typeName, entityDomain);
  }

  return entityDomainByTypeName;
};

const collectAnnotatedDeclarationIds = (
  declarationsById: Map<string, IndexedDeclaration>,
  kind: z.infer<typeof domainDocKindSchema>,
): ReadonlyArray<string> =>
  [...declarationsById.entries()]
    .filter(([, declaration]) => declaration.domainDocKind === kind)
    .map(([declarationId]) => declarationId);

const readDomainDocKind = (
  declaration: TypeDeclaration,
): z.infer<typeof domainDocKindSchema> | null => {
  const kindTags =
    declaration.jsDoc
      ?.flatMap((jsDoc) => [...(jsDoc.tags ?? [])])
      .filter((tag) => tag.tagName.text === 'domainDocKind') ?? [];

  if (kindTags.length === 0) {
    return null;
  }

  if (kindTags.length > 1) {
    throw new Error(
      `Duplicate @domainDocKind tag found: ${declaration.name.text}`,
    );
  }

  const kindValue = normalizeJSDocTagComment(kindTags[0].comment);
  if (kindValue == null) {
    throw new Error(
      `@domainDocKind tag requires a value: ${declaration.name.text}`,
    );
  }

  return domainDocKindSchema.parse(kindValue);
};

const ensureNode = (
  context: GraphBuildContext,
  declarationId: string,
  inferredDomain: string | null,
  requestedAsEntity: boolean,
): void => {
  const existingNode = context.nodesByDeclarationId.get(declarationId);
  if (existingNode != null) {
    existingNode.kind = requestedAsEntity ? 'entity' : existingNode.kind;
    if (existingNode.domain === null && inferredDomain !== null) {
      existingNode.domain = inferredDomain;
    }
    return;
  }

  const declaration = context.declarationsById.get(declarationId);
  if (declaration == null) {
    throw new Error(`Type declaration not found: ${declarationId}`);
  }

  const shape = resolveNodeShape(
    declaration.declaration,
    declaration,
    context,
    new Set<string>(),
  );
  if (shape === 'scalar' || shape === 'collection') {
    throw new Error(`Type is not graphable: ${declaration.typeName}`);
  }

  const properties = extractPropertiesFromDeclaration(
    declaration.declaration,
    declaration,
    context,
  );
  const entityDomain =
    context.entityDomainByTypeName.get(declaration.typeName)?.domain ?? null;
  const node: DomainGraphNode = {
    declarationId,
    typeName: declaration.typeName,
    kind:
      requestedAsEntity || declaration.domainDocKind === 'entity'
        ? 'entity'
        : 'valueObject',
    shape,
    domain: entityDomain ?? inferredDomain,
    sourcePath: declaration.sourcePath,
    sourceLine: declaration.sourceLine,
    properties: properties.map((entry) => entry.property),
  };

  context.nodesByDeclarationId.set(declarationId, node);
  context.orderedDeclarationIds.push(declarationId);

  for (const property of properties) {
    for (const relationCandidate of property.relationCandidates) {
      ensureNode(
        context,
        relationCandidate.targetDeclarationId,
        node.domain,
        false,
      );
      addEdge(context, {
        fromDeclarationId: declarationId,
        toDeclarationId: relationCandidate.targetDeclarationId,
        fromTypeName: declaration.typeName,
        toTypeName: relationCandidate.targetTypeName,
        kind: 'composition',
        cardinality: relationCandidate.cardinality,
        propertyName: property.property.name,
      });
    }
  }
};

const addHintedReference = (
  context: GraphBuildContext,
  hint: z.infer<typeof domainDocRelationHintSchema>,
): void => {
  const [sourceTypeName, propertyName] = hint.from.split('.');
  const sourceNodes = [...context.nodesByDeclarationId.values()].filter(
    (node) => node.typeName === sourceTypeName,
  );
  if (sourceNodes.length > 1) {
    throw new Error(`Hint source type is ambiguous: ${sourceTypeName}`);
  }
  if (sourceNodes.length === 0) {
    throw new Error(`Hint source node not found: ${hint.from}`);
  }
  const sourceNode = sourceNodes[0];

  const sourceProperty = sourceNode.properties.find(
    (property) => property.name === propertyName,
  );
  if (sourceProperty == null) {
    throw new Error(`Hint source property not found: ${hint.from}`);
  }

  const targetDeclarationIds = [...context.declarationsById.values()]
    .filter((declaration) => declaration.typeName === hint.to)
    .map((declaration) => declaration.declarationId);
  if (targetDeclarationIds.length !== 1) {
    throw new Error(`Hint target type must resolve uniquely: ${hint.to}`);
  }

  ensureNode(context, targetDeclarationIds[0], sourceNode.domain, false);

  addEdge(context, {
    fromDeclarationId: sourceNode.declarationId,
    toDeclarationId: targetDeclarationIds[0],
    fromTypeName: sourceTypeName,
    toTypeName: hint.to,
    kind: hint.kind,
    cardinality: 'one',
    propertyName,
  });
};

const addEdge = (context: GraphBuildContext, edge: DomainGraphEdge): void => {
  const edgeKey = [
    edge.fromDeclarationId,
    edge.toDeclarationId,
    edge.fromTypeName,
    edge.toTypeName,
    edge.kind,
    edge.cardinality,
    edge.propertyName,
  ].join(':');

  if (context.edgeKeys.has(edgeKey)) {
    return;
  }

  context.edgeKeys.add(edgeKey);
  context.edges.push(edge);
};

const extractPropertiesFromDeclaration = (
  declaration: TypeDeclaration,
  indexedDeclaration: IndexedDeclaration,
  context: GraphBuildContext,
): ReadonlyArray<PropertyMetadata> => {
  if (ts.isInterfaceDeclaration(declaration)) {
    return extractPropertiesFromMembers(
      declaration.members,
      indexedDeclaration,
      context,
    );
  }

  return extractPropertiesFromTypeNode(
    declaration.type,
    indexedDeclaration,
    context,
    new Set<string>([indexedDeclaration.declarationId]),
  );
};

const extractPropertiesFromTypeNode = (
  typeNode: ts.TypeNode,
  indexedDeclaration: IndexedDeclaration,
  context: GraphBuildContext,
  seenDeclarationIds: Set<string>,
): ReadonlyArray<PropertyMetadata> => {
  if (ts.isTypeReferenceNode(typeNode)) {
    const wrapperName = getIdentifierText(typeNode.typeName);

    if (passthroughWrapperNames.has(wrapperName)) {
      const wrappedNode = typeNode.typeArguments?.[0] ?? null;
      if (wrappedNode == null) {
        return [];
      }

      return extractPropertiesFromTypeNode(
        wrappedNode,
        indexedDeclaration,
        context,
        seenDeclarationIds,
      );
    }

    const referencedDeclaration = resolveIndexedDeclarationForTypeNode(
      typeNode,
      context,
    );
    if (
      referencedDeclaration == null ||
      seenDeclarationIds.has(referencedDeclaration.declarationId)
    ) {
      return [];
    }

    const nextSeenDeclarationIds = new Set(seenDeclarationIds);
    nextSeenDeclarationIds.add(referencedDeclaration.declarationId);

    if (ts.isInterfaceDeclaration(referencedDeclaration.declaration)) {
      return extractPropertiesFromMembers(
        referencedDeclaration.declaration.members,
        referencedDeclaration,
        context,
      );
    }

    return extractPropertiesFromTypeNode(
      referencedDeclaration.declaration.type,
      referencedDeclaration,
      context,
      nextSeenDeclarationIds,
    );
  }

  if (ts.isTypeLiteralNode(typeNode)) {
    return extractPropertiesFromMembers(
      typeNode.members,
      indexedDeclaration,
      context,
    );
  }

  return [];
};

const extractPropertiesFromMembers = (
  members: ts.NodeArray<ts.TypeElement>,
  indexedDeclaration: IndexedDeclaration,
  context: GraphBuildContext,
): ReadonlyArray<PropertyMetadata> => {
  const properties: PropertyMetadata[] = [];

  for (const member of members) {
    if (!ts.isPropertySignature(member) || member.type == null) {
      continue;
    }

    const propertyName = getPropertyNameText(member.name);
    if (propertyName === null) {
      continue;
    }

    properties.push({
      property: {
        name: propertyName,
        typeText: normalizeTypeText(
          typePrinter.printNode(
            ts.EmitHint.Unspecified,
            member.type,
            member.getSourceFile(),
          ),
        ),
      },
      relationCandidates: extractRelationCandidates(
        member.type,
        indexedDeclaration,
        context,
        new Set<string>(),
        'one',
      ),
    });
  }

  return properties;
};

const extractRelationCandidates = (
  typeNode: ts.TypeNode,
  indexedDeclaration: IndexedDeclaration,
  context: GraphBuildContext,
  seenDeclarationIds: Set<string>,
  cardinality: Cardinality,
): ReadonlyArray<RelationCandidate> => {
  if (ts.isParenthesizedTypeNode(typeNode)) {
    return extractRelationCandidates(
      typeNode.type,
      indexedDeclaration,
      context,
      seenDeclarationIds,
      cardinality,
    );
  }

  if (ts.isUnionTypeNode(typeNode)) {
    const relationCandidates: RelationCandidate[] = [];

    for (const unionMember of typeNode.types) {
      if (isNullishTypeNode(unionMember)) {
        continue;
      }

      relationCandidates.push(
        ...extractRelationCandidates(
          unionMember,
          indexedDeclaration,
          context,
          seenDeclarationIds,
          cardinality,
        ),
      );
    }

    return deduplicateRelationCandidates(relationCandidates);
  }

  if (ts.isTypeReferenceNode(typeNode)) {
    const typeName = getIdentifierText(typeNode.typeName);

    if (collectionWrapperNames.has(typeName)) {
      const elementType = typeNode.typeArguments?.[0] ?? null;
      if (elementType == null) {
        return [];
      }

      return extractRelationCandidates(
        elementType,
        indexedDeclaration,
        context,
        seenDeclarationIds,
        'many',
      );
    }

    if (passthroughWrapperNames.has(typeName)) {
      const wrappedType = typeNode.typeArguments?.[0] ?? null;
      if (wrappedType == null) {
        return [];
      }

      return extractRelationCandidates(
        wrappedType,
        indexedDeclaration,
        context,
        seenDeclarationIds,
        cardinality,
      );
    }

    const declaration = resolveIndexedDeclarationForTypeNode(typeNode, context);
    if (declaration == null) {
      return [];
    }

    if (seenDeclarationIds.has(declaration.declarationId)) {
      return [];
    }

    const nextSeenDeclarationIds = new Set(seenDeclarationIds);
    nextSeenDeclarationIds.add(declaration.declarationId);
    const shape = resolveNodeShape(
      declaration.declaration,
      declaration,
      context,
      nextSeenDeclarationIds,
    );

    if (
      shape === 'collection' &&
      ts.isTypeAliasDeclaration(declaration.declaration)
    ) {
      return extractRelationCandidates(
        declaration.declaration.type,
        declaration,
        context,
        nextSeenDeclarationIds,
        cardinality,
      );
    }

    if (shape === 'object' || shape === 'union') {
      return [
        {
          targetDeclarationId: declaration.declarationId,
          targetTypeName: typeName,
          cardinality,
        },
      ];
    }

    return [];
  }

  return [];
};

const deduplicateRelationCandidates = (
  relationCandidates: ReadonlyArray<RelationCandidate>,
): ReadonlyArray<RelationCandidate> => {
  const relationCandidateMap = new Map<string, RelationCandidate>();

  for (const relationCandidate of relationCandidates) {
    const relationKey = `${relationCandidate.targetTypeName}:${relationCandidate.cardinality}`;
    if (!relationCandidateMap.has(relationKey)) {
      relationCandidateMap.set(relationKey, relationCandidate);
    }
  }

  return [...relationCandidateMap.values()];
};

const resolveNodeShape = (
  declaration: TypeDeclaration,
  indexedDeclaration: IndexedDeclaration,
  context: GraphBuildContext,
  seenDeclarationIds: Set<string>,
): NodeShape => {
  if (ts.isInterfaceDeclaration(declaration)) {
    return 'object';
  }

  return resolveTypeNodeShape(
    declaration.type,
    indexedDeclaration,
    context,
    seenDeclarationIds,
  );
};

const resolveTypeNodeShape = (
  typeNode: ts.TypeNode,
  indexedDeclaration: IndexedDeclaration,
  context: GraphBuildContext,
  seenDeclarationIds: Set<string>,
): NodeShape => {
  if (ts.isTypeLiteralNode(typeNode)) {
    return 'object';
  }

  if (ts.isUnionTypeNode(typeNode)) {
    const nonNullishMembers = typeNode.types.filter(
      (unionMember) => !isNullishTypeNode(unionMember),
    );
    if (nonNullishMembers.length === 0) {
      return 'scalar';
    }

    for (const unionMember of nonNullishMembers) {
      const memberShape = resolveTypeNodeShape(
        unionMember,
        indexedDeclaration,
        context,
        seenDeclarationIds,
      );
      if (memberShape !== 'scalar') {
        return 'union';
      }
    }

    return 'scalar';
  }

  if (ts.isParenthesizedTypeNode(typeNode)) {
    return resolveTypeNodeShape(
      typeNode.type,
      indexedDeclaration,
      context,
      seenDeclarationIds,
    );
  }

  if (ts.isTypeReferenceNode(typeNode)) {
    const typeName = getIdentifierText(typeNode.typeName);

    if (collectionWrapperNames.has(typeName)) {
      return 'collection';
    }

    if (passthroughWrapperNames.has(typeName)) {
      const wrappedType = typeNode.typeArguments?.[0] ?? null;
      if (wrappedType == null) {
        return 'scalar';
      }

      return resolveTypeNodeShape(
        wrappedType,
        indexedDeclaration,
        context,
        seenDeclarationIds,
      );
    }

    if (typeName === 'Brand') {
      return 'scalar';
    }

    const referencedDeclaration = resolveIndexedDeclarationForTypeNode(
      typeNode,
      context,
    );
    if (
      referencedDeclaration == null ||
      seenDeclarationIds.has(referencedDeclaration.declarationId)
    ) {
      return 'scalar';
    }

    const nextSeenDeclarationIds = new Set(seenDeclarationIds);
    nextSeenDeclarationIds.add(referencedDeclaration.declarationId);

    return resolveNodeShape(
      referencedDeclaration.declaration,
      referencedDeclaration,
      context,
      nextSeenDeclarationIds,
    );
  }

  return 'scalar';
};

const normalizeJSDocTagComment = (
  comment: ts.JSDocTag['comment'],
): string | null => {
  if (comment == null) {
    return null;
  }

  if (typeof comment === 'string') {
    const normalizedComment = comment.trim();
    return normalizedComment.length > 0 ? normalizedComment : null;
  }

  const normalizedComment = comment
    .map((commentPart) =>
      typeof commentPart === 'string' ? commentPart : commentPart.text,
    )
    .join('')
    .trim();

  return normalizedComment.length > 0 ? normalizedComment : null;
};

const normalizeTypeText = (value: string): string =>
  value.replace(/\s+/g, ' ').trim();

const createDeclarationId = (sourcePath: string, typeName: string): string =>
  `${sourcePath}:${typeName}`;

const resolveIndexedDeclarationForTypeNode = (
  typeNode: ts.TypeReferenceNode,
  context: GraphBuildContext,
): IndexedDeclaration | null => {
  const symbol = context.typeChecker.getSymbolAtLocation(typeNode.typeName);
  if (symbol == null) {
    return null;
  }

  const resolvedSymbol =
    symbol.flags & ts.SymbolFlags.Alias
      ? context.typeChecker.getAliasedSymbol(symbol)
      : symbol;
  const declarationId = context.declarationIdBySymbol.get(resolvedSymbol);
  if (declarationId == null) {
    return null;
  }

  return context.declarationsById.get(declarationId) ?? null;
};

const toPortableRelativePath = (
  baseDirectory: string,
  filePath: string,
): string => path.relative(baseDirectory, filePath).split(path.sep).join('/');

const getNodeStartLine = (sourceFile: ts.SourceFile, node: ts.Node): number =>
  sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1;

const isExportedStatement = (statement: ts.Statement): boolean =>
  ts.canHaveModifiers(statement) &&
  (ts
    .getModifiers(statement)
    ?.some((modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword) ??
    false);

const getIdentifierText = (typeName: ts.EntityName): string =>
  ts.isIdentifier(typeName) ? typeName.text : typeName.right.text;

const getPropertyNameText = (propertyName: ts.PropertyName): string | null => {
  if (ts.isIdentifier(propertyName) || ts.isStringLiteral(propertyName)) {
    return propertyName.text;
  }

  return null;
};

const isNullishTypeNode = (typeNode: ts.TypeNode): boolean => {
  if (typeNode.kind === ts.SyntaxKind.UndefinedKeyword) {
    return true;
  }

  return (
    ts.isLiteralTypeNode(typeNode) &&
    typeNode.literal.kind === ts.SyntaxKind.NullKeyword
  );
};
