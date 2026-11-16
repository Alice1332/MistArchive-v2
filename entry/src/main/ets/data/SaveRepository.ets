import { GameState, TextStore, LoadResult } from '../model/GameModel';
import { encode, decode } from '../domain/SaveCodec';
import { freshState } from '../domain/GameEngine';
export const CURRENT = 'case_current_v1';
export const BACKUP = 'case_backup_v1';
export class SaveRepository {
  private store: TextStore;
  constructor(store: TextStore) { this.store = store; }
  async load(): Promise<LoadResult> {
    const current = await this.store.read(CURRENT);
    if (current !== '') {
      try { return { state: decode(current), message: '已恢复最近一次保存的调查。', source: 'current' }; } catch (_) {}
    }
    const backup = await this.store.read(BACKUP);
    if (backup !== '') {
      try { return { state: decode(backup), message: '主存档无效，已从上一份有效存档恢复。', source: 'backup' }; } catch (_) {}
    }
    if (current !== '' || backup !== '') throw new Error('存档损坏。原始数据未被覆盖；请确认后重开调查。');
    return { state: freshState(), message: '欢迎调查A-017档案失踪案。', source: 'new' };
  }
  async save(s: GameState): Promise<void> {
    const next = encode(s); decode(next);
    const old = await this.store.read(CURRENT);
    // 原主档有效才滚动备份，避免用损坏内容覆盖可用备份。
    if (old !== '') {
      let valid = false; try { decode(old); valid = true; } catch (_) {}
      if (valid) await this.store.write(BACKUP, old);
    }
    await this.store.write(CURRENT, next);
    try { await this.store.flush(); }
    catch (_) {
      // flush失败时将内存缓存回滚，界面不会展示未确认落盘的新状态。
      await this.store.write(CURRENT, old);
      throw new Error('保存失败，未推进调查，请重试。');
    }
  }
}
