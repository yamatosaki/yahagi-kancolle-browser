const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const kotlin = fs.readFileSync(process.argv[2], 'utf8');
const source = kotlin.match(/val source: String\s*=\s*"""([\s\S]*?)"""/)[1];
const capture = fs.readFileSync(process.argv[3], 'utf8');
const config = {sessionId: 7, token: 'test-session', ships: {'607': {
  graph: {api_boko_n: [180, 180], api_boko_d: [20, 240], api_weda: [0, 0]},
  resourceIds: ['package:coordinates'],
}}};
const raw = 'svdata={"api_result":1,"api_data":{"api_mst_ship":[{"api_id":607,"api_name":"伊47"}],"api_mst_shipgraph":[{"api_id":607,"api_boko_n":[1,2],"api_boko_d":[3,4],"api_weda":[9,9],"api_sortno":88},{"api_id":1,"api_boko_n":[9,10]}],"other":[1,2,3]}}';
function env(options = {}) {
  const reports = [], network = [], messages = [], configRequests = [], coordinateRequests = [];
  class ImageElement {
    set src(value) { this.requested = value; }
    get src() { return this.requested; }
  }
  class Xhr {
    constructor() { this.readyState = 0; this.responseType = ''; this.status = 0; this.events = {}; }
    open(method, url, async = true) { this.method = method; this.url = url; this.async = async; this.readyState = 1; }
    addEventListener(type, listener) { (this.events[type] ||= []).push(listener); }
    send(body) {
      const path = new URL(this.url, 'https://w01y.kancolle-server.com/kcs2/').pathname;
      if (path === '/__yahagi_mods__/coordinates.json') {
        configRequests.push({method: this.method, async: this.async});
        this._text = JSON.stringify(options.config || config); this.status = 200; this.readyState = 4; return;
      }
      if (path === '/__yahagi_mods__/coordinates-report') {
        reports.push(JSON.parse(new URL(this.url, 'https://w01y.kancolle-server.com/').searchParams.get('payload')));
        this._text = '{}'; this.status = 200; this.readyState = 4; return;
      }
      const coordinateRoute = path.match(/^\/__yahagi_mods__\/kanxy-coordinates\/([a-z0-9]{12})\.json$/);
      if (coordinateRoute) {
        const stem = coordinateRoute[1];
        coordinateRequests.push({stem, method: this.method, async: this.async});
        const fields = options.kanxyCoordinates?.[stem];
        this._text = fields ? JSON.stringify(fields) : '';
        this.status = fields ? 200 : 404;
        this.readyState = 4;
        return;
      }
      network.push({method: this.method, url: this.url, body});
      this._text = options.raw === undefined ? raw : options.raw;
      this._json = (() => { try { return JSON.parse(this._text.replace(/^svdata=/, '')); } catch (_) { return null; } })();
      this.responseURL = new URL(this.url, 'https://w01y.kancolle-server.com/').href;
      this.status = options.status || 200; this.readyState = 4;
      this.onreadystatechange?.();
      for (const listener of this.events.readystatechange || []) listener.call(this);
      this.onload?.();
      for (const listener of this.events.loadend || []) listener.call(this);
    }
    get responseText() { if (!['', 'text'].includes(this.responseType)) throw new Error('InvalidStateError'); return this._text || ''; }
    get response() { return this.responseType === 'json' ? this._json : this.responseText; }
  }
  const context = vm.createContext({URL, URLSearchParams, Response, Headers, Request, TextEncoder, XMLHttpRequest: Xhr, HTMLImageElement: ImageElement,
    location: options.location || {href: 'https://w01y.kancolle-server.com/kcs2/index.php', protocol: 'https:', hostname: 'w01y.kancolle-server.com', port: ''},
    performance: {timeOrigin: 1}, setTimeout,
    fetch: async (url, init) => { network.push({url, init}); return new Response(options.raw === undefined ? raw : options.raw, {status: options.status || 200}); },
    YahagiNativeCapture: {postMessage: value => messages.push(JSON.parse(value))},
  });
  context.window = context;
  const injectMod = () => vm.runInContext(source, context);
  const injectCapture = () => vm.runInContext(capture.replaceAll('__YAHAGI_BINARY_CAPTURE_ENABLED__', 'false').replaceAll('__YAHAGI_CAPTURE_SESSION_ID__', 'capture-test'), context);
  if (options.captureFirst) injectCapture();
  injectMod();
  if (options.captureLast) injectCapture();
  return {context, reports, network, messages, configRequests, coordinateRequests, injectMod};
}
function request(e, type = '', path = '/kcsapi/api_start2/getData') {
  const xhr = new e.context.XMLHttpRequest(); xhr.open('POST', path); xhr.responseType = type;
  let observed;
  xhr.onreadystatechange = () => { observed = type === 'json' ? xhr.response : xhr.responseText; };
  xhr.send('api_token=unchanged&api_verno=1');
  return {xhr, observed};
}
function parse(value) { return JSON.parse(typeof value === 'string' ? value.replace(/^svdata=/, '') : JSON.stringify(value)); }
function checkPatched(value) {
  const data = parse(value).api_data;
  assert.deepEqual(data.api_mst_shipgraph[0].api_boko_n, [180, 180]);
  assert.deepEqual(data.api_mst_shipgraph[0].api_boko_d, [20, 240]);
  assert.deepEqual(data.api_mst_shipgraph[0].api_weda, [0, 0]);
  assert.equal(data.api_mst_shipgraph[0].api_sortno, 88);
  assert.equal(data.api_mst_ship[0].api_name, '伊47');
  assert.deepEqual(data.api_mst_shipgraph[1].api_boko_n, [9, 10]);
  assert.deepEqual(data.other, [1, 2, 3]);
}

