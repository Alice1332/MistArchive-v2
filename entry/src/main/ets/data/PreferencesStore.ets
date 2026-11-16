import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { TextStore } from '../model/GameModel';
export class PreferencesStore implements TextStore {
  private prefs: preferences.Preferences;
  constructor(context: common.UIAbilityContext) {
    this.prefs = preferences.getPreferencesSync(context, { name: 'mist_archive' });
  }
  async read(key: string): Promise<string> { return await this.prefs.get(key, '') as string; }
  async write(key: string, value: string): Promise<void> { await this.prefs.put(key, value); }
  async flush(): Promise<void> { await this.prefs.flush(); }
}
