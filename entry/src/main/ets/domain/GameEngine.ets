import { GameState, HistoryItem, Transition, EventDef } from '../model/GameModel';
import { SCENES, CLUES, EVENTS } from '../data/CaseData';
export function freshState(): GameState {
  return { sceneId: 'gate', events: [], clues: [], history: [], cooperation: '', suspect: '', ending: '' };
}
export function cloneState(s: GameState): GameState {
  const history: HistoryItem[] = s.history.map((h: HistoryItem): HistoryItem => { return { eventId: h.eventId, choice: h.choice }; });
  return { sceneId: s.sceneId, events: s.events.slice(), clues: s.clues.slice(), history: history,
    cooperation: s.cooperation, suspect: s.suspect, ending: s.ending };
}
export class GameEngine {
  canEnter(s: GameState, scene: string): boolean {
    return scene === 'gate' || (scene === 'library' && s.events.includes('e04')) ||
      (scene === 'storage' && s.events.includes('e07'));
  }
  move(s: GameState, scene: string): Transition {
    if (!SCENES.some(v => v.id === scene) || !this.canEnter(s, scene)) return this.fail(s, '场景未解锁，请先完成前置调查。');
    const next = cloneState(s); next.sceneId = scene;
    return { ok: true, message: '已切换场景。', state: next };
  }
  reason(s: GameState, e: EventDef): string {
    if (s.ending !== '') return '调查已结束，请重开后再调查。';
    if (s.events.includes(e.id)) return '已完成，不重复获得线索。';
    if (s.sceneId !== e.sceneId) return '请前往对应场景。';
    if (!e.requires.every(id => s.events.includes(id))) return '前置事件未完成。';
    if (e.id === 'e10' && s.clues.length !== CLUES.length) return '完整验证需要六条线索；当前缺少关键回执，可继续提交现有判断或重开。';
    return '';
  }
  eventDescription(s: GameState, e: EventDef): string {
    if (s.events.includes(e.id)) return e.text;
    const blocked = this.reason(s, e);
    if (blocked !== '') return blocked;
    if (e.id === 'e06') return '选择询问方式，确认后将记录在本轮调查中。';
    if (e.id === 'e11') return '根据已收集并核验的证据填写最终判断。';
    return '开展本项调查后查看结果。';
  }
  investigate(s: GameState, eventId: string, choice: string = ''): Transition {
    const e = EVENTS.find(v => v.id === eventId);
    if (e === undefined) return this.fail(s, '不存在的事件。');
    const blocked = this.reason(s, e);
    if (blocked !== '') return this.fail(s, blocked);
    if (e.id === 'e06' && choice !== 'cooperate' && choice !== 'accuse') return this.fail(s, '请选择合作询问或直接指责。');
    if (e.id === 'e11' && choice !== 'transfer' && choice !== 'theft') return this.fail(s, '请选择转存漏登或实习生盗取。');
    if (e.id !== 'e06' && e.id !== 'e11' && choice !== '') return this.fail(s, '此事件不接受选项参数。');
    const next = cloneState(s);
    next.events.push(e.id); next.history.push({ eventId: e.id, choice: choice });
    let message = e.text;
    if (e.id === 'e06') next.cooperation = choice;
    if (e.id === 'e11') next.suspect = choice;
    if (e.clueId !== '' && (e.id !== 'e07' || next.cooperation === 'cooperate')) next.clues.push(e.clueId);
    if (e.id === 'e07' && next.cooperation === 'accuse') message = '实习生拒绝交出副本，你只得到储藏室位置。缺少回执将无法完成完整证据验证。';
    if (e.id === 'e12') {
      next.ending = next.events.includes('e10') && next.suspect === 'transfer' && next.cooperation === 'cooperate' ? 'truth' : 'rush';
      message = this.endingText(next);
    }
    return { ok: true, message: message, state: next };
  }
  endingText(s: GameState): string {
    if (s.ending === 'truth') return '结局一 真相归档：完整回执、轮迹与封条证明档案因转存漏登而失踪。你协助补全记录，排除了对实习生的误解。';
    if (s.ending === 'rush') return '结局二 未竟疑云：缺少完整核验或最终判断有误，调查结论未获认可。档案暂存，疑点仍待复核。';
    return '调查尚未结束。';
  }
  stage(s: GameState): string {
    if (s.ending !== '') return '调查结束';
    if (s.events.includes('e09')) return '最终判断';
    if (s.events.includes('e04')) return '收集与验证';
    return '接受与初查';
  }
  private fail(s: GameState, message: string): Transition { return { ok: false, message: message, state: cloneState(s) }; }
}
