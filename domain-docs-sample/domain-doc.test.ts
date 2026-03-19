import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';

import {
  generateDomainGraph,
  renderMermaidClassDiagram,
  type DomainDocConfig,
} from './domain-doc.js';

const tempDirectories: string[] = [];

const createFixtureProject = async (): Promise<string> => {
  const tempDirectory = await mkdtemp(
    path.join(os.tmpdir(), 'domain-doc-generator-'),
  );
  tempDirectories.push(tempDirectory);

  const billingDirectory = path.join(tempDirectory, 'billing');
  const salesDirectory = path.join(tempDirectory, 'sales');
  await mkdir(billingDirectory, { recursive: true });
  await mkdir(salesDirectory, { recursive: true });

  await writeFile(
    path.join(billingDirectory, 'invoice.domain.ts'),
    `export type InvoiceId = string;

/**
 * @domainDocKind entity
 */
export type Invoice = Readonly<{
  invoiceId: InvoiceId;
  issuedAt: string;
}>;`,
  );

  await writeFile(
    path.join(salesDirectory, 'order.domain.ts'),
    `export type OrderId = string;

export type Customer = Readonly<{
  customerId: string;
  name: string;
}>;

export type LineItem = Readonly<{
  sku: string;
  quantity: number;
}>;

/**
 * @domainDocKind entity
 */
export type Order = Readonly<{
  orderId: OrderId;
  customer: Customer;
  items: ReadonlyArray<LineItem>;
  invoiceId: string;
}>;`,
  );

  await writeFile(
    path.join(salesDirectory, 'ignored.ts'),
    `export type IgnoredEntity = Readonly<{
  ignored: boolean;
}>;`,
  );

  return tempDirectory;
};