const start2 = '/kcsapi/api_start2/getData';
const fusouStem = 'ibcavjzuajrb';
const yubariStem = 'tuzbqjvyptyt';
const missingStem = 'aaaaaaaaaaaa';
const kanxyStartup = JSON.stringify({
  api_result: 1,
  api_data: {api_mst_shipgraph: [
    {api_id: 748, api_filename: fusouStem, api_boko_n: [-30, 120], api_boko_d: [108, 198]},
    {api_id: 623, api_filename: yubariStem, api_boko_n: [5, 10]},
    {api_id: 1, api_filename: missingStem, api_boko_n: [9, 10], api_boko_d: [11, 12]},
    {api_id: 2, api_filename: '../outside', api_boko_n: [13, 14]},
  ]},
});
const kanxyCoordinates = {
  [fusouStem]: {api_boko_n: [320, 202], api_boko_d: [300, 205]},
  [yubariStem]: {api_boko_n: [90, 80]},
};

function kanxyEnv(options = {}) {
  return env({
    raw: 'svdata=' + kanxyStartup,
    config: {sessionId: 8, token: 'kanxy-session', ships: {}, kanxy: true, localArtShips: []},
    kanxyCoordinates,
    ...options,
  });
}

function parseStartupInGame(e, text) {
  e.context.startupText = text;
  return vm.runInContext("JSON.parse(startupText.replace(/^svdata=/, ''))", e.context).api_data.api_mst_shipgraph;
}

