import { GameState, TextStore, SaveEnvelope } from '../model/GameModel';
import { GameEngine, freshState } from '../domain/GameEngine';
import { encode, decode, checksum } from '../domain/SaveCodec';
import { SaveRepository, CURRENT, BACKUP } from '../data/SaveRepository';
import { InvestigationSession } from '../domain/InvestigationSession';
import { EVENTS } from '../data/CaseData';
export interface CaseDef { id: string; category: string; name: string; run: () => Promise<void>; }
function check(condition: boolean, message: string = '断言失败'): void { if (!condition) throw new Error(message); }
function equal(a: string, b: string): void { check(a === b, `${a} != ${b}`); }
function rejectsDecode(raw: string): void { let rejected = false; try { decode(raw); } catch (_) { rejected = true; } check(rejected); }
export function play(cooperation: string = 'cooperate', suspect: string = 'transfer', verify: boolean = true, count: number = 12): GameState {
  let s = freshState(); const engine = new GameEngine();
  for (let i = 0; i < EVENTS.length && i < count; i++) {
    const e = EVENTS[i];
    if (e.id === 'e10' && (!verify || cooperation === 'accuse')) continue;
    const moved = engine.move(s, e.sceneId); check(moved.ok, moved.message);
    const choice = e.id === 'e06' ? cooperation : e.id === 'e11' ? suspect : '';
    const step = engine.investigate(moved.state, e.id, choice); check(step.ok, step.message); s = step.state;
  }
  return s;
}
export class MemoryStore implements TextStore {
  current: string = ''; backup: string = ''; failFlush: boolean = false; failRead: boolean = false; failWrite: boolean = false;
  async read(key: string): Promise<string> { if (this.failRead) throw new Error('模拟读失败'); return key === CURRENT ? this.current : this.backup; }
  async write(key: string, value: string): Promise<void> { if (this.failWrite) throw new Error('模拟写失败'); if (key === CURRENT) this.current = value; else this.backup = value; }
  async flush(): Promise<void> { if (this.failFlush) throw new Error('模拟空间不足'); }
}
export const CASES: CaseDef[] = [
  { id: 'T01', category: '正常', name: '新调查状态为空且位于门卫室', run: async () => { const s = freshState(); equal(s.sceneId, 'gate'); check(s.clues.length === 0 && s.events.length === 0); } },
  { id: 'T02', category: '边界', name: '未解锁场景不可进入', run: async () => { const e = new GameEngine(); check(!e.move(freshState(), 'library').ok); check(!e.move(freshState(), 'unknown').ok); } },
  { id: 'T03', category: '异常', name: '越级事件和未知事件被拒绝', run: async () => { const e = new GameEngine(); check(!e.investigate(freshState(), 'e03').ok); check(!e.investigate(freshState(), 'e99').ok); } },
  { id: 'T04', category: '边界', name: '重复调查不增量且输入状态不突变', run: async () => { const e = new GameEngine(); const s = freshState(); const next = e.investigate(s, 'e01'); check(s.events.length === 0); check(next.state.events.length === 1); check(!e.investigate(next.state, 'e01').ok); } },
  { id: 'T05', category: '异常', name: '非法选择参数被拒绝', run: async () => { const s = play('cooperate', 'transfer', true, 5); const e = new GameEngine(); check(!e.investigate(s, 'e06', 'invalid').ok); check(!e.investigate(freshState(), 'e01', 'extra').ok); } },
  { id: 'T06', category: '正常', name: '合作路线取得六条线索并进入真相结局', run: async () => { const s = play(); equal(s.ending, 'truth'); check(s.events.length === 12 && s.clues.length === 6); } },
  { id: 'T07', category: '正常', name: '指责路线缺失回执并进入未竟结局', run: async () => { const s = play('accuse'); equal(s.ending, 'rush'); check(!s.clues.includes('c04') && s.clues.length === 5); } },
  { id: 'T08', category: '边界', name: '有全套线索但未核验仍为未竟结局', run: async () => { const s = play('cooperate', 'transfer', false); equal(s.ending, 'rush'); check(s.clues.length === 6); } },
  { id: 'T09', category: '异常', name: '错误最终判断不能触发真相结局', run: async () => { equal(play('cooperate', 'theft').ending, 'rush'); } },
  { id: 'T10', category: '边界', name: '结局后禁止继续执行事件', run: async () => { const s = play(); check(!new GameEngine().investigate(s, 'e01').ok); equal(s.ending, 'truth'); } },
  { id: 'T11', category: '正常', name: '中途存档可往返恢复', run: async () => { const s = play('cooperate', 'transfer', true, 7); equal(JSON.stringify(decode(encode(s))), JSON.stringify(s)); } },
  { id: 'T12', category: '正常', name: '结束状态可往返恢复', run: async () => { const s = play(); equal(JSON.stringify(decode(encode(s))), JSON.stringify(s)); } },
  { id: 'T13', category: '异常', name: '损坏JSON和校验值被拒绝', run: async () => { rejectsDecode('{broken'); rejectsDecode('null'); const env = JSON.parse(encode(freshState())) as SaveEnvelope; env.checksum = 0; rejectsDecode(JSON.stringify(env)); } },
  { id: 'T14', category: '异常', name: '不支持的存档版本被拒绝', run: async () => { const env = JSON.parse(encode(freshState())) as SaveEnvelope; env.version = 99; rejectsDecode(JSON.stringify(env)); } },
  { id: 'T15', category: '异常', name: '重算校验值也不能伪造线索', run: async () => { const s = freshState(); s.clues.push('c06'); rejectsDecode(encode(s)); } },
  { id: 'T16', category: '异常', name: '非法历史顺序与非数组结构被拒绝', run: async () => { const s = freshState(); s.history.push({ eventId: 'e12', choice: '' }); rejectsDecode(encode(s)); const raw = '{"history":1,"events":[],"clues":[]}'; rejectsDecode(JSON.stringify({ version: 1, payload: raw, checksum: checksum(raw), savedAt: 0 })); } },
  { id: 'T17', category: '正常', name: '空存储返回新调查', run: async () => { equal((await new SaveRepository(new MemoryStore()).load()).source, 'new'); } },
  { id: 'T18', category: '正常', name: '主存档恢复与滚动备份', run: async () => { const m = new MemoryStore(); const r = new SaveRepository(m); const s = play('cooperate', 'transfer', true, 4); await r.save(freshState()); await r.save(s); equal(JSON.stringify((await r.load()).state), JSON.stringify(s)); check(decode(m.backup).events.length === 0); } },
  { id: 'T19', category: '异常', name: '主档损坏回退至有效备份', run: async () => { const m = new MemoryStore(); m.current = 'bad'; m.backup = encode(play('cooperate', 'transfer', true, 4)); const loaded = await new SaveRepository(m).load(); equal(loaded.source, 'backup'); check(loaded.state.events.length === 4); equal(m.current, 'bad'); } },
  { id: 'T20', category: '异常', name: '双档损坏报错且原始内容不覆盖', run: async () => { const m = new MemoryStore(); m.current = 'bad'; m.backup = 'also bad'; let failed = false; try { await new SaveRepository(m).load(); } catch (_) { failed = true; } check(failed); equal(m.current, 'bad'); equal(m.backup, 'also bad'); } },
  { id: 'T21', category: '异常', name: 'flush失败回滚当前缓存', run: async () => { const m = new MemoryStore(); const r = new SaveRepository(m); await r.save(freshState()); const old = m.current; m.failFlush = true; let failed = false; try { await r.save(play('cooperate', 'transfer', true, 4)); } catch (_) { failed = true; } check(failed); equal(m.current, old); } },
  { id: 'T22', category: '异常', name: '读失败向调用者报告', run: async () => { const m = new MemoryStore(); m.failRead = true; let failed = false; try { await new SaveRepository(m).load(); } catch (_) { failed = true; } check(failed); } },
  { id: 'T23', category: '边界', name: '独立仓库实例恢复同一存储进度', run: async () => { const m = new MemoryStore(); await new SaveRepository(m).save(play('cooperate', 'transfer', true, 8)); const loaded = await new SaveRepository(m).load(); check(loaded.state.events.length === 8 && loaded.state.clues.length === 5); } },
  { id: 'T24', category: '边界', name: '被篡改的派生结局不能恢复', run: async () => { const s = play('cooperate', 'theft'); s.ending = 'truth'; rejectsDecode(encode(s)); } },
  { id: 'V201', category: '边界', name: '未解锁事件只显示原因，不泄露结果', run: async () => { const e = new GameEngine(); const item = EVENTS[1]; equal(e.eventDescription(freshState(), item), e.reason(freshState(), item)); check(e.eventDescription(freshState(), item) !== item.text); } },
  { id: 'V202', category: '正常', name: '已解锁未调查时仍隐藏结果，完成后显示', run: async () => { const e = new GameEngine(); const item = EVENTS[0]; const s = freshState(); check(e.eventDescription(s, item) !== item.text); equal(e.eventDescription(e.investigate(s, item.id).state, item), item.text); } },
  { id: 'V203', category: '边界', name: '询问方式选择前不提前揭示分支后果', run: async () => { const e = new GameEngine(); const s = e.move(play('cooperate', 'transfer', true, 5), 'library').state; const item = EVENTS[5]; check(e.reason(s, item) === ''); check(e.eventDescription(s, item) !== item.text); check(!e.eventDescription(s, item).includes('回执')); } },
  { id: 'V204', category: '异常', name: '页面会话保存写入失败不发布新状态，重试推进一次', run: async () => { const m = new MemoryStore(); const session = new InvestigationSession(new SaveRepository(m)); await session.open(); const result = new GameEngine().investigate(session.state, 'e01'); m.failWrite = true; check(!await session.commit(result)); check(session.state.events.length === 0 && !session.busy && session.message.includes('保存失败')); m.failWrite = false; check(await session.commit(result)); check(session.state.events.length === 1); } },
  { id: 'V205', category: '异常', name: '页面会话flush失败保留页面和存储，重试可恢复', run: async () => { const m = new MemoryStore(); const session = new InvestigationSession(new SaveRepository(m)); await session.open(); const result = new GameEngine().investigate(session.state, 'e01'); m.failFlush = true; check(!await session.commit(result)); check(session.state.events.length === 0 && m.current === ''); m.failFlush = false; check(await session.commit(result)); check(decode(m.current).events.length === 1); } },
  { id: 'V206', category: '边界', name: '保存期间立即再次提交不会重复推进', run: async () => { const session = new InvestigationSession(new SaveRepository(new MemoryStore())); await session.open(); const result = new GameEngine().investigate(session.state, 'e01'); const first = session.commit(result); check(session.busy); check(!await session.commit(result)); check(await first); check(session.state.events.length === 1 && !session.busy); } },
  { id: 'V207', category: '异常', name: '读取失败后禁止调查，重试成功后可继续', run: async () => { const m = new MemoryStore(); m.failRead = true; const session = new InvestigationSession(new SaveRepository(m)); await session.open(); check(!session.ready && !session.busy); check(!await session.commit(new GameEngine().investigate(session.state, 'e01'))); m.failRead = false; await session.open(); check(session.ready); } },
  { id: 'V208', category: '异常', name: '重开写入失败保留已有进度，重试成功后归零', run: async () => { const m = new MemoryStore(); const session = new InvestigationSession(new SaveRepository(m)); await session.open(); await session.commit(new GameEngine().investigate(session.state, 'e01')); m.failWrite = true; check(!await session.restart()); check(session.state.events.length === 1); m.failWrite = false; check(await session.restart()); check(session.state.events.length === 0); } }

];
