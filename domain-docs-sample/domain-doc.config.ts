import path from 'node:path';
import { fileURLToPath } from 'node:url';

import type { DomainDocConfig } from './domain-doc.js';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(scriptDirectory, '..');
const repositoryRoot = path.resolve(backendRoot, '..');

/**
 * 現行 backend のドメイン型関係図生成設定。
 */
export const domainDocConfig: DomainDocConfig = {
  sourcePathBaseDirectory: repositoryRoot,
  sources: [
    {
      directory: path.join(backendRoot, 'src/domain'),
      filePattern: '\\.(types|entity)\\.ts$',
    },
  ],
  entityDomains: [
    {
      typeName: 'ProjectEntity',
      domain: 'project',
    },
    {
      typeName: 'MapFeature',
      domain: 'map',
    },
    {
      typeName: 'MapOperationSite',
      domain: 'map-operations',
    },
    {
      typeName: 'RouteBusinessOperation',
      domain: 'route-planning',
    },
    {
      typeName: 'DrivingRuleDefinition',
      domain: 'driving-rule-governance',
    },
    {
      typeName: 'DrivingRuleAssignment',
      domain: 'driving-rule-governance',
    },
    {
      typeName: 'DrivingRuleZone',
      domain: 'driving-rule-governance',
    },
    {
      typeName: 'ConditionSet',
      domain: 'driving-rule-governance',
    },
    {
      typeName: 'ConditionItem',
      domain: 'driving-rule-governance',
    },
    {
      typeName: 'DrivingRuleAssignmentSubject',
      domain: 'driving-rule-governance',
    },
    {
      typeName: 'RuleScope',
      domain: 'driving-rule-governance',
    },
    {
      typeName: 'VehicleProfile',
      domain: 'vehicle',
    },
  ],
  relationHints: [
    {
      from: 'RouteBusinessOperation.operationSiteId',
      to: 'MapOperationSite',
      kind: 'reference',
    },
    {
      from: 'DrivingRuleAssignment.drivingRuleDefinitionId',
      to: 'DrivingRuleDefinition',
      kind: 'reference',
    },
  ],
};

/**
 * 生成 Markdown 出力先。
 */
export const domainDocMarkdownOutputPath = path.join(
  repositoryRoot,
  'docs/10-product-spec/domain-diagram.generated.md',
);

/**
 * 中間表現 JSON 出力先。
 */
export const domainDocJsonOutputPath = path.join(
  repositoryRoot,
  'docs/10-product-spec/domain-diagram.generated.json',
);
