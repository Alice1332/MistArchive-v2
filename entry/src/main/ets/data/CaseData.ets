import { SceneDef, ClueDef, EventDef } from '../model/GameModel';
export const SCENES: SceneDef[] = [
  { id: 'gate', name: '校园门卫室', subtitle: '调查起点', description: '旧馆封存前夜，一份校史档案失踪。值班老师请你还原档案最后的流转路线。所有人物与情节均为虚构。' },
  { id: 'library', name: '旧图书馆', subtitle: '目录与证词', description: '借阅台保留着登记目录。实习生愿意协助，但你的询问方式将影响他是否交出关键记录。' },
  { id: 'storage', name: '器材储藏室', subtitle: '物证核验', description: '临时转存的木箱排列在墙边。核对封条、搬运痕迹与登记时间，才能判断档案去了哪里。' }
];
export const CLUES: ClueDef[] = [
  { id: 'c01', name: '旧馆闭馆通知', source: '门卫室公告栏', detail: '旧图书馆于18:00闭馆；当晚19:00开展档案防潮转存。失踪时间不能仅以闭馆时间推断。' },
  { id: 'c02', name: '访客登记', source: '门卫值班员', detail: '实习生17:40离校，管理员18:50携推车进入旧馆。登记同时记录了人员与时间。' },
  { id: 'c03', name: '档案目录卡', source: '图书馆目录柜', detail: '目标档案编号A-017，封面右下角有修补痕迹；借阅状态为空，不能据此认定有人借走。' },
  { id: 'c04', name: '转存回执', source: '实习生保留的副本', detail: '管理员签名的回执写明：19:05将A-017移至器材储藏室。取得这份材料需要先建立合作关系。' },
  { id: 'c05', name: '推车痕迹', source: '储藏室门口', detail: '连续轮迹从旧馆通向储藏室，未延伸至校门。它支持校内转存的判断。' },
  { id: 'c06', name: '木箱封条', source: '储藏室木箱', detail: '封条标注A-017，封口完整，透过观察口可见相同修补痕迹。档案未被盗走，只是转存后漏登。' }
];
export const EVENTS: EventDef[] = [
  { id: 'e01', sceneId: 'gate', title: '接受调查委托', text: '你接下委托：找回A-017档案，并在提交判断前核实人员、时间与物证。', requires: [], clueId: '' },
  { id: 'e02', sceneId: 'gate', title: '查看闭馆通知', text: '你注意到闭馆与转存是两项不同安排。', requires: ['e01'], clueId: 'c01' },
  { id: 'e03', sceneId: 'gate', title: '询问门卫值班员', text: '值班员提供访客登记，实习生的离校时间早于转存。', requires: ['e02'], clueId: 'c02' },
  { id: 'e04', sceneId: 'gate', title: '领取旧馆通行许可', text: '完成初步询问，旧图书馆已解锁。', requires: ['e03'], clueId: '' },
  { id: 'e05', sceneId: 'library', title: '查阅档案目录', text: '你记下档案编号与外观，后续可以据此核验实物。', requires: ['e04'], clueId: 'c03' },
  { id: 'e06', sceneId: 'library', title: '选择询问实习生的方式', text: '合作询问可获得完整回执；直接指责会让对方拒绝提供副本。本轮选择不可撤销，可重开调查体验另一分支。', requires: ['e05'], clueId: '' },
  { id: 'e07', sceneId: 'library', title: '核对转存记录', text: '核对完成，器材储藏室已解锁。', requires: ['e06'], clueId: 'c04' },
  { id: 'e08', sceneId: 'storage', title: '检查推车轮迹', text: '搬运路线通向校内储藏室，未通向校门。', requires: ['e07'], clueId: 'c05' },
  { id: 'e09', sceneId: 'storage', title: '核验木箱封条', text: '编号和修补痕迹都与目录相符，最终判断已开放。', requires: ['e08'], clueId: 'c06' },
  { id: 'e10', sceneId: 'library', title: '交叉验证完整证据链', text: '六条证据相互印证：档案由管理员转存，转存后遗漏登记。', requires: ['e09'], clueId: '' },
  { id: 'e11', sceneId: 'gate', title: '填写最终判断', text: '选择你认为最合理的解释，再封存调查。判断会影响结局。', requires: ['e09'], clueId: '' },
  { id: 'e12', sceneId: 'gate', title: '提交判断并封存调查', text: '调查结束。你可以查阅线索，也可以重开体验另一条路线。', requires: ['e11'], clueId: '' }
];
