#!/usr/bin/env node
'use strict';

// Real Chromium smoke test; all documents are local fixtures served by routing.
// PLAYWRIGHT_MODULE may name a package or an absolute module directory.
// CHROME_PATH may select an installed Edge/Chrome executable; otherwise msedge
// is used. No packages, browser downloads, screenshots, or account data are used.
// Example: node tool/test_ooi_viewport_browser_smoke.cjs --round 1 --out ../outputs/ooi-smoke/browser
// Device labels describe screen/DPR emulation, not physical Android validation.
// Native OOI/canvas fits are bridge assertions, never simulated Android scaling.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const args = process.argv.slice(2);
function option(name, fallback) {
  const at = args.indexOf(name);
  return at < 0 ? fallback : args[at + 1];
}
if (args.includes('--help')) {
  console.log('Usage: node tool/test_ooi_viewport_browser_smoke.cjs [--round 1] [--out DIRECTORY] [--quick | --access-probe | --ownership-probe | --lifecycle-probe | --lifecycle-regression-probe]\nEnvironment: PLAYWRIGHT_MODULE, CHROME_PATH. --quick runs the route and scroll probes only. --lifecycle-probe tests local login/retry, viewport ownership and runtime reuse; it never authenticates with OOI. --lifecycle-regression-probe runs active OOI hide/dialog/login-form regressions only.');
  process.exit(0);
}
const round = String(option('--round', '1'));
assert.match(round, /^[a-zA-Z0-9_-]+$/, 'Round must be safe as a filename');
const quick = args.includes('--quick');
const accessProbe = args.includes('--access-probe');
const ownershipProbe = args.includes('--ownership-probe');
const lifecycleProbe = args.includes('--lifecycle-probe');
const lifecycleRegressionProbe = args.includes('--lifecycle-regression-probe');
const repo = path.resolve(__dirname, '..');
const sourceFile = path.join(repo, 'lib/src/browser/game_page_alignment_script.dart');
const dart = fs.readFileSync(sourceFile, 'utf8');
const source = /gamePageAlignmentScript\s*=\s*r'''([\s\S]*?)''';/.exec(dart)?.[1];
assert.ok(source, 'Could not extract the actual production injection');
const expectedRuntime = Number(/const runtimeVersion\s*=\s*(\d+)/.exec(source)?.[1]);
assert.ok(expectedRuntime > 0, 'Could not read the production runtime version');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const day = new Date().toISOString().slice(0, 10).replaceAll('-', '');
const outDir = path.resolve(option('--out', path.join(repo, '..', 'outputs', `ooi-smoke-${day}`, 'browser')));
fs.mkdirSync(outDir, {recursive: true});
const stamp = new Date().toISOString().replaceAll(/[:.]/g, '-');
const outputFile = path.join(outDir, `round-${round}-${stamp}.json`);
const eventsFile = outputFile.replace(/\.json$/, '.jsonl');
let playwright;
try {
  playwright = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
} catch (error) {
  throw new Error('Playwright is required. Set PLAYWRIGHT_MODULE to an existing installation; this test does not install dependencies.', {cause: error});
}
const report = {
  round, startedAt: new Date().toISOString(), sourceSha256: hash(dart),
  mode: lifecycleRegressionProbe ? 'lifecycle-regression-probe' : lifecycleProbe ? 'lifecycle-probe' : ownershipProbe ? 'ownership-probe' : accessProbe ? 'access-probe' : quick ? 'quick' : 'full', browser: null, checks: [], failures: [],
  pageErrors: [], diagnostics: [], capabilityBoundaries: [], measurements: [],
  limits: {pages: 1, contexts: 1, rasterThreads: 2, maximumEmulatedPixels: 7000000, screenshots: 0},
  scope: 'Offline wrapper fixtures and Chromium device metrics; not live OOI, Android WebView, physical vivo, system UI, or native scale validation.',
};
function save() { fs.writeFileSync(outputFile, JSON.stringify(report, null, 2)); }
async function check(name, action) {
  const start = Date.now();
  let result;
  try {
    await action();
    result = {name, passed: true, elapsedMs: Date.now() - start};
  } catch (error) {
    result = {name, passed: false, elapsedMs: Date.now() - start, error: error.stack || String(error)};
    report.failures.push(result);
  }
  report.checks.push(result);
  fs.appendFileSync(eventsFile, JSON.stringify(result) + '\n');
  console.log(`${result.passed ? 'PASS' : 'FAIL'} ${name}${result.passed ? '' : ': ' + result.error.split('\n')[0]}`);
  if (!result.passed || report.checks.length % 10 === 0) save();
  if (page?.isClosed()) throw new Error('The sole browser page closed; aborting subsequent checks');
}

