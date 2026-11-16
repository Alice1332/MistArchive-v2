import { GameState, Transition } from '../model/GameModel';
import { freshState, cloneState } from './GameEngine';
import { SaveRepository } from '../data/SaveRepository';

// 页面和测试共享同一保存流程，只有保存确认后才发布新状态。
export class InvestigationSession {
  state: GameState = freshState();
  busy: boolean = false;
  ready: boolean = false;
  message: string = '正在读取本地档案…';
  private repository: SaveRepository;
  constructor(repository: SaveRepository) { this.repository = repository; }

  async open(): Promise<void> {
    if (this.busy || this.ready) return;
    this.busy = true;
    try {
      const loaded = await this.repository.load();
      this.state = cloneState(loaded.state); this.ready = true; this.message = loaded.message;
    } catch (_) {
      this.message = '读取失败或存档损坏。可重试读取；确认重开会替换当前主档。';
    } finally { this.busy = false; }
  }

  async commit(result: Transition): Promise<boolean> {
    if (this.busy || !this.ready) return false;
    if (!result.ok) { this.message = result.message; return false; }
    this.busy = true;
    try {
      await this.repository.save(result.state);
      this.state = cloneState(result.state); this.message = result.message;
      return true;
    } catch (_) {
      this.message = '保存失败，本次操作未推进，请检查空间后重试。'; return false;
    } finally { this.busy = false; }
  }

  async restart(): Promise<boolean> {
    if (this.busy) return false;
    this.busy = true;
    try {
      const next = freshState(); await this.repository.save(next);
      this.state = next; this.ready = true; this.message = '已开启新一轮调查。'; return true;
    } catch (_) {
      this.message = '重开未能保存，请重试。'; return false;
    } finally { this.busy = false; }
  }
}
