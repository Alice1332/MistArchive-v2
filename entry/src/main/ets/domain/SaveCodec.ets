import { GameState, SaveEnvelope, HistoryItem } from '../model/GameModel';
import { EVENTS } from '../data/CaseData';
import { GameEngine, freshState } from './GameEngine';
export function checksum(text: string): number {
  let hash = 2166136261;
  for (let i = 0; i < text.length; i++) { hash ^= text.charCodeAt(i); hash = Math.imul(hash, 16777619); }
  return hash >>> 0;
}
export function encode(s: GameState): string {
  const payload = JSON.stringify(s);
  const envelope: SaveEnvelope = { version: 1, payload: payload, checksum: checksum(payload), savedAt: Date.now() };
  return JSON.stringify(envelope);
}
export function decode(raw: string): GameState {
  const env = JSON.parse(raw) as SaveEnvelope;
  if (!env || env.version !== 1 || typeof env.payload !== 'string' || env.checksum !== checksum(env.payload)) throw new Error('存档版本或校验值无效');
  const s = JSON.parse(env.payload) as GameState;
  if (!s || !Array.isArray(s.history) || s.history.length > EVENTS.length || !Array.isArray(s.events) || !Array.isArray(s.clues)) throw new Error('存档结构无效');
  // 逐个重放业务事件，拒绝绕过条件、重复事件及伪造线索的存档。
  let rebuilt = freshState(); const engine = new GameEngine();
  for (let i = 0; i < s.history.length; i++) {
    const h: HistoryItem = s.history[i];
    if (!h || typeof h.eventId !== 'string' || typeof h.choice !== 'string') throw new Error('历史记录无效');
    const e = EVENTS.find(v => v.id === h.eventId);
    if (e === undefined) throw new Error('历史事件不存在');
    const moved = engine.move(rebuilt, e.sceneId);
    if (!moved.ok) throw new Error('场景访问顺序无效');
    const step = engine.investigate(moved.state, h.eventId, h.choice);
    if (!step.ok) throw new Error('事件顺序或选择无效');
    rebuilt = step.state;
  }
  const moved = engine.move(rebuilt, s.sceneId);
  if (!moved.ok) throw new Error('当前场景无效');
  rebuilt = moved.state;
  if (JSON.stringify(rebuilt.events) !== JSON.stringify(s.events) || JSON.stringify(rebuilt.clues) !== JSON.stringify(s.clues) ||
    rebuilt.cooperation !== s.cooperation || rebuilt.suspect !== s.suspect || rebuilt.ending !== s.ending) throw new Error('派生状态与历史不一致');
  return rebuilt;
}
