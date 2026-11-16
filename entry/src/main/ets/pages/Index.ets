import { common } from '@kit.AbilityKit';
import { GameState, EventDef, SceneDef, ClueDef, Transition } from '../model/GameModel';
import { GameEngine, freshState, cloneState } from '../domain/GameEngine';
import { SaveRepository } from '../data/SaveRepository';
import { InvestigationSession } from '../domain/InvestigationSession';
import { PreferencesStore } from '../data/PreferencesStore';
import { SCENES, EVENTS, CLUES } from '../data/CaseData';

@Entry
@Component
struct Index {
  @State game: GameState = freshState();
  @State tab: number = 0;
  @State busy: boolean = true;
  @State ready: boolean = false;
  @State message: string = '正在读取本地档案…';
  @State selectedClue: string = '';
  @State pulse: number = 1;
  private engine: GameEngine = new GameEngine();
  private session: InvestigationSession | undefined = undefined;

  aboutToAppear(): void { this.openArchive(); }
  getSession(): InvestigationSession {
    if (this.session === undefined) {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) throw new Error('无法取得应用上下文');
      this.session = new InvestigationSession(new SaveRepository(new PreferencesStore(context as common.UIAbilityContext)));
    }
    return this.session;
  }
  syncSession(): void {
    if (this.session === undefined) return;
    this.game = cloneState(this.session.state); this.ready = this.session.ready;
    this.busy = this.session.busy; this.message = this.session.message;
  }
  async openArchive(): Promise<void> {
    if (this.ready) return;
    this.busy = true;
    try { await this.getSession().open(); this.syncSession(); }
    catch (_) { this.message = '无法初始化本地存储，请重试。'; this.busy = false; }
  }
  async commit(result: Transition): Promise<void> {
    if (this.busy || !this.ready) return;
    const pending = this.getSession().commit(result); this.syncSession();
    const saved = await pending; this.syncSession();
    if (saved) this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.pulse = this.pulse === 1 ? 0.985 : 1; });
  }
  async restart(): Promise<void> {
    if (this.busy) return;
    try {
      const pending = this.getSession().restart(); this.syncSession();
      const saved = await pending; this.syncSession();
      if (saved) { this.tab = 0; this.selectedClue = ''; }
    } catch (_) { this.message = '重开未能保存，请重试。'; this.busy = false; }
  }
  confirmRestart(): void {
    this.getUIContext().showAlertDialog({ title: '重开调查', message: '将替换本轮进度，上一份有效存档保留为备份。是否继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认重开', action: () => { this.restart(); } } });
  }
  currentScene(): SceneDef { return SCENES.find(v => v.id === this.game.sceneId) || SCENES[0]; }

  @Builder
  eventCard(e: EventDef) {
    Column({ space: 8 }) {
      Row() {
        Text(e.id.toUpperCase()).fontSize(11).fontColor('#8A693A').width(38)
        Text(e.title).fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1)
        Text(this.game.events.includes(e.id) ? '已完成' : '待调查').fontSize(12).fontColor('#72776D')
      }.width('100%')
      Text(this.engine.eventDescription(this.game, e)).fontSize(14).lineHeight(22).fontColor('#60665F').width('100%')
      if (!this.game.events.includes(e.id)) {
        if (e.id === 'e06') {
          Button('合作询问').onClick(() => { this.commit(this.engine.investigate(this.game, e.id, 'cooperate')); })
            .enabled(this.ready && !this.busy && this.engine.reason(this.game, e) === '').width('100%').backgroundColor('#284C43')
          Button('直接指责').onClick(() => { this.commit(this.engine.investigate(this.game, e.id, 'accuse')); })
            .enabled(this.ready && !this.busy && this.engine.reason(this.game, e) === '').width('100%').backgroundColor('#886546')
        } else if (e.id === 'e11') {
          Button('判断为管理员转存漏登').onClick(() => { this.commit(this.engine.investigate(this.game, e.id, 'transfer')); })
            .enabled(this.ready && !this.busy && this.engine.reason(this.game, e) === '').width('100%').backgroundColor('#284C43')
          Button('判断为实习生盗取').onClick(() => { this.commit(this.engine.investigate(this.game, e.id, 'theft')); })
            .enabled(this.ready && !this.busy && this.engine.reason(this.game, e) === '').width('100%').backgroundColor('#886546')
        } else {
          Button(e.id === 'e12' ? '封存调查并查看结局' : '开展调查').width('100%').backgroundColor('#284C43')
            .enabled(this.ready && !this.busy && this.engine.reason(this.game, e) === '')
            .onClick(() => { this.commit(this.engine.investigate(this.game, e.id)); })
        }
        if (this.engine.reason(this.game, e) !== '') {
          Text(this.engine.reason(this.game, e)).fontSize(12).fontColor('#925B3D').width('100%')
        }
      }
    }.padding(16).backgroundColor('#FFFFFF').borderRadius(12).width('100%')
  }

  @Builder
  scenePage() {
    Column({ space: 14 }) {
      ForEach(SCENES, (s: SceneDef) => {
        Button(`${s.name}  ${this.engine.canEnter(this.game, s.id) ? '可前往' : '未解锁'}`)
          .width('100%').backgroundColor(this.game.sceneId === s.id ? '#284C43' : '#E1E7DF')
          .fontColor(this.game.sceneId === s.id ? '#FFFFFF' : '#33483E')
          .enabled(this.ready && !this.busy && this.engine.canEnter(this.game, s.id))
          .onClick(() => { this.commit(this.engine.move(this.game, s.id)); })
      }, (s: SceneDef) => s.id)
      Text(this.currentScene().name).fontSize(25).fontWeight(FontWeight.Bold).width('100%')
      Text(this.currentScene().description).fontSize(15).lineHeight(24).fontColor('#5D655F').width('100%')
      if (this.game.ending !== '') {
        Text(this.engine.endingText(this.game)).fontSize(19).lineHeight(30).fontColor('#284C43').padding(12)
      }
      ForEach(EVENTS.filter(e => e.sceneId === this.game.sceneId), (e: EventDef) => { this.eventCard(e) }, (e: EventDef) => e.id)
    }.width('100%')
  }

  @Builder
  cluePage() {
    Column({ space: 12 }) {
      Text('线索板').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
      Text(`已收集 ${this.game.clues.length} / 6 条  ·  点击已获得线索查看详情`).fontSize(14).fontColor('#616C63').width('100%')
      ForEach(CLUES, (c: ClueDef) => {
        Column({ space: 8 }) {
          Text(this.game.clues.includes(c.id) ? c.name : '待发现的线索').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
          Text(this.game.clues.includes(c.id) ? `来源：${c.source}` : '继续探索，解锁证据').fontSize(13).fontColor('#7B8076').width('100%')
          if (this.selectedClue === c.id && this.game.clues.includes(c.id)) {
            Text(c.detail).fontSize(15).lineHeight(24).width('100%')
          }
        }.padding(18).width('100%').backgroundColor('#FFFFFF').borderRadius(12)
          .onClick(() => { if (this.game.clues.includes(c.id)) this.selectedClue = this.selectedClue === c.id ? '' : c.id; })
      }, (c: ClueDef) => c.id)
    }.width('100%')
  }

  @Builder
  progressPage() {
    Column({ space: 14 }) {
      Text('调查进度').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
      Text(this.engine.stage(this.game)).fontSize(20).fontColor('#284C43').width('100%')
      Progress({ value: this.game.events.length, total: 12, type: ProgressType.Linear }).width('100%').color('#547561')
      Text(`已完成 ${this.game.events.length} / 12 个事件`).fontSize(15).width('100%')
      Text(`询问方式：${this.game.cooperation === '' ? '未选择' : this.game.cooperation === 'cooperate' ? '合作询问' : '直接指责'}`).fontSize(15).width('100%')
      Text(`完整核验：${this.game.events.includes('e10') ? '已完成' : '未完成'}`).fontSize(15).width('100%')
      Text(`最终判断：${this.game.suspect === '' ? '未选择' : this.game.suspect === 'transfer' ? '转存漏登' : '实习生盗取'}`).fontSize(15).width('100%')
      ForEach(EVENTS, (e: EventDef) => {
        Text(`${this.game.events.includes(e.id) ? '✓' : '○'} ${e.id}  ${e.title}`).fontSize(14).width('100%').padding(7)
      }, (e: EventDef) => e.id)
      if (this.game.ending !== '') { Text(this.engine.endingText(this.game)).fontSize(17).lineHeight(27).width('100%') }
    }.width('100%')
  }

  @Builder
  archivePage() {
    Column({ space: 16 }) {
      Text('调查存档').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
      Text('每次有效调查、选择和场景切换均在保存成功后更新界面。结束应用进程后重新打开，将自动读取主存档；主档校验失败时尝试上一份有效备份。').fontSize(15).lineHeight(25).width('100%')
      Button('保存当前进度').width('100%').backgroundColor('#284C43').enabled(this.ready && !this.busy)
        .onClick(() => { this.commit({ ok: true, message: '当前进度已保存。', state: cloneState(this.game) }); })
      Button('重试读取存档').width('100%').backgroundColor('#547561').enabled(!this.ready && !this.busy).onClick(() => { this.openArchive(); })
      Button('重开调查').width('100%').backgroundColor('#886546').enabled(!this.busy).onClick(() => { this.confirmRestart(); })
      Text('重开会替换本轮主档。当前版本提供一个主档与一个滚动备份，不提供多周目结局收集。').fontSize(13).lineHeight(22).fontColor('#73786D').width('100%')
    }.width('100%')
  }

  build() {
    Column() {
      Column({ space: 5 }) {
        Text('迷雾档案').fontSize(30).fontWeight(FontWeight.Bold).fontColor('#253D34').width('100%')
        Text('A-017  /  旧图书馆失踪档案').fontSize(13).fontColor('#7A715C').width('100%')
      }.width('100%').padding({ left: 22, right: 22, top: 24, bottom: 16 })
      Row({ space: 8 }) {
        Text(this.busy ? '正在处理…' : this.engine.stage(this.game)).fontSize(12).fontColor('#FFFFFF')
        Blank()
        Text(`${this.game.clues.length}/6 线索`).fontSize(12).fontColor('#FFFFFF')
      }.width('100%').padding(12).backgroundColor('#284C43')
      Text(this.message).fontSize(13).lineHeight(20).fontColor('#6D5137').padding({ left: 18, right: 18, top: 10, bottom: 10 }).width('100%')
      Scroll() {
        Column() {
          if (this.tab === 0) { this.scenePage() }
          else if (this.tab === 1) { this.cluePage() }
          else if (this.tab === 2) { this.progressPage() }
          else { this.archivePage() }
        }.width('100%').padding(18).scale({ x: this.pulse, y: this.pulse })
      }.layoutWeight(1).width('100%').align(Alignment.Top)
      Row() {
        ForEach(['场景', '线索', '进度', '存档'], (label: string, index: number) => {
          Button(label).layoutWeight(1).height(48).fontSize(15).borderRadius(0)
            .backgroundColor(this.tab === index ? '#284C43' : '#FFFFFF').fontColor(this.tab === index ? '#FFFFFF' : '#536557')
            .onClick(() => { this.tab = index; })
        }, (label: string) => label)
      }.width('100%').padding({ bottom: 10 }).backgroundColor('#FFFFFF')
    }.width('100%').height('100%').backgroundColor('#F2F1E9')
  }
}