async function checkKanxyFallback() {
  for (const order of ['captureFirst', 'captureLast']) {
    const e = kanxyEnv({[order]: true});
    const {observed} = request(e, 'text');
    const [fusou, yubari, missing, invalid] = parseStartupInGame(e, observed);
    assert.equal(fusou.api_id, 748);
    assert.equal(fusou.api_filename, fusouStem);
    assert.equal(JSON.stringify(fusou), JSON.stringify(JSON.parse(kanxyStartup).api_data.api_mst_shipgraph[0]));
    assert.deepEqual(e.coordinateRequests, []);
    assert.deepEqual(Array.from(fusou.api_boko_n), [320, 202]);
    assert.deepEqual(Array.from(fusou.api_boko_d), [300, 205]);
    const sameShip = parseStartupInGame(e, request(e).observed)[0];
    assert.deepEqual(Array.from(sameShip.api_boko_n), [320, 202]);
    assert.deepEqual(e.coordinateRequests, [{stem: fusouStem, method: 'GET', async: false}]);
    assert.deepEqual(Array.from(yubari.api_boko_n), [90, 80]);
    assert.deepEqual(Array.from(missing.api_boko_n), [9, 10]);
    assert.deepEqual(Array.from(missing.api_boko_d), [11, 12]);
    assert.deepEqual(Array.from(invalid.api_boko_n), [13, 14]);
    assert.deepEqual(e.coordinateRequests.map(request => request.stem), [fusouStem, yubariStem, missingStem]);
    assert.ok(e.messages.length > 0);
    assert.ok(e.messages.every(message => message.responseBody === 'svdata=' + kanxyStartup));
    assert.deepEqual(e.reports, []);
  }

  const json = kanxyEnv({captureLast: true});
  const jsonShip = request(json, 'json').observed.api_data.api_mst_shipgraph[0];
  assert.deepEqual(json.coordinateRequests, []);
  assert.deepEqual(Array.from(jsonShip.api_boko_n), [320, 202]);
  assert.deepEqual(json.coordinateRequests.map(request => request.stem), [fusouStem]);
  assert.deepEqual(JSON.parse(json.messages[0].responseBody), JSON.parse(kanxyStartup));

  const fetchText = kanxyEnv({captureFirst: true});
  const textResponse = await fetchText.context.fetch(start2, {method: 'POST'});
  const [textShip] = parseStartupInGame(fetchText, await textResponse.text());
  assert.deepEqual(fetchText.coordinateRequests, []);
  assert.deepEqual(Array.from(textShip.api_boko_n), [320, 202]);
  assert.deepEqual(fetchText.coordinateRequests.map(request => request.stem), [fusouStem]);
  await new Promise(setImmediate);
  assert.equal(fetchText.messages.at(-1).responseBody, 'svdata=' + kanxyStartup);

  const fetchJson = kanxyEnv({raw: kanxyStartup});
  const jsonResponse = await fetchJson.context.fetch(start2, {method: 'POST'});
  const jsonClone = await jsonResponse.clone().json();
  const fetchData = await jsonResponse.json();
  assert.deepEqual(fetchJson.coordinateRequests, []);
  assert.deepEqual(Array.from(jsonClone.api_data.api_mst_shipgraph[0].api_boko_d), [300, 205]);
  assert.deepEqual(Array.from(fetchData.api_data.api_mst_shipgraph[0].api_boko_n), [320, 202]);
  assert.deepEqual(fetchJson.coordinateRequests.map(request => request.stem), [fusouStem]);

  const mixed = kanxyEnv({config: {
    sessionId: 9,
    token: 'mixed-session',
    ships: {'748': {graph: {api_boko_n: [180, 181]}, resourceIds: ['local:fusou-coordinates']}},
    kanxy: true,
    localArtShips: [623],
  }});
  const [localField, localArt] = parseStartupInGame(mixed, request(mixed).observed);
  assert.deepEqual(Array.from(localField.api_boko_n), [180, 181]);
  assert.deepEqual(Array.from(localArt.api_boko_n), [5, 10]);
  assert.deepEqual(mixed.coordinateRequests, []);
  assert.deepEqual(Array.from(localField.api_boko_d), [300, 205]);
  assert.deepEqual(mixed.coordinateRequests.map(request => request.stem), [fusouStem]);
  assert.deepEqual(mixed.reports[0].resourceIds, ['local:fusou-coordinates']);

  const localYubari = kanxyEnv({
    config: {
      sessionId: 10, token: 'local-yubari', kanxy: true, localArtShips: [623],
      ships: {'623': {graph: {api_boko_n: [261, 221]}, resourceIds: ['local:yubari-coordinates']}},
    },
    kanxyCoordinates: {...kanxyCoordinates, [yubariStem]: {api_boko_n: [207, 194]}},
  });
  const [remoteFusou, localYubariShip] = parseStartupInGame(localYubari, request(localYubari).observed);
  assert.deepEqual(Array.from(localYubariShip.api_boko_n), [261, 221]);
  assert.deepEqual(localYubari.coordinateRequests, []);
  assert.deepEqual(Array.from(remoteFusou.api_boko_n), [320, 202]);
  assert.deepEqual(localYubari.coordinateRequests.map(request => request.stem), [fusouStem]);
  assert.deepEqual(localYubari.reports[0].resourceIds, ['local:yubari-coordinates']);

  const retryCoordinates = {};
  const retry = kanxyEnv({kanxyCoordinates: retryCoordinates});
  vm.runInContext('Date.now = () => 10_000', retry.context);
  const [retryShip] = parseStartupInGame(retry, request(retry).observed);
  assert.deepEqual(Array.from(retryShip.api_boko_n), [-30, 120]);
  retryCoordinates[fusouStem] = kanxyCoordinates[fusouStem];
  vm.runInContext('Date.now = () => 11_999', retry.context);
  assert.deepEqual(Array.from(retryShip.api_boko_d), [108, 198]);
  assert.deepEqual(retry.coordinateRequests.map(request => request.stem), [fusouStem]);
  vm.runInContext('Date.now = () => 12_000', retry.context);
  assert.deepEqual(Array.from(retryShip.api_boko_d), [300, 205]);
  assert.deepEqual(Array.from(retryShip.api_boko_n), [320, 202]);
  assert.deepEqual(retry.coordinateRequests.map(request => request.stem), [fusouStem, fusouStem]);

  const off = kanxyEnv({config: {sessionId: 10, token: 'off', ships: {}, kanxy: false, localArtShips: []}});
  const [stock] = parseStartupInGame(off, request(off).observed);
  assert.deepEqual(Array.from(stock.api_boko_n), [-30, 120]);
  assert.deepEqual(off.coordinateRequests, []);
}

