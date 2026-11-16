// Native black-box smoke test. Requires the running course emulator and a fresh
// MistArchive investigation. This run restarts only the test game's progress.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { setTimeout as pause } from 'node:timers/promises';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const hdc = process.env.MIST_HDC || 'F:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const device = process.env.MIST_DEVICE || '127.0.0.1:5555';
const bundle = process.env.MIST_BUNDLE || 'com.example.mistarchive.v2';
const evidence = path.join(root, 'evidence');
const shots = path.join(evidence, 'screenshots');
const layoutPath = path.join(evidence, 'native-layout.json');
fs.mkdirSync(shots, { recursive: true });
const records = [];
const steps = [];
const resumeAccuse = process.argv.includes('--resume-accuse');
const previous = resumeAccuse ? JSON.parse(fs.readFileSync(path.join(evidence, 'native-ui-results.json'), 'utf8')) : null;
if (previous) { records.push(...previous.records.filter(r => r.pass)); steps.push(...previous.steps); }
const session = previous?.startedAt || new Date().toISOString();
function command(...args) {
  return execFileSync(hdc, ['-t', device, ...args], { encoding: 'utf8', timeout: 45000, windowsHide: true });
}
function bounds(value) {
  const n = String(value || '').match(/-?\d+/g)?.map(Number);
  return n?.length === 4 ? n : [0, 0, 0, 0];
}
function layout() {
  command('shell', 'uitest', 'dumpLayout', '-p', '/data/local/tmp/mistarchive-ui.json');
  command('file', 'recv', '/data/local/tmp/mistarchive-ui.json', layoutPath);
  const tree = JSON.parse(fs.readFileSync(layoutPath, 'utf8'));
  const appRoots = [];
  function select(node) {
    if (node.attributes?.bundleName === bundle) { appRoots.push(node); return; }
    for (const child of node.children || []) select(child);
  }
  select(tree);
  if (!appRoots.length) throw new Error('MistArchive is not in the foreground; UI test stopped.');
  const nodes = [];
  function walk(node, scroll = null) {
    const a = node.attributes || {};
    const currentScroll = a.type === 'Scroll' ? bounds(a.bounds) : scroll;
    nodes.push({ a, scroll: currentScroll });
    for (const child of node.children || []) walk(child, currentScroll);
  }
  appRoots.forEach(n => walk(n));
  return nodes;
}
function visible(node) {
  const b = bounds(node.a.bounds);
  return node.a.visible === 'true' && b[2] > b[0] && b[3] > b[1];
}
async function swipe(direction) {
  // Both endpoints stay inside the observed app's central scroll viewport.
  const s = layout().find(n => n.a.type === 'Scroll' && n.a.scrollable === 'true');
  if (!s) throw new Error('Expected scroll container is absent');
  const b = bounds(s.a.bounds), x = Math.round((b[0] + b[2]) / 2);
  const y1 = Math.round(b[1] + (b[3] - b[1]) * (direction === 'up' ? .83 : .17));
  const y2 = Math.round(b[1] + (b[3] - b[1]) * (direction === 'up' ? .17 : .83));
  command('shell', 'uitest', 'uiInput', 'swipe', String(x), String(y1), String(x), String(y2), '2400');
  await pause(180);
}
async function tap(text, seek = 'up') {
  for (let attempt = 0; attempt < 9; attempt++) {
    const nodes = layout();
    const candidate = nodes.find(n => n.a.text === text && n.a.enabled === 'true' && visible(n));
    if (candidate) {
      const b = bounds(candidate.a.bounds);
      command('shell', 'uitest', 'uiInput', 'click', String(Math.round((b[0] + b[2]) / 2)), String(Math.round((b[1] + b[3]) / 2)));
      await pause(300);
      steps.push({ operation: text, at: new Date().toISOString() });
      console.log('UI ' + text);
      return;
    }
    await swipe(seek);
  }
  throw new Error('Enabled visible control not found: ' + text);
}
async function expectText(text) {
  // Labels can be above or below the viewport; inspect both scroll directions.
  for (const direction of ['down', 'up']) {
    for (let attempt = 0; attempt < 7; attempt++) {
      if (layout().some(n => n.a.text === text && visible(n))) return;
      await swipe(direction);
    }
  }
  throw new Error('Expected UI text not found: ' + text);
}
async function screenshot(name) {
  command('shell', 'uitest', 'screenCap', '-p', '/data/local/tmp/mistarchive-screen.png');
  command('file', 'recv', '/data/local/tmp/mistarchive-screen.png', path.join(shots, name + '.png'));
}
function pass(id, name, detail) {
  records.push({ id, name, pass: true, detail, at: new Date().toISOString() });
  console.log('PASS ' + id + ' ' + name);
}
async function start() {
  const result = command('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', bundle);
  if (!result.includes('successfully')) throw new Error(result);
  await pause(500);
}
async function move(scene) { await tap(scene + '  可前往', 'down'); }
async function initialInvestigation(cooperation) {
  await tap('场景');
  for (let i = 0; i < 4; i++) await tap('开展调查');
  await move('旧图书馆');
  await tap('开展调查');
  await tap(cooperation === 'cooperate' ? '合作询问' : '直接指责');
  await tap('开展调查');
  await move('器材储藏室');
  await tap('开展调查');
}
async function restart() {
  await tap('存档');
  await tap('重开调查');
  await tap('确认重开');
}
try {
  await start();
  if (!resumeAccuse) {
  await tap('进度');
  await expectText('已完成 0 / 12 个事件');
  await tap('场景');
  await expectText('校园门卫室');
  await screenshot('01-native-start');
  pass('N01', '原生应用启动与初始状态', '显示门卫室，事件0，线索0');
  const locked = layout().find(n => n.a.text === '旧图书馆  未解锁');
  if (!locked || locked.a.enabled !== 'false') throw new Error('Locked scene is not disabled');
  pass('N02', '锁定场景边界', '旧图书馆按钮在初始状态不可执行');
  if (layout().some(n => String(n.a.text || '').includes('你接下委托：'))) throw new Error('未调查就泄露了事件结果');
  pass('N08', '第二版调查结果展示边界', '初始事件卡未展示调查结果');

  await initialInvestigation('cooperate');
  await tap('进度');
  await expectText('已完成 8 / 12 个事件');
  await expectText('询问方式：合作询问');
  await screenshot('05-before-restart');
  const pidBefore = command('shell', 'pidof', bundle).trim();
  const stopped = command('shell', 'aa', 'force-stop', bundle);
  if (!stopped.toLowerCase().includes('success')) throw new Error(stopped);
  const pidStopped = command('shell', 'pidof', bundle).trim();
  if (pidStopped) throw new Error('App process still exists after force-stop: ' + pidStopped);
  await start();
  const pidAfter = command('shell', 'pidof', bundle).trim();
  await expectText('器材储藏室');
  await expectText('5/6 线索');
  await expectText('已恢复最近一次保存的调查。');
  await tap('进度');
  await expectText('已完成 8 / 12 个事件');
  await expectText('询问方式：合作询问');
  await screenshot('06-after-restart');
  pass('N03', '实际Preferences进程终止恢复', { pidBefore, pidStopped, pidAfter, events: 8, clues: 5, scene: 'storage' });

  await tap('场景');
  await tap('开展调查');
  await move('旧图书馆');
  await tap('开展调查');
  await move('校园门卫室');
  await tap('判断为管理员转存漏登');
  await tap('封存调查并查看结局');
  await tap('进度');
  await expectText('已完成 12 / 12 个事件');
  await expectText('6/6 线索');
  await expectText('完整核验：已完成');
  await screenshot('03-truth');
  const truthText = '结局一 真相归档：完整回执、轮迹与封条证明档案因转存漏登而失踪。你协助补全记录，排除了对实习生的误解。';
  if (!layout().some(n => n.a.text === truthText)) {
    await swipe('up');
    if (!layout().some(n => n.a.text === truthText)) throw new Error('Truth ending text missing');
  }
  pass('N04', '合作路线原生真相结局', '事件12，线索6，完整核验，真相归档');
  await tap('线索');
  await tap('转存回执');
  await screenshot('02-clues');

  await tap('存档');
  await tap('重开调查');
  await tap('取消');
  await tap('进度');
  await expectText('已完成 12 / 12 个事件');
  pass('N05', '取消重开不丢进度', '取消对话框后保留12事件与结束状态');

  await restart();
  await initialInvestigation('accuse');
  await tap('开展调查');
  } else {
    await tap('进度');
    await expectText('已完成 9 / 12 个事件');
    await expectText('询问方式：直接指责');
    await tap('场景');
  }
  await move('旧图书馆');
  await expectText('完整验证需要六条线索；当前缺少关键回执，可继续提交现有判断或重开。');
  pass('N06', '选择分支真实改变核验条件', '指责后只有5条线索，不能执行完整验证');
  await move('校园门卫室');
  await tap('判断为管理员转存漏登');
  await tap('封存调查并查看结局');
  await tap('进度');
  await expectText('已完成 11 / 12 个事件');
  await expectText('5/6 线索');
  await expectText('询问方式：直接指责');
  await expectText('结局二 未竟疑云：缺少完整核验或最终判断有误，调查结论未获认可。档案暂存，疑点仍待复核。');
  await screenshot('04-rush');
  pass('N07', '指责路线原生未竟结局', '事件11，线索5，未竟疑云');
  await restart();
  await screenshot('00-ready-for-user');
} catch (error) {
  records.push({ id: 'FAILED_STEP', pass: false, error: String(error), at: new Date().toISOString() });
  console.error(String(error));
  try { await screenshot('native-failure'); } catch (_) {}
  process.exitCode = 1;
} finally {
  fs.writeFileSync(path.join(evidence, 'native-ui-results.json'), JSON.stringify({ startedAt: session, completedAt: new Date().toISOString(), resumedAfterHarnessFix: resumeAccuse, device, bundle, scope: 'Real HarmonyOS emulator UI via hdc uitest; real Preferences adapter; no mocked game implementation', records, steps }, null, 2));
}