const routes = ['/kancolle', '/kancolle/', '/poi', '/poi/', '/flash', '/flash/', '/kcs2/index.php', '/kcs2/index.php/'];
const shapes = ['ooi', 'flash', 'nested', 'both'];
const profiles = [
  {name: 'desktop-dpr1', width: 1440, height: 900, dpr: 1, mobile: false},
  {name: 'desktop-dpr2', width: 1280, height: 800, dpr: 2, mobile: false},
  {name: 'phone-dpr2', width: 432, height: 960, dpr: 2, mobile: true},
  {name: 'phone-dpr2.75', width: 393, height: 873, dpr: 2.75, mobile: true},
  {name: 'phone-dpr3.5', width: 412, height: 915, dpr: 3.5, mobile: true},
  {name: 'vivo-screen-3096x2064-dpr2.75', width: 1126, height: 750, screenWidth: 1126, screenHeight: 750, physicalScreen: [3096, 2064], dpr: 2.75, mobile: true},
  {name: 'foldable-dpr2', width: 884, height: 1104, dpr: 2, mobile: true},
];
report.deviceProfiles = profiles;
const corners = [{name: 'tl', x: 12, y: 12}, {name: 'tr', x: 1188, y: 12}, {name: 'bl', x: 12, y: 708}, {name: 'br', x: 1188, y: 708}];
const childUrl = 'https://w01.kancolle-server.com/kcs2/index.php';
function childHtml(scrollable) {
  return `<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><style>
    html,body{margin:0;padding:0;${scrollable ? 'width:1800px;height:2000px;overflow:auto' : 'width:1280px;height:800px;overflow:hidden'}}
    canvas{display:block;width:1200px;height:720px;background:#34526a}
    </style><canvas width="1200" height="720"></canvas><script>
    const canvas=document.querySelector('canvas');
    document.addEventListener('click',e=>{
      const r=canvas.getBoundingClientRect(),x=e.clientX-r.x,y=e.clientY-r.y;
      const corner=x<24?(y<24?'tl':y>696?'bl':'other'):x>1176?(y<24?'tr':y>696?'br':'other'):'other';
      parent.postMessage({ooiSmoke:'click',x,y,clientX:e.clientX,clientY:e.clientY,corner,targetCanvas:e.target===canvas,trusted:e.isTrusted},'*');
    });
    parent.postMessage({ooiSmoke:'ready'},'*');
    </script>`;
}
function fixture(shape, tag = 'iframe', delayed = false, surfaceUrl = childUrl, initialScrolling = null) {
  const surface = `<${tag} id="${shape === 'htmlWrap' ? 'htmlWrap' : 'externalswf'}" width="1280" height="800" ${tag === 'embed' ? 'type="text/html"' : ''} ${initialScrolling === null ? '' : `scrolling="${initialScrolling}"`} src="${surfaceUrl}"></${tag}>`;
  const active = delayed ? '' : surface;
  const ooi = value => `<div id="ooi-page"><header id="ooi-header">Header</header><main id="ooi-content"><div id="ooi-game"><p>Help</p>${value}</div></main><footer id="ooi-footer">Footer</footer></div>`;
  const body = shape === 'canvas' ? '<canvas width="1200" height="720"></canvas>'
    : shape === 'ooi' ? ooi(active)
    : shape === 'nested' ? ooi(`<div id="flashWrap">${active}</div>`)
    : shape === 'both' ? ooi('') + `<div id="flashWrap">${active}</div>`
    : `<div id="spacing_top">Spacing</div><div id="flashWrap">${active}</div>`;
  return {surface, selector: shape === 'ooi' ? '#ooi-game' : '#flashWrap', html: `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>
    html,body{margin:0;padding:0;background:#13212c}body{min-width:1000px;min-height:2200px}
    #ooi-page{max-width:980px;margin:20px auto;padding:15px}#ooi-game,#flashWrap{width:1280px;margin:20px 30px}
    iframe,embed{display:block;max-width:100%;border:2px solid #777}canvas{display:block;width:1200px;height:720px}
    </style></head><body>${body}</body></html>`};
}
function initProbe() {
  window.__probe = {callbacks: 0, records: 0, writes: 0, observers: 0};
  window.__messages = [];
  window.__clicks = [];
  window.__childReady = 0;
  window.YahagiPresentation = {postMessage: message => window.__messages.push(message)};
  window.addEventListener('message', event => {
    if (!['https://w01.kancolle-server.com', 'https://ooi.moe'].includes(event.origin)) return;
    if (event.data?.ooiSmoke === 'click') window.__clicks.push(event.data);
    if (event.data?.ooiSmoke === 'ready') window.__childReady++;
  });
  const Original = window.MutationObserver;
  window.MutationObserver = class extends Original {
    constructor(callback) {
      window.__probe.observers++;
      super((records, observer) => {
        window.__probe.callbacks++;
        window.__probe.records += records.length;
        callback(records, observer);
      });
    }
  };
  const set = CSSStyleDeclaration.prototype.setProperty;
  CSSStyleDeclaration.prototype.setProperty = function(name, ...rest) {
    if (name.startsWith('--yahagi-ooi-')) window.__probe.writes++;
    return set.call(this, name, ...rest);
  };
}
function metrics() {
  const frame = document.querySelector('#externalswf, iframe#htmlWrap');
  const frameStyle = frame && getComputedStyle(frame);
  const rect = element => {
    if (!element) return null;
    const {x, y, width, height, right, bottom} = element.getBoundingClientRect();
    return {x, y, width, height, right, bottom};
  };
  return {
    url: location.href, state: window.__yahagiMobileReadPresentation?.(), runtime: window.__yahagiMobilePresentationRuntimeVersion,
    viewport: {width: innerWidth, height: innerHeight, visualWidth: visualViewport.width, visualHeight: visualViewport.height, dpr: devicePixelRatio, screenWidth: screen.width, screenHeight: screen.height},
    frame: rect(frame), canvas: rect(document.querySelector('canvas')),
    frameCss: frameStyle && Object.fromEntries(['position', 'left', 'top', 'width', 'height', 'transform'].map(name => [name, frameStyle[name]])),
    ancestorTransforms: frame ? Array.from((function* () { for (let ancestor = frame.parentElement; ancestor; ancestor = ancestor.parentElement) yield ancestor; })()).map(element => getComputedStyle(element).transform) : [],
    viewportMetadata: Array.from(document.querySelectorAll('meta[name]')).filter(meta => meta.getAttribute('name').toLowerCase() === 'viewport').map(meta => meta.getAttribute('content')),
    scroll: {x: scrollX, y: scrollY}, fullscreen: !!document.fullscreenElement,
    ooiStyles: document.querySelectorAll('#__yahagi_mobile_ooi_browser__').length,
    gameStyles: document.querySelectorAll('#__yahagi_mobile_fixed_canvas__').length,
    probe: {...window.__probe}, messages: [...window.__messages], childReady: window.__childReady,
  };
}
let browser, context, page, cdp, activeFixture, activeDevice, scrollableChild = false, activeChildUrl = childUrl;
let requests = 0, mainNavigations = 0, clicksSent = 0;
const counts = () => ({requests, mainNavigations});
async function settle() {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.waitForTimeout(120);
}
async function device(profile, width = profile.width, height = profile.height) {
  assert.ok(width * height * profile.dpr ** 2 <= report.limits.maximumEmulatedPixels, 'Emulated render budget exceeded');
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width, height, deviceScaleFactor: profile.dpr, mobile: profile.mobile,
    screenWidth: profile.screenWidth || Math.max(profile.width, width),
    screenHeight: profile.screenHeight || Math.max(profile.height, height),
    screenOrientation: {type: width > height ? 'landscapePrimary' : 'portraitPrimary', angle: width > height ? 90 : 0},
  });
  activeDevice = {...profile, width, height};
  assert.equal(await page.evaluate(() => devicePixelRatio), profile.dpr, 'The requested DPR must be applied by the real browser');
}
async function setup(url, shape, tag = 'iframe', profile = profiles[0], delayed = false, scrollable = false, sameOrigin = false, initialScrolling = null) {
  await device(profile);
  activeChildUrl = sameOrigin ? 'https://ooi.moe/kcs2/index.php' : childUrl;
  activeFixture = fixture(shape, tag, delayed, activeChildUrl, initialScrolling);
  scrollableChild = scrollable;
  await page.goto(url, {waitUntil: 'load'});
  await page.evaluate(source);
  await settle();
  if (shape !== 'canvas' && !delayed) await page.waitForFunction(() => window.__childReady > 0);
  return activeFixture;
}
function visibleCorners(m) {
  return corners.filter(({x, y}) => m.frame.x + x >= 0 && m.frame.y + y >= 0 && m.frame.x + x < m.viewport.visualWidth && m.frame.y + y < m.viewport.visualHeight);
}
async function clickCorners(m) {
  assert.equal(activeDevice.mobile, false, 'Trusted child clicks require the unscaled desktop fixture; mobile native input is tested on Android');
  const targets = visibleCorners(m);
  assert.ok(targets.length > 0, 'The desktop fixture must expose at least one unscaled child corner');
  const start = await page.evaluate(() => window.__clicks.length);
  for (const corner of targets) await page.mouse.click(m.frame.x + corner.x, m.frame.y + corner.y);
  clicksSent += targets.length;
  await page.waitForFunction(({start, length}) => window.__clicks.length >= start + length, {start, length: targets.length});
  return page.evaluate(start => window.__clicks.slice(start), start);
}
async function geometryAndClicks(label, click = true) {
  const m = await page.evaluate(metrics);
  report.measurements.push({label, emulatedDevice: activeDevice.name, nativeScaleValidated: false, ...m});
  assert.equal(m.state, 'game');
  assert.equal(m.runtime, expectedRuntime);
  assert.equal(m.ooiStyles, 1);
  assert.equal(m.gameStyles, 1);
  assert.ok(['game', 'game-fit'].includes(m.messages.at(-1)), 'OOI must request native game presentation, including after pending or canvas states');
  assert.deepEqual(m.frameCss, {position: 'fixed', left: '0px', top: '0px', width: '1280px', height: '800px', transform: 'none'}, 'The original OOI embedding surface must stay fixed and untransformed for native fitting');
  assert.ok(m.ancestorTransforms.every(value => value === 'none'), 'No ancestor may add a CSS transform to the embedding surface');
  assert.ok(m.viewportMetadata.length > 0);
  m.viewportMetadata.forEach(content => assert.match(content, /minimum-scale=0\.01, maximum-scale=10, user-scalable=yes/, 'OOI must own the same game viewport as a canvas'));
  for (const [actual, expected, description] of [[m.frame.x, 0, 'left'], [m.frame.y, 0, 'top'], [m.frame.width, 1280, 'frame width'], [m.frame.height, 800, 'frame height']]) {
    assert.ok(Math.abs(actual - expected) < .1, `${description}: ${actual} != ${expected}`);
  }
  if (click && !activeDevice.mobile) {
    const targets = visibleCorners(m);
    assert.ok(await page.evaluate(points => points.every(({x, y}) => ['externalswf', 'htmlWrap'].includes(document.elementFromPoint(x, y)?.id)), targets.map(corner => ({x: m.frame.x + corner.x, y: m.frame.y + corner.y}))), 'Each visible unscaled corner must hit the real embedding surface');
    const clicks = await clickCorners(m);
    const inputTolerance = 1;
    assert.equal(clicks.length, targets.length);
    clicks.forEach((value, index) => {
      assert.equal(value.corner, targets[index].name, 'Trusted unscaled click must reach the corresponding visible child canvas corner');
      assert.equal(value.targetCanvas, true);
      assert.equal(value.trusted, true);
      assert.ok(Math.abs(value.x - targets[index].x) <= inputTolerance && Math.abs(value.y - targets[index].y) <= inputTolerance, `Child click coordinate mismatch: ${JSON.stringify(value)}`);
    });
    report.measurements.at(-1).clicks = clicks;
    report.measurements.at(-1).inputToleranceGameCssPx = inputTolerance;
    assert.deepEqual(await page.evaluate(() => window.__messages), m.messages, 'Clicking an OOI wrapper must not add native fit notifications');
  } else if (activeDevice.mobile) {
    report.measurements.at(-1).inputScope = 'Bridge and untransformed CSS geometry only; Chromium device emulation does not apply Android WebView native scale or verify scaled corner taps.';
  }
  return m;
}
async function observerSettles(label, mutate = false) {
  await settle();
  const before = await page.evaluate(() => ({...window.__probe, messages: window.__messages.length}));
  if (mutate) await page.evaluate(() => { for (let i = 0; i < 100; i++) document.body.className = 'mutation-' + i; });
  await settle();
  const first = await page.evaluate(() => ({...window.__probe, messages: window.__messages.length}));
  await settle();
  const second = await page.evaluate(() => ({...window.__probe, messages: window.__messages.length}));
  report.diagnostics.push({label, before, first, second});
  assert.deepEqual(second, first, 'Mutation observer, CSS writes and bridge messages must settle');
  assert.equal(second.observers, before.observers, 'Repeated fits must reuse the observer');
  if (mutate) {
    assert.ok(first.callbacks - before.callbacks <= 2, 'Mutation burst must be bounded');
    assert.equal(first.writes, before.writes, 'Unrelated mutations must not rewrite OOI variables');
    assert.equal(first.messages, before.messages);
  }
}
async function nativeFit(label, ooi = false) {
  const before = await page.evaluate(metrics);
  assert.equal(before.state, 'game');
  assert.equal(before.ooiStyles, ooi ? 1 : 0);
  assert.equal(before.gameStyles, 1);
  const messages = before.messages.length;
  await page.evaluate(source);
  await settle();
  const after = await page.evaluate(metrics);
  assert.equal(after.messages.length, messages + 1);
  assert.equal(after.messages.at(-1), 'game-fit');
  report.measurements.push({label, nativeBridgeOnly: true, ...after});
}
async function scrollingOwnershipChecks() {
  for (const url of ['https://ooi.moe/login', 'https://evil.test/poi', 'https://play.games.dmm.com/game/other']) for (const tag of ['iframe', 'embed']) for (const original of [null, 'no', 'auto']) {
    await check(`scrolling isolation ${url} ${tag} original=${original}`, async () => {
      await setup(url, 'flash', tag, profiles[0], false, false, false, original);
      const initial = await page.locator('#externalswf').getAttribute('scrolling');
      await page.evaluate(source);
      await settle();
      const repeated = await page.locator('#externalswf').getAttribute('scrolling');
      report.diagnostics.push({label: 'scrolling-isolation', url, tag, original, initial, repeated});
      assert.equal(initial, original, 'First injection on an unrelated page must preserve its frame scrolling attribute');
      assert.equal(repeated, original, 'Repeated injection on an unrelated page must preserve its frame scrolling attribute');
      const m = await page.evaluate(metrics);
      assert.equal(m.state, 'web'); assert.equal(m.ooiStyles, 0); assert.equal(m.gameStyles, 0);
    });
  }
  for (const tag of ['iframe', 'embed']) for (const original of [null, 'no', 'auto']) {
    await check(`scrolling ownership restore ${tag} original=${original}`, async () => {
      await setup('https://ooi.moe/poi', 'flash', tag, profiles[0], false, false, false, original);
      assert.equal(await page.locator('#externalswf').getAttribute('scrolling'), 'no');
      await page.evaluate(() => { window.__removedSurface = document.querySelector('#externalswf'); window.__removedSurface.remove(); });
      await settle();
      const restored = await page.evaluate(() => window.__removedSurface.getAttribute('scrolling'));
      report.diagnostics.push({label: 'scrolling-owned-surface-removed', tag, original, restored});
      assert.equal(restored, original, 'Leaving OOI wrapper mode must restore the original attribute even on the detached owned surface');
      const m = await page.evaluate(metrics);
      assert.equal(m.state, 'web'); assert.equal(m.ooiStyles, 0); assert.equal(m.gameStyles, 0);
      assert.equal(m.messages.at(-1), 'web', 'Removing an owned game frame must release the native game fit');
      await observerSettles(`scrolling ownership ${tag}/${original}`);
    });
  }
}