describe('generateDomainGraph', () => {
  afterEach(async () => {
    for (const tempDirectory of tempDirectories.splice(0)) {
      await rm(tempDirectory, { recursive: true, force: true });
    }
  });

  it('ディレクトリとファイル正規表現で対象を絞り、構成関係と参照ヒントを抽出できる', async () => {
    const fixtureDirectory = await createFixtureProject();
    const config: DomainDocConfig = {
      sourcePathBaseDirectory: fixtureDirectory,
      sources: [
        {
          directory: fixtureDirectory,
          filePattern: '\\.domain\\.ts$',
        },
      ],
      entityDomains: [
        {
          typeName: 'Order',
          domain: 'sales',
        },
        {
          typeName: 'Invoice',
          domain: 'billing',
        },
      ],
      relationHints: [
        {
          from: 'Order.invoiceId',
          to: 'Invoice',
          kind: 'reference',
        },
      ],
    };

    const graph = await generateDomainGraph(config);

    expect(graph.nodes.map((node) => node.typeName)).toEqual([
      'Invoice',
      'Order',
      'Customer',
      'LineItem',
    ]);

    expect(graph.edges).toEqual([
      expect.objectContaining({
        fromTypeName: 'Order',
        toTypeName: 'Customer',
        kind: 'composition',
        cardinality: 'one',
        propertyName: 'customer',
      }),
      expect.objectContaining({
        fromTypeName: 'Order',
        toTypeName: 'LineItem',
        kind: 'composition',
        cardinality: 'many',
        propertyName: 'items',
      }),
      expect.objectContaining({
        fromTypeName: 'Order',
        toTypeName: 'Invoice',
        kind: 'reference',
        cardinality: 'one',
        propertyName: 'invoiceId',
      }),
    ]);

    expect(graph.nodes.find((node) => node.typeName === 'Order')).toMatchObject(
      {
        typeName: 'Order',
        kind: 'entity',
        domain: 'sales',
        sourcePath: 'sales/order.domain.ts',
        sourceLine: 16,
        properties: [
          { name: 'orderId', typeText: 'OrderId' },
          { name: 'customer', typeText: 'Customer' },
          { name: 'items', typeText: 'ReadonlyArray<LineItem>' },
          { name: 'invoiceId', typeText: 'string' },
        ],
      },
    );
    expect(graph.nodes.find((node) => node.typeName === 'Customer')?.kind).toBe(
      'valueObject',
    );
    expect(graph.nodes.find((node) => node.typeName === 'Invoice')?.kind).toBe(
      'entity',
    );
  });

  it('classDiagram として Mermaid を出力できる', async () => {
    const fixtureDirectory = await createFixtureProject();
    const config: DomainDocConfig = {
      sourcePathBaseDirectory: fixtureDirectory,
      sources: [
        {
          directory: fixtureDirectory,
          filePattern: '\\.domain\\.ts$',
        },
      ],
      entityDomains: [
        {
          typeName: 'Order',
          domain: 'sales',
        },
        {
          typeName: 'Invoice',
          domain: 'billing',
        },
      ],
      relationHints: [
        {
          from: 'Order.invoiceId',
          to: 'Invoice',
          kind: 'reference',
        },
      ],
    };

    const graph = await generateDomainGraph(config);
    const mermaid = renderMermaidClassDiagram(graph);

    expect(mermaid).toContain('classDiagram');
    expect(mermaid).toContain('class Order {');
    expect(mermaid).toContain('class Invoice {');
    expect(mermaid).toContain('Order "1" --> "1" Invoice : invoiceId');
    expect(mermaid).not.toContain('class Customer {');
    expect(mermaid).not.toContain('class LineItem {');
    expect(mermaid).not.toContain('IgnoredEntity');
  });

  it('sourcePath を基準ディレクトリからの相対パスで保持し、sourceLine を持てる', async () => {
    const fixtureDirectory = await createFixtureProject();
    const config: DomainDocConfig = {
      sourcePathBaseDirectory: fixtureDirectory,
      sources: [
        {
          directory: fixtureDirectory,
          filePattern: '\\.domain\\.ts$',
        },
      ],
      entityDomains: [
        {
          typeName: 'Order',
          domain: 'sales',
        },
        {
          typeName: 'Invoice',
          domain: 'billing',
        },
      ],
      relationHints: [
        {
          from: 'Order.invoiceId',
          to: 'Invoice',
          kind: 'reference',
        },
      ],
    };

    const graph = await generateDomainGraph(config);

    expect(graph.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          typeName: 'Order',
          sourcePath: 'sales/order.domain.ts',
          sourceLine: 16,
        }),
        expect.objectContaining({
          typeName: 'Customer',
          sourcePath: 'sales/order.domain.ts',
          sourceLine: 3,
        }),
        expect.objectContaining({
          typeName: 'LineItem',
          sourcePath: 'sales/order.domain.ts',
          sourceLine: 8,
        }),
        expect.objectContaining({
          typeName: 'Invoice',
          sourcePath: 'billing/invoice.domain.ts',
          sourceLine: 6,
        }),
      ]),
    );
  });

  it('別ファイルに同名の export 型があっても、到達する型を解決できる', async () => {
    const fixtureDirectory = await createFixtureProject();
    const sharedDirectory = path.join(fixtureDirectory, 'shared');
    await mkdir(sharedDirectory, { recursive: true });

    await writeFile(
      path.join(sharedDirectory, 'sales-metadata.domain.ts'),
      `export type Metadata = Readonly<{
  salesChannel: string;
}>;`,
    );
    await writeFile(
      path.join(sharedDirectory, 'billing-metadata.domain.ts'),
      `export type Metadata = Readonly<{
  billingCode: string;
}>;`,
    );
    await writeFile(
      path.join(sharedDirectory, 'shipment.domain.ts'),
      `import type { Metadata } from './sales-metadata.domain.js';

/**
 * @domainDocKind entity
 */
export type Shipment = Readonly<{
  shipmentId: string;
  metadata: Metadata;
}>;`,
    );

    const config: DomainDocConfig = {
      sourcePathBaseDirectory: fixtureDirectory,
      sources: [
        {
          directory: fixtureDirectory,
          filePattern: '\\.domain\\.ts$',
        },
      ],
      entityDomains: [
        {
          typeName: 'Shipment',
          domain: 'shipping',
        },
      ],
      relationHints: [],
    };

    const graph = await generateDomainGraph(config);

    expect(graph.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          typeName: 'Shipment',
          sourcePath: 'shared/shipment.domain.ts',
        }),
        expect.objectContaining({
          typeName: 'Metadata',
          sourcePath: 'shared/sales-metadata.domain.ts',
          kind: 'valueObject',
        }),
      ]),
    );
    expect(graph.nodes).not.toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          typeName: 'Metadata',
          sourcePath: 'shared/billing-metadata.domain.ts',
        }),
      ]),
    );
    expect(graph.edges).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          fromTypeName: 'Shipment',
          toTypeName: 'Metadata',
          propertyName: 'metadata',
        }),
      ]),
    );
  });
});
