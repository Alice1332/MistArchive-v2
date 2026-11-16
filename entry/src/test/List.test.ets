import { describe, it, expect } from '@ohos/hypium';
import { CASES, CaseDef } from '../main/ets/testing/CoreCases';
export default function testsuite(): void {
  describe('MistArchiveCore', () => {
    CASES.forEach((c: CaseDef) => {
      it(`${c.id} ${c.name}`, 0, async () => { await c.run(); expect(true).assertTrue(); });
    });
  });
}
