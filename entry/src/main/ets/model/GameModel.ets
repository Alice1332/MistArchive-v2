export interface SceneDef { id: string; name: string; subtitle: string; description: string; }
export interface ClueDef { id: string; name: string; detail: string; source: string; }
export interface EventDef {
  id: string; sceneId: string; title: string; text: string; requires: string[]; clueId: string;
}
export interface HistoryItem { eventId: string; choice: string; }
export interface GameState {
  sceneId: string; events: string[]; clues: string[]; history: HistoryItem[];
  cooperation: string; suspect: string; ending: string;
}
export interface Transition { ok: boolean; message: string; state: GameState; }
export interface LoadResult { state: GameState; message: string; source: string; }
export interface SaveEnvelope { version: number; payload: string; checksum: number; savedAt: number; }
export interface TextStore {
  read(key: string): Promise<string>;
  write(key: string, value: string): Promise<void>;
  flush(): Promise<void>;
}