async function checkKanxyShipNames() {
  const stockShipNames = JSON.parse(fs.readFileSync(
    path.join(__dirname, '../../assets/data/master_ship_names.json'), 'utf8',
  )).names;
  const aliases = [
    {api_id: 623, api_name: false, api_yomi: 'reading'},
    {api_id: 748, api_name: ' FaLsE ', api_yomi: 'reading'},
    {api_id: 607, api_name: 'Custom alias', api_yomi: 'reading'},
    {api_id: 99998, api_name: false, api_yomi: 'Fallback reading'},
    {api_id: 99999, api_name: 'false', api_yomi: false},
  ];
  const master = JSON.parse(kanxyStartup);
  master.api_data.api_mst_ship = aliases;
  const payload = JSON.stringify(master);
  const text = 'svdata=' + payload;
  const config = {
    sessionId: 12, token: 'kanxy-ship-names', kanxy: true, localArtShips: [623],
    ships: {'623': {graph: {api_boko_n: [261, 221]}, resourceIds: ['local:yubari-coordinates']}},
    stockShipNames,
  };
  const expected = [stockShipNames['623'], stockShipNames['748'], 'Custom alias', 'Fallback reading', '#99999'];
  assert.ok(expected[0] && expected[1]);
  const check = (e, observed) => {
    e.context.observedNames = observed;
    const data = vm.runInContext(
      "typeof observedNames === 'string' ? JSON.parse(observedNames.replace(/^svdata=/, '')) : observedNames",
      e.context,
    ).api_data;
    assert.deepEqual(Array.from(data.api_mst_ship, ship => ship.api_name), expected);
    if (!data.api_mst_shipgraph) return;
    assert.deepEqual(Array.from(data.api_mst_shipgraph[1].api_boko_n), [261, 221]);
    assert.deepEqual(Array.from(data.api_mst_shipgraph[0].api_boko_n), [320, 202]);
    assert.deepEqual(e.coordinateRequests.map(value => value.stem), [fusouStem]);
  };

  for (const order of ['captureFirst', 'captureLast']) {
    const e = kanxyEnv({raw: text, config, [order]: true});
    check(e, request(e, 'text').observed);
    assert.equal(e.messages[0].responseBody, text);
    assert.equal(request(e, 'text', '/kcsapi/api_port/port').observed, text);
    const json = kanxyEnv({raw: payload, config, [order]: true});
    check(json, request(json, 'json').observed);
    assert.deepEqual(JSON.parse(json.messages[0].responseBody), master);
  }

  const jsonString = kanxyEnv({raw: JSON.stringify(text), config, captureLast: true});
  const observedString = request(jsonString, 'json').observed;
  assert.equal(typeof observedString, 'string');
  check(jsonString, observedString);
  assert.equal(JSON.parse(jsonString.messages[0].responseBody), text);

  const fetch = kanxyEnv({raw: payload, config, captureFirst: true});
  const response = await fetch.context.fetch(start2, {method: 'POST'});
  check(fetch, await response.clone().json());
  check(fetch, await response.text());
  await new Promise(setImmediate);
  assert.equal(fetch.messages[0].responseBody, payload);

  const namesOnly = kanxyEnv({
    raw: JSON.stringify({api_result: 1, api_data: {api_mst_ship: aliases}}),
    config: {...config, ships: {}},
  });
  check(namesOnly, request(namesOnly, 'json').observed);

  const stock = kanxyEnv({raw: text, config: {...config, kanxy: false}});
  const originalNames = parse(request(stock).observed).api_data.api_mst_ship;
  assert.deepEqual(originalNames, aliases);
}