async function lifecycleChecks(focused = false) {
  const original = [
    'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover',
    'WIDTH=1200; MINIMUM-SCALE=1; maximum-scale=2',
  ];
  const metadata = async () => page.evaluate(() => Array.from(document.querySelectorAll('meta[name]'))
    .filter(meta => meta.getAttribute('name').toLowerCase() === 'viewport')
    .map(meta => meta.getAttribute('content')));
  async function boot(url, shape, tag = 'iframe', metaValues = original, runtime = source, initialSurface = false, decorate = html => html) {
    await device(profiles[3]);
    activeChildUrl = childUrl;
    scrollableChild = false;
    activeFixture = fixture(shape, tag, shape !== 'canvas' && !initialSurface);
    const tags = metaValues.map(value => value === null ? '<meta name="viewport">' : `<meta name="viewport" content="${value}">`).join('');
    activeFixture.html = decorate(activeFixture.html.replace('<meta name="viewport" content="width=device-width,initial-scale=1">', tags));
    await page.goto(url, {waitUntil:'load'});
    await page.evaluate(runtime);
    await settle();
  }
  async function blockingDialog(open) {
    await page.evaluate(open => {
      if(open) {const dialog=document.createElement('dialog');dialog.id='blocker';dialog.textContent='Fixture account login';document.body.append(dialog);dialog.showModal();}
      else document.querySelector('#blocker')?.remove();
    },open);
    await settle();
  }
  const ooiVariants=[{shape:'flash',tag:'iframe'},{shape:'flash',tag:'embed'},{shape:'htmlWrap',tag:'iframe'}];
  for(const {shape,tag} of ooiVariants) await check(`lifecycle active OOI inline display ${shape}/${tag}`,async()=>{
    await boot('https://ooi.moe/poi',shape,tag,original,source,true);
    await geometryAndClicks(`active before inline hide ${shape}/${tag}`);
    const selector=shape==='htmlWrap'?'#htmlWrap':'#externalswf';
    const inlineStyle=await page.locator(selector).getAttribute('style');
    const before=counts();
    await page.locator(selector).evaluate(frame=>{frame.style.display='none';});
    await page.waitForTimeout(250);await settle();
    const hidden=await page.evaluate(metrics);
    assert.equal(hidden.state,'web','Setting display:none on an active OOI frame must release native presentation');
    assert.equal(hidden.ooiStyles,0);assert.equal(hidden.gameStyles,0);
    assert.equal(hidden.messages.at(-1),'web');
    assert.deepEqual(await metadata(),original,'Inline hiding must restore the exact original login viewport');
    assert.equal(await page.locator(selector).getAttribute('scrolling'),null);
    await page.locator(selector).evaluate((frame,inlineStyle)=>{
      if(inlineStyle===null) frame.removeAttribute('style');else frame.setAttribute('style',inlineStyle);
    },inlineStyle);await settle();
    await geometryAndClicks(`active inline display restored ${shape}/${tag}`);
    await nativeFit(`active inline display native fit ${shape}/${tag}`,true);
    await observerSettles(`active inline display ${shape}/${tag}`,true);
    assert.deepEqual(counts(),before,'Inline visibility changes must preserve the child document');
  });
  for(const {shape,tag} of [...ooiVariants,{shape:'ooi',tag:'iframe'},{shape:'ooi',tag:'embed'}]) for(const kind of ['dialog','nested-dialog','password-form','password-toggle-name','password-toggle-autocomplete']) await check(`lifecycle OOI internal ${kind} ${shape}/${tag}`,async()=>{
    await boot('https://ooi.moe/poi',shape,tag,original,source,true);
    await geometryAndClicks(`active before internal ${kind} ${shape}/${tag}`);
    const before=counts();
    await page.evaluate(({shape,kind})=>{
      const wrapper=document.querySelector(shape==='ooi'?'#ooi-game':'#flashWrap');
      if(kind==='dialog'||kind==='nested-dialog') {
        const dialog=document.createElement('dialog');dialog.id='internal-login';dialog.textContent='Local fixture account dialog';
        if(kind==='nested-dialog') {const host=document.createElement('div');host.id='internal-login-host';host.append(dialog);wrapper.append(host);} else wrapper.append(dialog);
        dialog.showModal();
      } else {
        const identity=kind==='password-toggle-name'?'name="password" autocomplete="off"':kind==='password-toggle-autocomplete'?'autocomplete="current-password"':'autocomplete="off"';
        wrapper.insertAdjacentHTML('beforeend',`<form id="internal-login"><label>Fixture password <input type="password" ${identity}></label><button type="button">Local retry</button></form>`);
      }
    },{shape,kind});await settle();
    const blocked=await page.evaluate(metrics);
    assert.equal(blocked.state,'web',`An OOI wrapper containing a visible ${kind} must release game presentation before hiding its login controls`);
    assert.equal(blocked.ooiStyles,0);assert.equal(blocked.gameStyles,0);
    assert.equal(blocked.messages.at(-1),'web');assert.deepEqual(await metadata(),original);
    assert.equal(await page.locator('#internal-login').isVisible(),true,'OOI presentation CSS must preserve its own internal login controls');
    if(kind.startsWith('password')) {
      await page.locator('#internal-login input').fill('offline-fixture-password');
      assert.equal(await page.locator('#internal-login input').inputValue(),'offline-fixture-password');
      if(kind.startsWith('password-toggle')) {
        await page.locator('#internal-login input').evaluate(input=>{input.type='text';});await settle();
        const toggled=await page.evaluate(metrics);
        assert.equal(toggled.state,'web','Showing a password as text must preserve the visible login page and release native fitting');
        assert.equal(toggled.ooiStyles,0);assert.equal(toggled.gameStyles,0);assert.equal(toggled.messages.at(-1),'web');
        assert.deepEqual(await metadata(),original);
        assert.equal(await page.locator('#internal-login input').isVisible(),true);
        assert.equal(await page.locator('#internal-login input').getAttribute('type'),'text');
      }
    }
    await page.locator('#internal-login').evaluate(element=>{const host=element.closest('#internal-login-host');if(host) host.remove();else element.remove();});await settle();
    await geometryAndClicks(`internal ${kind} closed ${shape}/${tag}`);
    await nativeFit(`internal ${kind} native fit ${shape}/${tag}`,true);
    await observerSettles(`internal ${kind} ${shape}/${tag}`,true);
    assert.deepEqual(counts(),before,'Showing and closing local login controls must not reload the game document');
  });
  if(focused) return;
  for(const route of ['/poi','/flash','/kancolle']) for(const tag of ['iframe','embed']) {
    await check(`lifecycle failed login retry delayed ${route}/${tag}`,async()=>{
      await boot('https://ooi.moe'+route,'flash',tag);
      assert.equal(await page.evaluate(()=>window.__yahagiMobileReadPresentation()),'pending');
      await page.evaluate(()=>{document.querySelector('#flashWrap').innerHTML='<form id="login" method="post"><input type="email" name="login_id"><input type="password" name="password"><label><input type="radio" name="mode" value="browser">Browser fixture</label><label><input type="radio" name="mode" value="poi">POI fixture</label><label><input type="radio" name="mode" value="direct">Direct fixture</label><p>Local login form; no credentials or real authentication</p></form>';});
      await settle();
      assert.deepEqual(await metadata(),original,'A login form must retain its viewport exactly');
      for(const mode of ['browser','poi','direct']) await page.locator(`input[name="mode"][value="${mode}"]`).check();
      assert.equal(await page.locator('input[name="mode"][value="direct"]').isChecked(),true);
      for(let failed=0;failed<2;failed++) {
        await page.evaluate(failed=>{document.querySelector('#login').insertAdjacentHTML('beforeend',`<p class="login-failure">Fixture retry ${failed}</p>`);},failed);
        await settle();
        assert.equal(await page.evaluate(()=>window.__messages.some(m=>m.startsWith('game'))),false,'A failed local login must not request native game scaling');
      }
      const before=counts();
      await page.evaluate(surface=>{setTimeout(()=>{document.querySelector('#flashWrap').innerHTML=surface;},40);},activeFixture.surface);
      await page.waitForFunction(()=>window.__childReady>0&&!!document.querySelector('#__yahagi_mobile_ooi_browser__'));
      await settle();
      await geometryAndClicks(`local login recovered ${route}/${tag}`);
      const owned = await metadata();
      assert.equal(owned.length, original.length);
      owned.forEach(content => assert.match(content,/minimum-scale=0\.01, maximum-scale=10, user-scalable=yes/,'An active OOI frame must own the native game viewport'));
      await nativeFit(`OOI explicit fit after login ${route}/${tag}`,true);
      assert.equal(counts().mainNavigations,before.mainNavigations);
      await page.locator('#externalswf').evaluate(frame=>{frame.setAttribute('width','640');frame.setAttribute('height','400');});
      await device(profiles[3],873,393);await settle();
      await geometryAndClicks(`width/resize ${route}/${tag}`);
      await observerSettles(`login ${route}/${tag}/settled`,true);
    });
  }
  for(const shape of ['canvas','flash','htmlWrap']) for(const values of [original,[],[null]]) await check(`lifecycle ${shape} metadata ${JSON.stringify(values)}`,async()=>{
    await boot('https://ooi.moe/kcs2/index.php',shape,'iframe',values,source,true);
    const owned=await metadata();
    assert.equal(owned.length,Math.max(values.length,1));
    owned.forEach(content=>assert.match(content,/minimum-scale=0\.01, maximum-scale=10, user-scalable=yes/));
    const before=counts();
    for(let cycle=0;cycle<3;cycle++) {
      await page.evaluate(source);await settle();
      await blockingDialog(true);
      assert.equal(await page.evaluate(()=>window.__yahagiMobileReadPresentation()),'web');
      assert.deepEqual(await metadata(),values,'Dialog cleanup must restore exact original attributes');
      await blockingDialog(false);
      assert.equal(await page.evaluate(()=>window.__yahagiMobileReadPresentation()),'game');
      assert.deepEqual(await metadata(),owned,'Returning to game must take a fresh identical viewport snapshot');
    }
    await observerSettles(`${shape} viewport stability`,true);
    assert.deepEqual(counts(),before,'Metadata ownership must not cause document requests');
  });
  for(const tag of ['iframe','embed']) await check(`lifecycle interleaved wrapper standalone dialog ${tag}`,async()=>{
    await boot('https://ooi.moe/poi','canvas',tag);
    const owned=await metadata();
    await page.evaluate(surface=>{
      const wrapper=document.createElement('div');wrapper.id='flashWrap';document.body.append(wrapper);
      wrapper.innerHTML=surface;wrapper.replaceChildren();
      const dialog=document.createElement('dialog');dialog.id='blocker';dialog.open=true;document.body.append(dialog);
      window.__yahagiMobileSyncPresentation();
    },fixture('flash',tag).surface);
    await settle();
    assert.equal(await page.evaluate(()=>window.__yahagiMobileReadPresentation()),'web');
    assert.deepEqual(await metadata(),original);
    await blockingDialog(false);
    assert.deepEqual(await metadata(),owned);
    await page.evaluate(surface=>{document.querySelector('canvas').remove();document.querySelector('#flashWrap').innerHTML=surface;},fixture('flash',tag).surface);
    await page.waitForFunction(()=>window.__childReady>0);await settle();
    await geometryAndClicks(`interleaved final wrapper ${tag}`);
    assert.deepEqual(await metadata(),owned,'Wrapper and standalone canvas must retain the same owned game viewport');
    assert.equal(await page.evaluate(()=>document.querySelectorAll('#__yahagi_mobile_fixed_canvas__').length),1);
    await observerSettles('interleaved request settlement '+tag,true);
  });
  for(const variant of ooiVariants) {
    const {shape,tag}=variant;
    await check(`lifecycle active OOI release and resume ${shape}/${tag}`,async()=>{
      await boot('https://ooi.moe/poi',shape,tag,original,'void 0',true);
      const originalStyles=await page.evaluate(()=>{
        window.scrollTo(0,150);
        const styles=element=>Object.fromEntries(['overflow','touchAction','minWidth','minHeight'].map(key=>[key,getComputedStyle(element)[key]]));
        return {html:styles(document.documentElement),body:styles(document.body),scroll:{x:scrollX,y:scrollY}};
      });
      assert.equal(originalStyles.scroll.y,150,'The original wrapper fixture must genuinely scroll');
      await page.evaluate(source);await settle();
      await geometryAndClicks(`active before release ${shape}/${tag}`);
      await nativeFit(`active OOI native fit ${shape}/${tag}`,true);
      const before=counts();
      const messages=await page.evaluate(()=>[...window.__messages]);
      await page.evaluate(()=>{for(let i=0;i<30;i++) window.__yahagiMobileReadPresentation();});
      await settle();
      assert.deepEqual(await page.evaluate(()=>window.__messages),messages,'Native acknowledgement reads must not send game or game-fit messages back');
      await page.evaluate(()=>{document.querySelector('#flashWrap').hidden=true;});await settle();
      assert.equal(await page.evaluate(()=>window.__yahagiMobileReadPresentation()),'web','Hiding an active game surface must release native presentation');
      assert.deepEqual(await metadata(),original);
      assert.equal(await page.evaluate(()=>window.__messages.at(-1)),'web');
      await page.evaluate(()=>{document.querySelector('#flashWrap').hidden=false;});await settle();
      await geometryAndClicks(`active unhidden ${shape}/${tag}`);
      await page.evaluate(()=>{window.__removedSurface=document.querySelector('#externalswf,iframe#htmlWrap');window.__removedSurface.remove();});await settle();
      const released=await page.evaluate(()=>{
        window.scrollTo(0,150);
        const styles=element=>Object.fromEntries(['overflow','touchAction','minWidth','minHeight'].map(key=>[key,getComputedStyle(element)[key]]));
        return {state:window.__yahagiMobileReadPresentation(),html:styles(document.documentElement),body:styles(document.body),scroll:{x:scrollX,y:scrollY},scrolling:window.__removedSurface.getAttribute('scrolling'),locks:[typeof window.__yahagiMobileScrollLock,typeof window.__yahagiMobileAlignGame,typeof window.__yahagiMobileOoiAlignGame],styleCount:document.querySelectorAll('#__yahagi_mobile_fixed_canvas__,#__yahagi_mobile_ooi_browser__').length,messages:[...window.__messages]};
      });
      await settle();
      assert.equal(released.state,'web','A previously active OOI game removed from the document must become web, not pending');
      assert.equal(released.styleCount,0);
      assert.deepEqual(released.html,originalStyles.html);assert.deepEqual(released.body,originalStyles.body);
      assert.deepEqual(released.scroll,originalStyles.scroll,'Removing the surface must restore real top-level scrollability');
      assert.deepEqual(await page.evaluate(()=>({x:scrollX,y:scrollY})),released.scroll,'A stale scroll listener must not pull the released web page back to zero');
      assert.equal(released.scrolling,null,'The detached frame must recover its original scrolling attribute');
      assert.deepEqual(released.locks,['undefined','undefined','undefined']);
      assert.deepEqual(await metadata(),original);assert.equal(released.messages.at(-1),'web');
      await page.evaluate(source);await settle();
      assert.deepEqual(await page.evaluate(()=>window.__messages),released.messages,'Repeated fits on a released web page must not request native game scaling');
      assert.deepEqual(counts(),before,'Hide, release and native state acknowledgement must not reload documents');
      const ready=await page.evaluate(()=>window.__childReady);
      await page.evaluate(surface=>document.querySelector('#flashWrap').insertAdjacentHTML('beforeend',surface),activeFixture.surface);
      await page.waitForFunction(previous=>window.__childReady>previous,ready);await settle();
      await geometryAndClicks(`active reappeared ${shape}/${tag}`);
      await observerSettles(`OOI release resume ${shape}/${tag}`,true);
    });
    for(const hidden of ['surface-hidden','surface-visibility','ancestor-hidden']) await check(`lifecycle initial hidden OOI ${shape}/${tag}/${hidden}`,async()=>{
      const selector=shape==='htmlWrap'?'#htmlWrap':'#externalswf';
      await boot('https://ooi.moe/poi',shape,tag,original,source,true,html=>{
        if(hidden==='ancestor-hidden') return html.replace('id="flashWrap"','id="flashWrap" hidden');
        return html.replace(`id="${shape==='htmlWrap'?'htmlWrap':'externalswf'}"`,`id="${shape==='htmlWrap'?'htmlWrap':'externalswf'}" ${hidden==='surface-hidden'?'hidden':'style="visibility:hidden"'}`);
      });
      const initial=await page.evaluate(metrics);
      assert.equal(initial.state,'pending','An initially hidden OOI surface must not take over the login page');
      assert.equal(initial.ooiStyles,0);assert.equal(initial.gameStyles,0);
      assert.deepEqual(await metadata(),original);
      assert.equal(initial.messages.some(message=>message.startsWith('game')),false);
      await page.evaluate(({selector,hidden})=>{
        if(hidden==='ancestor-hidden') document.querySelector('#flashWrap').hidden=false;
        else if(hidden==='surface-hidden') document.querySelector(selector).hidden=false;
        else document.querySelector(selector).style.visibility='visible';
      },{selector,hidden});await settle();
      await geometryAndClicks(`initial hidden became visible ${shape}/${tag}/${hidden}`);
      await observerSettles(`initial hidden ${shape}/${tag}/${hidden}`,true);
    });
  }
  await check(`lifecycle runtime 4 upgrade and runtime ${expectedRuntime} reinjection snapshot`,async()=>{
    const git=(...args)=>require('node:child_process').execFileSync('git',args,{cwd:repo,encoding:'utf8'});
    const revisions=git('log','-n','32','--format=%H','--','lib/src/browser/game_page_alignment_script.dart').trim().split(/\s+/);
    let oldSource;
    for(const revision of revisions) {
      const oldDart=git('show',`${revision}:lib/src/browser/game_page_alignment_script.dart`);
      const candidate=/gamePageAlignmentScript\s*=\s*r'''([\s\S]*?)''';/.exec(oldDart)?.[1];
      if(candidate?.includes('const runtimeVersion = 4;')) {oldSource=candidate;report.diagnostics.push({label:'actual prior runtime fixture',revision,runtime:4});break;}
    }
    assert.match(oldSource,/const runtimeVersion = 4;/,'The retained runtime fixture must be the actual prior revision');
    await boot('https://ooi.moe/kcs2/index.php','canvas','iframe',original,oldSource);
    assert.equal(await page.evaluate(()=>window.__yahagiMobilePresentationRuntimeVersion),4);
    await page.evaluate(source);await settle();
    assert.equal(await page.evaluate(()=>window.__yahagiMobilePresentationRuntimeVersion),expectedRuntime);
    const owned=await metadata();
    await page.evaluate(source);await page.evaluate(source);await settle();
    assert.deepEqual(await metadata(),owned);
    await blockingDialog(true);assert.deepEqual(await metadata(),original);
    await blockingDialog(false);await observerSettles('runtime upgrade settlement',true);
  });
  await check('lifecycle game account navigation failed login then restored game',async()=>{
    await boot('https://play.games.dmm.com/game/kancolle/','canvas');
    await nativeFit('pre-account game');
    await boot('https://accounts.dmm.com/login','canvas');
    assert.equal(await page.evaluate(()=>window.__yahagiMobileReadPresentation()),'web');
    assert.deepEqual(await metadata(),original);
    await page.evaluate(()=>{document.body.insertAdjacentHTML('beforeend','<p>Fixture login rejected, retry required</p>');});
    await settle();assert.equal(await page.evaluate(()=>window.__messages.some(m=>m.startsWith('game'))),false);
    await boot('https://play.games.dmm.com/game/kancolle/','canvas');
    await nativeFit('post-account retry game');await blockingDialog(true);assert.deepEqual(await metadata(),original);
  });
  await check('lifecycle wheel touch and programmatic scroll locks',async()=>{
    await boot('https://play.games.dmm.com/game/kancolle/','canvas');
    await cdp.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:1});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:150,y:200}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:240,y:450}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    await page.mouse.move(150,200);await page.mouse.wheel(160,400);
    await page.evaluate(()=>window.scrollTo(80,150));await settle();
    const locked=await page.evaluate(()=>({x:scrollX,y:scrollY,action:getComputedStyle(document.documentElement).touchAction}));
    assert.deepEqual(locked,{x:0,y:0,action:'none'});
    report.diagnostics.push({label:'trusted touch and wheel scroll lock',...locked});
  });
}

