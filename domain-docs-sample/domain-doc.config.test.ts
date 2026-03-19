import { describe, expect, it } from 'vitest';

import { domainDocConfig } from './domain-doc.config.js';

describe('domainDocConfig', () => {
  it('backend/src/application を domain-doc の対象スコープに含めない', () => {
    expect(
      domainDocConfig.sources.some((source) =>
        source.directory.includes('/src/application'),
      ),
    ).toBe(false);
  });

  it('application 配下の型を entityDomains に含めない', () => {
    expect(
      domainDocConfig.entityDomains.map(
        (entityDomain) => entityDomain.typeName,
      ),
    ).not.toContain('RoutePlanManagementRecord');
    expect(
      domainDocConfig.entityDomains.map(
        (entityDomain) => entityDomain.typeName,
      ),
    ).not.toContain('RoutePlanRouteRecord');
  });
});
