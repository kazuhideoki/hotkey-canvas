import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

import {
  domainDocConfig,
  domainDocJsonOutputPath,
  domainDocMarkdownOutputPath,
} from './domain-doc.config.js';
import {
  generateDomainGraph,
  renderDomainDocMarkdown,
  renderMermaidClassDiagram,
} from './domain-doc.js';

/**
 * 現行 backend 型からドメイン関係図と中間 JSON を生成する。
 */
const run = async (): Promise<void> => {
  const graph = await generateDomainGraph(domainDocConfig);
  const mermaid = renderMermaidClassDiagram(graph);
  const markdown = renderDomainDocMarkdown(
    'ドメイン型関係図（生成）',
    graph,
    mermaid,
  );

  await mkdir(path.dirname(domainDocMarkdownOutputPath), { recursive: true });
  await writeFile(domainDocMarkdownOutputPath, markdown);
  await writeFile(domainDocJsonOutputPath, JSON.stringify(graph, null, 2));

  console.log(`Wrote ${domainDocMarkdownOutputPath}`);
  console.log(`Wrote ${domainDocJsonOutputPath}`);
};

void run();