function checkKanxyShipArt() {
  const load = (env, src) => {
    const image = new env.context.HTMLImageElement();
    image.src = src;
    return image.src;
  };
  const path = '/kcs2/resources/ship/full/0668_4249_yizetqxpvltq.png';
  const first = kanxyEnv();
  const firstUrl = new URL(load(first, path));
  assert.equal(firstUrl.pathname, path);
  assert.match(firstUrl.search, /^\?version=yahagi-[a-z0-9]+$/);
  assert.equal(load(first, path), firstUrl.href);
  assert.notEqual(load(kanxyEnv(), path), firstUrl.href);
  assert.match(new URL(load(first, path + '?version=25~beta')).search, /^\?version=25~beta-yahagi-[a-z0-9]+$/);
  assert.equal(load(first, path + '?signed=value'), path + '?signed=value');
  assert.equal(load(first, '/kcs2/img/common/error.png'), '/kcs2/img/common/error.png');
  const external = 'https://example.test' + path;
  assert.equal(load(first, external), external);
  assert.equal(load(env(), path), path);
}

function checkKanxyDocumentLifecycle() {
  const config = {
    sessionId: 13, token: 'same-local-session',
    ships: {'623': {graph: {api_boko_n: [261, 221]}, resourceIds: ['local:yubari-coordinates']}},
    localArtShips: [623], kanxy: false,
  };
  const portraitPath = '/kcs2/resources/ship/full/0623_5644_tuzbqjvyptyt.png';
  const portraitUrl = portraitPath + '?version=25';

  for (const active of [false, true, false]) {
    config.kanxy = active;
    const document = kanxyEnv({config});
    assert.deepEqual(document.configRequests, [{method: 'GET', async: false}]);
    assert.deepEqual(document.network, []);
    assert.deepEqual(document.coordinateRequests, []);

    const image = new document.context.HTMLImageElement();
    image.src = portraitUrl;
    if (active) {
      const url = new URL(image.src);
      assert.equal(url.pathname, portraitPath);
      assert.match(url.search, /^\?version=25-yahagi-[a-z0-9]+$/);
    } else {
      assert.equal(image.src, portraitUrl);
    }

    const [fusou, yubari] = parseStartupInGame(document, request(document).observed);
    assert.deepEqual(Array.from(yubari.api_boko_n), [261, 221]);
    assert.deepEqual(Array.from(fusou.api_boko_n), active ? [320, 202] : [-30, 120]);
    assert.deepEqual(document.coordinateRequests.map(value => value.stem), active ? [fusouStem] : []);
    assert.deepEqual(document.reports[0].resourceIds, ['local:yubari-coordinates']);
  }
}

