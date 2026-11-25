// Optional local acceptance test. Game code and user archives are read at runtime,
// never copied into this fixture. This verifies model/anchor consumption, not GPU rendering.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');

const required = ['YAHAGI_GAME_DECODED_JS', 'YAHAGI_GAME_START2_JSON',
  'YAHAGI_REAL_MOD_ZIP', 'YAHAGI_REAL_VOICE_MOD_ZIP'];
const missing = required.filter(key => !process.env[key]);
if (missing.length) {
  console.log(`SKIP real game consumer: missing ${missing.join(', ')}`);
  process.exit(0);
}
const gameSource = fs.readFileSync(process.env.YAHAGI_GAME_DECODED_JS, 'utf8');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sourceHash = sha(fs.readFileSync(process.env.YAHAGI_GAME_DECODED_JS));
const inputPaths = [process.env.YAHAGI_REAL_MOD_ZIP, process.env.YAHAGI_REAL_VOICE_MOD_ZIP];
const inputHashes = inputPaths.map(path => sha(fs.readFileSync(path)));
const {readGameModScript} = require('../game_mod_script_source.cjs');
const hook = readGameModScript(process.argv[2]);
const capture = fs.readFileSync(process.argv[3], 'utf8');

// Only ZIP data is decoded. No archive scripts, executables, or bundled JS run.
const inventory = spawnSync(process.env.YAHAGI_TEST_PYTHON || 'python', ['-c', String.raw`
import hashlib,json,struct,sys,zipfile,zlib
result=[]
for path in sys.argv[1:]:
 package={'path':path,'pngs':[],'configs':[]}
 with zipfile.ZipFile(path) as archive:
  for entry in archive.infolist():
   if entry.is_dir(): continue
   if entry.filename.endswith('.config.json'):
    package['configs'].append({'path':entry.filename,'data':json.loads(archive.read(entry))})
   if not entry.filename.lower().endswith('.png'): continue
   data=archive.read(entry)
   assert data[:8]==b'\x89PNG\r\n\x1a\n',entry.filename
   width,height=struct.unpack('>II',data[16:24]);pos=8;payload=[];ended=False
   while pos+12<=len(data):
    size=struct.unpack('>I',data[pos:pos+4])[0];kind=data[pos+4:pos+8]
    chunk=data[pos+8:pos+8+size];crc=struct.unpack('>I',data[pos+8+size:pos+12+size])[0]
    assert zlib.crc32(kind+chunk)&0xffffffff==crc,entry.filename
    pos+=size+12
    if kind==b'IDAT':payload.append(chunk)
    if kind==b'IEND':ended=True;break
   assert ended,entry.filename
   inflater=zlib.decompressobj();pixels=inflater.decompress(b''.join(payload));pixels+=inflater.flush()
   assert inflater.eof and not inflater.unused_data,entry.filename
   assert data[24]==8 and data[25] in (2,6) and data[26:29]==bytes(3),entry.filename
   channels=3 if data[25]==2 else 4
   assert len(pixels)==height*(1+width*channels),entry.filename
   package['pngs'].append({'path':entry.filename,'width':width,'height':height,
     'sha256':hashlib.sha256(data).hexdigest(),'trailingBytes':len(data)-pos})
 result.append(package)
print(json.dumps(result,ensure_ascii=True))
`, ...inputPaths], {encoding: 'utf8', maxBuffer: 4 * 1024 * 1024});
assert.equal(inventory.status, 0, inventory.stderr || inventory.error?.message);
const packages = JSON.parse(inventory.stdout);
const coordinatePackage = packages[0];
assert.equal(coordinatePackage.configs.length, 1);
assert.equal(coordinatePackage.pngs.length, 2);
assert.equal(packages[1].pngs.length, 29);
const graphPatch = coordinatePackage.configs[0].data.api_mst_shipgraph;
assert.deepEqual(graphPatch.api_boko_n, [180, 180]);
assert.deepEqual(graphPatch.api_boko_d, [20, 240]);
const baseline = JSON.parse(fs.readFileSync(process.env.YAHAGI_GAME_START2_JSON, 'utf8').replace(/^svdata=/, ''));
const masterData = baseline.api_data || baseline;
const originalGraph = masterData.api_mst_shipgraph.find(ship => ship.api_id === 607);
assert.equal(originalGraph.api_filename, 'tciiyagxjjpu');
const raw = 'svdata=' + JSON.stringify({api_result: 1, api_result_msg: 'OK', api_data: masterData});
const config = {sessionId: 17, token: 'real-consumer-test', ships: {'607': {
  graph: graphPatch, resourceIds: ['real-i47:coordinates'],
}}};