async function run() {
  browser = await playwright.chromium.launch({headless: true, ...(process.env.CHROME_PATH ? {executablePath: process.env.CHROME_PATH} : {channel: 'msedge'}), args: ['--num-raster-threads=2', '--renderer-process-limit=2', '--disable-gpu', '--disable-extensions', '--disable-background-networking', '--disable-sync', '--no-first-run']});
  report.browser = browser.version();
  context = await browser.newContext({viewport: {width: 1440, height: 900}, serviceWorkers: 'block'});
  page = await context.newPage();
  page.setDefaultTimeout(6000);
  page.setDefaultNavigationTimeout(10000);
  cdp = await context.newCDPSession(page);
  await page.addInitScript(initProbe);
  page.on('request', () => requests++);
  page.on('framenavigated', frame => { if (frame === page.mainFrame()) mainNavigations++; });
  page.on('pageerror', error => report.pageErrors.push({url: page.url(), error: error.stack || error.message}));
  page.on('crash', () => { report.failures.push({name: 'browser page crashed', passed: false}); save(); });
  await context.route('**/*', route => route.fulfill({status: 200, contentType: 'text/html', body: route.request().frame() !== page.mainFrame() ? childHtml(scrollableChild) : activeFixture.html}));

  if (lifecycleProbe || lifecycleRegressionProbe) { await lifecycleChecks(lifecycleRegressionProbe); return; }

  if (ownershipProbe) { await scrollingOwnershipChecks(); return; }

  if (accessProbe) {
    for (const tag of ['iframe', 'embed']) await check(`same-origin window access ${tag}`, async () => {
      await setup('https://ooi.moe/poi', 'flash', tag, profiles[2], false, true, true);
      const access = await page.evaluate(() => {
        const surface = document.querySelector('#externalswf');
        const children = [];
        for (let index = 0; index < window.frames.length; index++) {
          try {
            const child = window.frames[index];
            children.push({index, matchesSurface: child.frameElement === surface, frameElementId: child.frameElement?.id, origin: child.location.origin, canScroll: typeof child.scrollTo});
          } catch (error) { children.push({index, error: String(error)}); }
        }
        return {tag: surface.tagName, framesLength: window.frames.length, contentWindow: typeof surface.contentWindow, contentDocument: typeof surface.contentDocument, contentDocumentPresent: !!surface.contentDocument, children};
      });
      report.diagnostics.push({label: 'same-origin-window-access', ...access});
      console.log(JSON.stringify(access));
    });
    return;
  }

  const wrappedOoiFrame = '<div class="ooi-frame-wrap"><iframe id="externalswf" width="1280" height="720"></iframe></div>';
  await check('OOI /kancolle fits the wrapped game iframe after it loads', async () => {
    await setup('https://ooi.moe/kancolle', 'ooi', 'iframe', profiles[0], true);
    assert.equal((await page.evaluate(metrics)).state, 'pending');
    const before = counts();
    await page.locator('#ooi-game').evaluate((game, frame) => game.insertAdjacentHTML('beforeend', frame), wrappedOoiFrame);
    await settle();
    await geometryAndClicks('OOI wrapped game iframe', false);
    assert.equal(await page.locator('#ooi-game > p').isVisible(), false);
    await observerSettles('OOI wrapped game iframe', true);
    assert.equal(counts().mainNavigations, before.mainNavigations);
  });
  await check('DMM keeps its canvas fit without styling the wrapped OOI iframe', async () => {
    const url = 'https://play.games.dmm.com/game/kancolle/';
    await setup(url, 'ooi', 'iframe', profiles[0], true);
    await page.locator('#ooi-game').evaluate((game, frame) => {
      game.insertAdjacentHTML('beforeend', frame);
      document.body.insertAdjacentHTML('beforeend', '<canvas width="1200" height="720"></canvas>');
    }, wrappedOoiFrame);
    await settle();
    await nativeFit(url);
    assert.equal((await page.evaluate(metrics)).frameCss.position, 'static');
  });

  for (const route of quick ? ['/poi'] : routes) for (const shape of quick ? ['flash'] : shapes) for (const tag of ['iframe', 'embed']) {
    await check(`routes ${route} ${shape}/${tag}`, async () => {
      await setup('https://ooi.moe' + route, shape, tag);
      const before = counts();
      await geometryAndClicks(`routes ${route} ${shape}/${tag}`);
      await nativeFit(`routes explicit native fit ${route} ${shape}/${tag}`,true);
      assert.deepEqual(counts(), before, 'Fit and clicks must not reload or request documents');
    });
  }
  for(const route of quick?['/poi']:routes) await check(`routes ${route} htmlWrap/iframe`,async()=>{
    await setup('https://ooi.moe'+route,'htmlWrap');
    const before=counts();
    await geometryAndClicks(`routes ${route} htmlWrap/iframe`);
    await nativeFit(`routes explicit native fit ${route} htmlWrap/iframe`,true);
    await observerSettles(`htmlWrap ${route}`,true);
    assert.deepEqual(counts(),before);
  });

  // Scroll probes distinguish a fitting child (cannot scroll) from a deliberately
  // scrollable child. The latter is a robustness fixture, not a claim about OOI.
  for (const tag of ['iframe', 'embed']) for (const scrollable of [false, true]) {
    await check(`manual fit child scroll ${tag} scrollable=${scrollable}`, async () => {
      await setup('https://ooi.moe/poi', 'flash', tag, profiles[0], false, scrollable);
      await geometryAndClicks(`child scroll initial ${tag} ${scrollable}`);
      const before = counts();
      const child = page.frames().find(frame => frame.url() === childUrl);
      assert.ok(child, 'The real embedded child document must be accessible to the test driver');
      const scrolled = await child.evaluate(() => { window.scrollTo(80, 160); return {x: scrollX, y: scrollY, canvasTop: document.querySelector('canvas').getBoundingClientRect().y}; });
      const clicksBeforeFit = await clickCorners(await page.evaluate(metrics));
      await page.evaluate(source);
      await settle();
      const after = await child.evaluate(() => ({x: scrollX, y: scrollY, canvasTop: document.querySelector('canvas').getBoundingClientRect().y}));
      const clicksAfterFit = await clickCorners(await page.evaluate(metrics));
      report.diagnostics.push({label: 'child-scroll-manual-fit', tag, scrollable, scrolled, after, clicksBeforeFit, clicksAfterFit, modeledScrollableChild: scrollable});
      assert.deepEqual(counts(), before);
      if (scrolled.x || scrolled.y) {
        // A top-level script cannot reset arbitrary cross-origin child state.
        // Keep this explicit robustness boundary separate from OOI regressions.
        const restored = after.x === 0 && after.y === 0 && after.canvasTop === 0;
        const clicksChanged = clicksAfterFit.some((value, index) => value.corner !== corners[index].name || !value.targetCanvas);
        report.capabilityBoundaries.push({name: 'modeled-scrollable-cross-origin-child', tag, scrolled, after, restored, clicksChanged, clicksAfterFit, explanation: 'Deliberately scrollable child fixture; standard 1280x800 child fits the 1200x720 canvas and cannot scroll. Top-level fit does not have same-origin access to reset arbitrary child scroll.'});
        assert.ok(restored || clicksChanged, 'The scroll probe must prove recovery or a change to the actual visible/clickable canvas');
        if (!restored) return;
      }
      await geometryAndClicks(`child scroll after manual fit ${tag} ${scrollable}`);
    });
  }
  for (const tag of ['iframe', 'embed']) await check(`manual fit same-origin OOI proxy child scroll ${tag}`, async () => {
    await setup('https://ooi.moe/poi', 'flash', tag, profiles[0], false, true, true);
    await geometryAndClicks(`same-origin child initial ${tag}`);
    const before = counts();
    const child = page.frames().find(frame => frame !== page.mainFrame() && frame.url() === activeChildUrl);
    assert.ok(child, 'The same-origin OOI proxy child must be a real browser frame');
    const scrolled = await child.evaluate(() => { window.scrollTo(80, 160); return {x: scrollX, y: scrollY, canvasTop: document.querySelector('canvas').getBoundingClientRect().y}; });
    assert.deepEqual(scrolled, {x: 80, y: 160, canvasTop: -160}, 'The artificial scroll must really move the game canvas');
    const clicksBeforeFit = await clickCorners(await page.evaluate(metrics));
    await page.evaluate(source);
    await settle();
    const after = await child.evaluate(() => ({x: scrollX, y: scrollY, canvasTop: document.querySelector('canvas').getBoundingClientRect().y}));
    const clicksAfterFit = await clickCorners(await page.evaluate(metrics));
    report.diagnostics.push({label: 'same-origin-child-scroll-manual-fit', tag, childUrl: activeChildUrl, scrolled, after, clicksBeforeFit, clicksAfterFit});
    assert.deepEqual(counts(), before, 'Manual restoration must not reload the child');
    assert.deepEqual(after, {x: 0, y: 0, canvasTop: 0}, 'Same-origin child game visibility must recover on manual fit');
    await geometryAndClicks(`same-origin child restored ${tag}`);
  });
  for (const tag of ['iframe', 'embed']) await check(`same document wrapper/canvas/wrapper ${tag}`, async () => {
    const data = await setup('https://ooi.moe/poi/', 'flash', tag, profiles[5]);
    const before = counts();
    for (let cycle = 0; cycle < 2; cycle++) {
      await page.evaluate(() => { document.querySelector('#externalswf').remove(); const canvas = document.createElement('canvas'); canvas.width = 1200; canvas.height = 720; document.body.append(canvas); });
      await settle();
      await nativeFit(`same-document standalone ${tag}/${cycle}`);
      const ready = await page.evaluate(() => window.__childReady);
      await page.evaluate(surface => { document.querySelector('canvas').remove(); document.querySelector('#flashWrap').insertAdjacentHTML('beforeend', surface); }, data.surface);
      await page.waitForFunction(previous => window.__childReady > previous, ready);
      await settle();
      await geometryAndClicks(`same-document wrapper restored ${tag}/${cycle}`);
    }
    assert.equal(counts().mainNavigations, before.mainNavigations);
    assert.ok(counts().requests <= before.requests + 2);
    await observerSettles(`same-document ${tag}`);
  });
  if (quick) return;

  for (let index = 0; index < profiles.length; index++) for (const tag of ['iframe', 'embed']) {
    const profile = profiles[index];
    await check(`device transitions ${profile.name} ${tag}`, async () => {
      await setup('https://ooi.moe' + routes[index], shapes[index % shapes.length], tag, profile);
      const before = counts();
      const long = Math.max(profile.width, profile.height), short = Math.min(profile.width, profile.height);
      const states = [
        ['portrait', short, long], ['landscape', long, short],
        ['split', Math.max(280, Math.round(long / 2)), short],
        ['sidebar', Math.max(280, long - 280), short],
        ['full-size', long, short], ['portrait-again', short, long],
        ['split-again', Math.max(280, Math.round(long / 2)), short], ['full-size-again', long, short],
      ];
      if (profile.name.startsWith('foldable')) states.splice(2, 0, ['folded-cover', 344, 832], ['unfolded', 884, 1104]);
      for (const [state, width, height] of states) {
        await device(profile, width, height);
        await settle();
        await geometryAndClicks(`${profile.name}/${tag}/${state}`);
      }
      for (let cycle = 0; cycle < 2; cycle++) {
        const response = await cdp.send('Runtime.evaluate', {expression: 'document.documentElement.requestFullscreen()', awaitPromise: true, userGesture: true});
        assert.equal(response.exceptionDetails, undefined, 'Real DOM fullscreen request must succeed');
        await settle();
        assert.equal(await page.evaluate(() => !!document.fullscreenElement), true);
        await geometryAndClicks(`${profile.name}/${tag}/dom-fullscreen-${cycle}`);
        await page.evaluate(() => document.exitFullscreen());
        await settle();
        assert.equal(await page.evaluate(() => !!document.fullscreenElement), false);
        await geometryAndClicks(`${profile.name}/${tag}/dom-fullscreen-exit-${cycle}`);
      }
      await observerSettles(`${profile.name}/${tag}/settled`, true);
      assert.deepEqual(counts(), before, 'All resize/fold/fullscreen cycles must preserve document loads');
    });
  }

  for (const shape of shapes) for (const tag of ['iframe', 'embed']) {
    await check(`manual fit corruption ${shape}/${tag}`, async () => {
      await setup('https://ooi.moe/kancolle/', shape, tag, profiles[3]);
      const before = counts();
      for (const kind of ['frame-attributes', 'style-deletion', 'style-text', 'game-style-deletion', 'game-style-text', 'parent-scroll']) {
        const broken = await page.evaluate(({source, kind}) => {
          const frame = document.querySelector('#externalswf');
          if (kind === 'frame-attributes') {
            frame.setAttribute('width','640');frame.setAttribute('height','400');
          } else if (kind === 'style-text') document.querySelector('#__yahagi_mobile_ooi_browser__').textContent = 'iframe,embed{transform:scale(.1)!important}';
          else if (kind === 'game-style-deletion') document.querySelector('#__yahagi_mobile_fixed_canvas__').remove();
          else if (kind === 'game-style-text') document.querySelector('#__yahagi_mobile_fixed_canvas__').textContent = 'html,body{min-width:2000px!important;overflow:auto!important}';
          else {
            document.querySelector('#__yahagi_mobile_ooi_browser__').remove();
            if (kind === 'parent-scroll') {document.querySelector('#__yahagi_mobile_fixed_canvas__').remove();window.scrollTo(120, 400);}
          }
          const r = frame.getBoundingClientRect();
          const broken = {kind, x: scrollX, y: scrollY, frame: {x: r.x, y: r.y, width: r.width, height: r.height}};
          // Same task: the manual endpoint runs before observer auto-repair.
          (0, eval)(source);
          return broken;
        }, {source, kind});
        await settle();
        const restored = await geometryAndClicks(`manual ${shape}/${tag}/${kind}`);
        report.diagnostics.push({label: 'manual-corruption', shape, tag, broken, restoredScroll: restored.scroll});
        assert.deepEqual(restored.scroll, {x: 0, y: 0}, 'Manual fit must reset the top-level page scroll');
      }
      // Separately verify observer-only repair when manual fit is not invoked.
      await page.evaluate(() => {
        document.querySelector('#__yahagi_mobile_ooi_browser__').remove();
        document.querySelector('#__yahagi_mobile_fixed_canvas__').remove();
      });
      await settle();
      await geometryAndClicks(`observer corruption repair ${shape}/${tag}`);
      await observerSettles(`manual ${shape}/${tag}/settled`);
      assert.deepEqual(counts(), before);
    });
  }

  for (const shape of shapes) for (const tag of ['iframe', 'embed']) {
    await check(`delayed surface ${shape}/${tag}`, async () => {
      const data = await setup('https://ooi.moe/flash/', shape, tag, profiles[4], true);
      assert.equal(await page.evaluate(() => window.__yahagiMobileReadPresentation()), 'pending');
      const before = counts();
      await page.evaluate(({selector, surface}) => document.querySelector(selector).insertAdjacentHTML('beforeend', surface), data);
      await page.waitForFunction(() => window.__childReady > 0 && !!document.querySelector('#__yahagi_mobile_ooi_browser__'));
      await settle();
      await geometryAndClicks(`delayed ${shape}/${tag}`);
      assert.equal(counts().mainNavigations, before.mainNavigations);
      assert.ok(counts().requests <= before.requests + 1);
      await observerSettles(`delayed ${shape}/${tag}`);
    });
  }

  for (const route of routes) await check(`standalone native bridge ${route}`, async () => {
    await setup('https://ooi.moe' + route, 'canvas', 'iframe', profiles[2]);
    const before = counts();
    await nativeFit(route);
    await page.evaluate(() => { const dialog = document.createElement('dialog'); dialog.id = 'blocker'; document.body.append(dialog); dialog.showModal(); });
    await settle();
    assert.equal(await page.evaluate(() => window.__yahagiMobileReadPresentation()), 'web');
    await page.evaluate(() => document.querySelector('#blocker').remove());
    await settle();
    await nativeFit(route + '/dialog-closed');
    await observerSettles(`standalone ${route}`, true);
    assert.deepEqual(counts(), before);
  });

  const exclusions = [
    'https://ooi.moe/', 'https://ooi.moe/login', 'https://ooi.moe/connector', 'https://ooi.moe/poi-help', 'https://ooi.moe/poison', 'https://ooi.moe/kancolle-help', 'https://ooi.moe/kcs2/index.php-malicious',
    'https://ooi.moe.evil.test/poi', 'https://sub.ooi.moe/flash', 'https://evil.test/kancolle',
    'https://accounts.dmm.com/login', 'https://accounts.dmm.co.jp/login', 'https://play.games.dmm.com/game/other', 'https://www.dmm.com/login',
  ];
  for (const url of exclusions) for (const shape of ['flash', 'canvas']) await check(`isolation ${url} ${shape}`, async () => {
    await setup(url, shape);
    const m = await page.evaluate(metrics);
    report.measurements.push({label: 'isolation', shape, ...m});
    assert.equal(m.state, 'web'); assert.equal(m.ooiStyles, 0); assert.equal(m.gameStyles, 0);
    assert.deepEqual(m.messages, ['web']);
    const before = counts(); await page.evaluate(source); await settle();
    assert.deepEqual(counts(), before);
    assert.deepEqual(await page.evaluate(() => window.__messages), ['web']);
  });
  for (const url of ['https://play.games.dmm.com/game/kancolle/', 'https://www.dmm.com/netgame/social/-/gadgets/=/app_id=854854/', 'https://osapi.dmm.com/gadgets/ifr', 'https://w02.kancolle-server.com/kcs2/index.php']) await check(`DMM/server native isolation ${url}`, async () => {
    // The main fixture is selected by hostname; use a distinct server host.
    await setup(url, 'canvas');
    await nativeFit(url);
    await observerSettles(`native isolation ${url}`);
  });
  for (const route of ['/POI/?x=1#fragment', '/kancolle?x=1']) await check(`OOI query/case ${route}`, async () => {
    await setup('https://ooi.moe' + route, 'flash');
    await geometryAndClicks(`query/case ${route}`);
  });
  await scrollingOwnershipChecks();
  await lifecycleChecks();
}

(async () => {
  try {
    await run();
    assert.equal(hash(fs.readFileSync(sourceFile, 'utf8')), report.sourceSha256, 'Production source changed while the smoke test was running');
  } catch (error) {
    report.failures.push({name: 'fatal', passed: false, error: error.stack || String(error)});
    console.error(error.stack || error);
  } finally {
    if (context) await context.close().catch(error => report.diagnostics.push({cleanup: String(error)}));
    if (browser) await browser.close().catch(error => report.diagnostics.push({cleanup: String(error)}));
    report.finishedAt = new Date().toISOString();
    report.summary = {checks: report.checks.length, failures: report.failures.length, pageErrors: report.pageErrors.length, capabilityBoundaries: report.capabilityBoundaries.length, measurements: report.measurements.length, clicksSent};
    save();
    console.log(JSON.stringify({outputFile, ...report.summary}));
    if (report.failures.length || report.pageErrors.length) process.exitCode = 1;
  }
})();