let assertions = 0;
async function run() {
  for (let round = 1; round <= 3; round++) {
    for (const type of ['', 'text', 'json']) {
      const e = env(); const {xhr, observed} = request(e, type);
      checkPatched(observed); checkPatched(xhr.response);
      assert.equal(e.reports.length, 1); assert.deepEqual(e.reports[0].resourceIds, ['package:coordinates']);
      assert.equal(e.network[0].body, 'api_token=unchanged&api_verno=1');
      assert.equal(e.network.length, 1);
      assertions++;
    }
    for (const order of ['captureFirst', 'captureLast']) {
      const e = env({[order]: true}); checkPatched(request(e).observed);
      assert.equal(e.messages[0].responseBody, raw);
      const response = await e.context.fetch('/kcsapi/api_start2/getData', {method: 'POST'});
      assert.ok(response instanceof Response); checkPatched(await response.text());
      await new Promise(setImmediate);
      assert.equal(e.messages.at(-1).responseBody, raw);
      assertions++;
      const jsonCapture = env({[order]: true}); checkPatched(request(jsonCapture, 'json').observed);
      assert.deepEqual(JSON.parse(jsonCapture.messages[0].responseBody), parse(raw));
      assertions++;
    }
    const e = env(); e.injectMod();
    assert.equal(request(e, '', '/kcsapi/api_port/port').observed, raw); assert.equal(e.reports.length, 0);
    checkPatched(request(e).observed); assert.equal(e.reports.length, 1); assertions++;
    const off = env({config: {sessionId: 8, token: 'off', ships: {}}});
    assert.equal(request(off).observed, raw); assert.equal(off.reports.length, 0); assertions++;
    for (const body of ['svdata={bad', '{"api_result":0}', '{"api_result":1,"api_data":{"api_mst_shipgraph":[]}}']) {
      const fail = env({raw: body}); assert.equal(request(fail).observed, body);
      assert.ok(fail.reports.some(r => r.failure === 'coordinate_apply_failed')); assertions++;
    }
    const failedHttp = env({status: 500}); assert.equal(request(failedHttp).observed, raw); assertions++;
    const reuse = env(); const {xhr} = request(reuse); xhr.open('POST', '/kcsapi/api_port/port'); xhr.send();
    assert.equal(xhr.responseText, raw); assertions++;
    const captureOnly = env({captureLast: true});
    const unopened = new captureOnly.context.XMLHttpRequest(); unopened.open('POST', '/kcsapi/api_start2/getData'); unopened.send();
    assert.equal(captureOnly.messages[0].responseBody, raw); assert.equal(captureOnly.reports.length, 0); assertions++;
    const plain = env({raw: raw.slice(7)}); checkPatched(request(plain).observed); assertions++;
    const missing = env({raw: '{"api_result":1,"api_data":{"api_mst_shipgraph":[{"api_id":1,"api_boko_n":[2,3]}]}}'});
    const missingData = parse(request(missing).observed); assert.deepEqual(missingData.api_data.api_mst_shipgraph[0].api_boko_n, [2,3]);
    assert.equal(missing.reports[0].failure, 'coordinate_apply_failed'); assertions++;
    const elsewhere = env({location: {href: 'https://example.test/', protocol: 'https:', hostname: 'example.test', port: ''}});
    assert.equal(request(elsewhere).observed, raw); assert.equal(elsewhere.reports.length, 0); assertions++;
    const external = env(); assert.equal(request(external, '', 'https://example.test/kcsapi/api_start2/getData').observed, raw);
    assert.equal(external.reports.length, 0); assertions++;
    const cloneEnv = env({raw: raw.slice(7)}); const cloneResponse = await cloneEnv.context.fetch('/kcsapi/api_start2/getData');
    checkPatched(await cloneResponse.clone().text()); checkPatched(await cloneResponse.json());
    assertions++;
  }
  console.log(`coordinate execution: ${assertions} scenarios passed (3 rounds; XHR text/json, fetch, capture both orders, off/failure/reuse)`);
  await checkKanxyFallback();
  console.log('Kanxy coordinate fallback passed (on demand, local priority, missing, capture, XHR text/json and fetch)');
  checkKanxyShipArt();
  console.log('Kanxy ship art refresh passed (fresh document, stock mode, versioned URLs and origin scope)');
  checkKanxyDocumentLifecycle();
  console.log('Kanxy document lifecycle passed (stock, Kanxy, stock; local selection preserved)');
  await checkKanxyShipNames();
  console.log('Kanxy ship names passed (false sentinels, aliases, native capture, XHR text/json and fetch)');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