// The decoded webpack snapshot has module delimiters that cannot occur inside
// the selected modules' strings. A changed snapshot fails extraction explicitly.
function extractModule(id) {
  const startPattern = new RegExp('\\},0x' + id.toString(16) + '\\(([^)]*)\\)\\{');
  const match = startPattern.exec(gameSource);
  assert.ok(match, `missing game module ${id.toString(16)}`);
  const start = match.index + 2;
  const rest = gameSource.slice(match.index + match[0].length);
  const next = /\},0x[0-9a-f]+\([^)]*\)\{/.exec(rest);
  assert.ok(next, `unterminated game module ${id.toString(16)}`);
  const end = match.index + match[0].length + next.index + 1;
  const text = gameSource.slice(start, end);
  return {id: id.toString(16), start, end,
    executable: text.replace(/^0x[0-9a-f]+\(/, 'function(')};
}
const moduleIds = [0xb462, 0x148c5, 0x88f9, 0x15bef, 0x10fb6, 0x957d, 0xc500];
const extracted = new Map(moduleIds.map(id => [id, extractModule(id)]));

function environment() {
  const reports = [], messages = [], network = [], callbacks = [];
  class Xhr {
    constructor() { this.readyState = 0; this.responseType = ''; this.status = 0; this.events = {}; }
    open(method, url, async = true) { Object.assign(this, {method, url, async, readyState: 1}); }
    addEventListener(type, listener) { (this.events[type] ||= []).push(listener); }
    send(body) {
      const url = new URL(this.url, 'https://w01y.kancolle-server.com/kcs2/');
      if (url.pathname === '/__yahagi_mods__/coordinates.json') {
        this._text = JSON.stringify(config); this.status = 200; this.readyState = 4; return;
      }
      if (url.pathname === '/__yahagi_mods__/coordinates-report') {
        reports.push(JSON.parse(url.searchParams.get('payload')));
        this._text = '{}'; this.status = 200; this.readyState = 4; return;
      }
      network.push({method: this.method, url: this.url, body});
      this._text = raw; this._json = JSON.parse(raw.slice(7));
      this.responseURL = url.href; this.status = 200; this.readyState = 4;
      this.onreadystatechange?.();
      for (const listener of this.events.loadend || []) listener.call(this);
    }
    get responseText() { return this._text || ''; }
    get response() { return this.responseType === 'json' ? this._json : this._text || ''; }
  }
  class Point { constructor(x = 0, y = 0) { Object.assign(this, {x, y}); } set(x, y) { Object.assign(this, {x, y}); } }
  class Rectangle { constructor(x, y, width, height) { Object.assign(this, {x, y, width, height}); } }
  class Sprite { constructor(texture) { this.texture = texture; } }
  const app = {model: {}, settings: {api_token: 'test-only', api_root: 'https://w01y.kancolle-server.com/kcsapi',
    renderer: {extract: {pixels: () => new Uint8Array(0)}}},
    view: {loading: {hide() {}, show() {}}, showError: message => {throw new Error(message);}},
    resources: {getShip: (id, damaged) => {
      const item = packages.flatMap(package => package.pngs).find(png => {
        const match = png.path.match(/\/ship\/(full|full_dmg)\/(\d+)_/);
        return match && Number(match[2]) === id && (match[1] === 'full_dmg') === damaged;
      });
      assert.ok(item, `missing actual PNG for ${id}/${damaged}`);
      return item;
    }}};
  const context = vm.createContext({URL, URLSearchParams, Response, Headers, Request, TextEncoder,
    XMLHttpRequest: Xhr, performance: {timeOrigin: 1}, setTimeout, clearTimeout,
    location: {href: 'https://w01y.kancolle-server.com/kcs2/index.php', protocol: 'https:', hostname: 'w01y.kancolle-server.com', port: ''},
    _0x455a: () => {throw new Error('game snapshot is not fully decoded');},
    PIXI: {Point, Rectangle, Sprite, Texture: {EMPTY: null}},
    fetch: async (url, init) => {network.push({url, init}); return new Response(raw);},
    YahagiNativeCapture: {postMessage: value => messages.push(JSON.parse(value))},
  });
  context.window = context;
  const loaded = new Map([
    [0xdd98, {__esModule: true, default: app}],
    [0xd84d, {stringify: () => {throw new Error('real network disabled');}}],
    [0xf516, {post: () => {throw new Error('real network disabled');}}],
    [0xd85e, {}], [0x15cce, {WheelEventUtil: {isEnabled: false}}],
  ]);
  function requireGame(id) {
    if (loaded.has(id)) return loaded.get(id);
    const module = extracted.get(id);
    assert.ok(module, `unexpected game dependency ${id.toString(16)}`);
    const exports = {}, record = {exports}; loaded.set(id, exports);
    const factory = vm.runInContext('(' + module.executable + ')', context, {timeout: 1000});
    factory(record, exports, requireGame); loaded.set(id, record.exports);
    return record.exports;
  }
  const {ShipGraphModelHolder} = requireGame(0x15bef);
  app.model.ship_graph = new ShipGraphModelHolder();
  app.model.basic = {getFlagShipPosIDCli: () => 0};
  // Non-graph model sinks are isolated; the graph holder and startup consumer are real.
  for (const name of ['const', 'shipType', 'ship', 'ship_upgrade', 'slot', 'useItem',
    'expedition', 'map', 'mst_bgm', 'payitem', 'equip', 'furniture']) {
    app.model[name] = new Proxy({}, {get: (_, property) => (...args) => callbacks.push({name, property, args})});
  }
  const GetDataAPI = requireGame(0xc500).GetDataAPI;
  function consume(value) {
    const api = new GetDataAPI(); api._success({data: value});
    assert.equal(api._api_result, 1);
    return app.model.ship_graph.get(607);
  }
  return {context, app, reports, messages, network, consume, requireGame};
}

// Runtime extraction of the real port initialize method; only dependencies that
// supply textures, points, and fixed port settings are replaced.
const portReference = gameSource.indexOf('["getPortOffset"]', gameSource.indexOf('["getPortOffset"]') + 1);
const prefix = gameSource.slice(0, portReference);
const methodPattern = /\["prototype"\]\["initialize"\]=function\(/g;
const methodMatches = [...prefix.matchAll(methodPattern)];
assert.ok(methodMatches.length);
const methodStart = methodMatches.at(-1).index + '["prototype"]["initialize"]='.length;
const methodEnd = gameSource.indexOf('},Object["defineProperty"]', portReference) + 1;
assert.ok(methodEnd > methodStart);
const portMethodSource = gameSource.slice(methodStart, methodEnd);

function portAnchor(e, id, damaged) {
  const appName = portMethodSource.match(/(_0x[0-9a-f]+)\["default"\]\["model"\]\["basic"\]/)[1];
  const constName = portMethodSource.match(/(_0x[0-9a-f]+)\["PortConst"\]/)[1];
  const utilName = portMethodSource.match(/(_0x[0-9a-f]+)\["ObjUtil"\]/)[1];
  const lookupName = portMethodSource.match(/\{var _0x[0-9a-f]+=(_0x[0-9a-f]+)/)[1];
  e.context[appName] = {default: e.app};
  e.context[constName] = {PortConst: {getMoveXValue: () => 0}};
  e.context[utilName] = e.requireGame(0xb462);
  e.context[lookupName] = e.context._0x455a;
  const initialize = vm.runInContext('(' + portMethodSource + ')', e.context, {timeout: 1000});
  const chara = {position: {set(x, y) {this.x = x; this.y = y;}},
    get width() {return this.texture.width;}, get height() {return this.texture.height;}};
  const view = {_chara: chara, _animation: {reset() {}},
    position: {set(x, y) {this.x = x; this.y = y;}},
    positionSet(x, y) {this.anchor = {x, y};}};
  initialize.call(view, id, damaged, 'full', null);
  return {shipId: id, damaged, width: chara.width, height: chara.height,
    child: {x: chara.position.x, y: chara.position.y}, anchor: view.anchor};
}

async function run() {
  let scenarios = 0;
  const anchors = [];
  for (let round = 1; round <= 3; round++) {
    for (const order of ['captureFirst', 'captureLast']) {
      const unread = environment();
      const captureSource = capture.replaceAll('__YAHAGI_BINARY_CAPTURE_ENABLED__', 'false')
        .replaceAll('__YAHAGI_CAPTURE_SESSION_ID__', 'consumer-test');
      if (order === 'captureFirst') vm.runInContext(captureSource, unread.context);
      vm.runInContext(hook, unread.context);
      if (order === 'captureLast') vm.runInContext(captureSource, unread.context);
      const unreadXhr = new unread.context.XMLHttpRequest();
      unreadXhr.open('POST', '/kcsapi/api_start2/getData'); unreadXhr.send('api_token=unchanged');
      assert.equal(unread.messages[0].responseBody, raw);
      assert.equal(unread.reports.length, 0, 'capture alone must not acknowledge game consumption');
      const e = environment();
      const installCapture = () => vm.runInContext(captureSource, e.context);
      if (order === 'captureFirst') installCapture();
      vm.runInContext(hook, e.context);
      if (order === 'captureLast') installCapture();
      const xhr = new e.context.XMLHttpRequest(); xhr.open('POST', '/kcsapi/api_start2/getData');
      let consumed;
      xhr.onreadystatechange = () => {if (xhr.readyState === 4) consumed = e.consume(xhr.responseText);};
      xhr.send('api_token=unchanged&api_verno=1');
      assert.deepEqual([consumed.getPortOffset().x, consumed.getPortOffset().y], [180, 180]);
      assert.deepEqual([consumed.getPortOffset(true).x, consumed.getPortOffset(true).y], [20, 240]);
      assert.deepEqual([consumed.getCenterOffset().x, consumed.getCenterOffset().y], [160, 80]);
      for (const [method, field] of [['getPortOffset', 'boko'], ['getCenterOffset', 'kaizo'],
        ['getLeftOffset', 'ensyuf'], ['getMapOffset', 'map'],
        ['getRemodelPowupUIOffset', 'kaisyu'], ['getBattleOffset', 'battle']]) {
        for (const damaged of [false, true]) {
          const point = consumed[method](damaged);
          assert.deepEqual([point.x, point.y], graphPatch[`api_${field}_${damaged ? 'd' : 'n'}`]);
        }
      }
      for (const [field, value] of Object.entries(graphPatch)) {
        assert.deepEqual(JSON.parse(JSON.stringify(consumed._o[field])), value);
      }
      assert.deepEqual([consumed.getFaceRect().x, consumed.getFaceRect().y], [0, 0]);
      assert.deepEqual([consumed.getFaceRect().width, consumed.getFaceRect().height], originalGraph.api_wedb);
      assert.equal(consumed.unique_key, originalGraph.api_filename);
      assert.deepEqual(JSON.parse(e.messages[0].responseBody.slice(7)).api_data, masterData);
      assert.equal(e.network[0].body, 'api_token=unchanged&api_verno=1');
      assert.equal(e.network.length, 1);
      assert.equal(e.reports.filter(report => !report.failure).length, 1);
      for (const ship of masterData.api_mst_shipgraph) {
        if (ship.api_id !== 607) assert.deepEqual(JSON.parse(JSON.stringify(e.app.model.ship_graph.get(ship.api_id)._o)), ship);
      }
      const normal = portAnchor(e, 607, false), damaged = portAnchor(e, 607, true);
      assert.deepEqual([normal.width, normal.height, normal.child.x, normal.child.y], [582, 984, -111, -312]);
      assert.deepEqual([damaged.width, damaged.height, damaged.child.x, damaged.child.y], [672, 604, -316, -62]);
      if (round === 1 && order === 'captureFirst') anchors.push(normal, damaged);
      for (const png of packages[1].pngs) {
        const match = png.path.match(/\/ship\/(full|full_dmg)\/(\d+)_/);
        if (!match) continue;
        const anchor = portAnchor(e, Number(match[2]), match[1] === 'full_dmg');
        assert.ok([anchor.child.x, anchor.child.y, anchor.anchor.x, anchor.anchor.y].every(Number.isFinite));
        if (round === 1 && order === 'captureFirst') anchors.push(anchor);
      }
      // Disable by starting another document with no hook: raw data restores the model.
      const clean = environment(); const restored = clean.consume(raw);
      assert.deepEqual([restored.getPortOffset().x, restored.getPortOffset().y], originalGraph.api_boko_n);
      const response = await e.context.fetch('/kcsapi/api_start2/getData', {method: 'POST'});
      e.consume(await response.text());
      assert.equal(e.app.model.ship_graph.get(607).getPortOffset().x, 180);
      scenarios++;
    }
  }
  assert.deepEqual(inputPaths.map(path => sha(fs.readFileSync(path))), inputHashes);
  const report = {verification: 'real game model and port-anchor execution; not complete game or GPU rendering',
    sourceSha256: sourceHash, scenarios, rounds: 3,
    modules: [...extracted.values()].map(({id, start, end}) => ({id, start, end})),
    portMethod: {start: methodStart, end: methodEnd},
    packages: packages.map((package, index) => ({path: package.path, sha256: inputHashes[index],
      pngCount: package.pngs.length, trailingPngCount: package.pngs.filter(png => png.trailingBytes).length})),
    anchors};
  if (process.env.YAHAGI_GAME_CONSUMER_REPORT) fs.writeFileSync(process.env.YAHAGI_GAME_CONSUMER_REPORT,
    JSON.stringify(report, null, 2) + '\n');
  console.log(`real game consumer: ${scenarios} scenarios passed (3 rounds; 31 actual PNGs; raw coordinates; unchanged capture/requests)`);
  console.log(JSON.stringify(report));
}
run().catch(error => {console.error(error); process.exitCode = 1;});
