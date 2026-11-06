// Run with: node --test tool/test_game_mouse_wheel_script.cjs
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname,
  '../android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameMouseWheelScript.kt'), 'utf8')
  .split('"""')[1];

function frame(pathname = '/kcs2/index.php', initialEnabled = true) {
  const messages = [], events = [], listeners = new Map(), observers = [];
  const reads = {canvas: 0, layout: 0};
  let nativeEnabled = initialEnabled;
  let revision = 0;
  let rect = {left: 10, top: 20, width: 1200, height: 720};
  const canvas = {
    isConnected: true,
    getBoundingClientRect: () => { reads.layout++; return rect; },
    dispatchEvent: event => { events.push(event); return false; },
  };
  let currentCanvas = canvas;
  const bridge = {postMessage: data => {
    const message = JSON.parse(data);
    messages.push(message);
    if (message.kind === 'ready') receive({kind: 'configure', enabled: nativeEnabled, revision});
  }};
  const document = {hidden: false, querySelector: () => { reads.canvas++; return currentCanvas; }};
  const window = {
    YahagiMouseWheel: bridge,
    addEventListener: (name, handler) => {
      if (!listeners.has(name)) listeners.set(name, new Set());
      listeners.get(name).add(handler);
    },
    removeEventListener: (name, handler) => listeners.get(name)?.delete(handler),
  };
  function receive(overrides = {}) {
    bridge.onmessage?.({data: JSON.stringify({
      token: messages[0]?.token, kind: 'wheel', x: .5, y: .25,
      deltaX: 0, deltaY: 120, ...overrides,
    })});
  }
  const context = vm.createContext({document, window, location: {pathname},
    MutationObserver: class {
      constructor(handler) {this.handler = handler; this.observing = false; observers.push(this);}
      observe() {this.observing = true;}
      disconnect() {this.observing = false;}
    },
    WheelEvent: class { constructor(type, options) {this.type = type; Object.assign(this, options);} },
  });
  vm.runInContext(source, context, {timeout: 1000});
  return {messages, events, bridge, canvas, context, document, reads, observers,
    listenerCount: name => listeners.get(name)?.size ?? 0,
    emit: name => { for (const handler of listeners.get(name) ?? []) handler(); },
    mutate: () => { for (const observer of observers) if (observer.observing) observer.handler(); },
    queuedMutation: () => { for (const observer of observers) observer.handler(); },
    setCanvas: value => {currentCanvas = value;},
    setRect: value => {rect = value;},
    configure: enabled => {nativeEnabled = enabled; receive({kind: 'configure', enabled, revision: ++revision});},
    send: receive,
  };
}

test('disabled bootstrap handshakes without observing or reading canvas layout', () => {
  const f = frame('/kcs2/index.php', false);
  assert.equal(f.messages[0].kind, 'ready');
  assert.equal(f.observers.filter(o => o.observing).length, 0);
  assert.equal(f.listenerCount('resize'), 0);
  f.mutate();
  f.emit('resize');
  f.send();
  assert.deepEqual(f.reads, {canvas: 0, layout: 0});
  assert.equal(f.events.length, 0);
});

test('enabling immediately discovers existing canvas and delivers the first wheel', () => {
  const f = frame('/kcs2/index.php', false);
  f.configure(true);
  assert.equal(f.messages.at(-1).available, true);
  assert.equal(f.observers.filter(o => o.observing).length, 1);
  f.send();
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].clientX, 610);
  assert.equal(f.events[0].clientY, 200);
});

test('one packet produces one bubbling wheel at the game canvas', () => {
  const f = frame();
  f.send();
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].type, 'wheel');
  assert.equal(f.events[0].deltaY, 120);
  assert.equal(f.events[0].clientX, 610);
  assert.equal(f.events[0].clientY, 200);
  assert.equal(f.events[0].bubbles, true);
  assert.equal(f.events[0].cancelable, true);
  f.send({deltaY: -120});
  assert.equal(f.events[1].deltaY, -120);
});

test('does not install twice or multiply observers and wheel events across toggles', () => {
  const f = frame();
  vm.runInContext(source, f.context, {timeout: 1000});
  assert.equal(f.messages.filter(m => m.kind === 'ready').length, 1);
  for (let i = 0; i < 4; i++) {
    f.configure(false);
    f.configure(true);
    f.configure(true);
    assert.equal(f.observers.filter(o => o.observing).length, 1);
    assert.equal(f.listenerCount('resize'), 1);
  }
  f.send();
  assert.equal(f.events.length, 1);
});

test('outer gadget documents never observe, handshake or receive game wheels', () => {
  const f = frame('/gadget_html5/');
  assert.equal(f.messages.length, 0);
  f.send();
  assert.equal(f.events.length, 0);
  assert.equal(f.observers.length, 0);
  assert.deepEqual(f.reads, {canvas: 0, layout: 0});
});

test('ignores old document tokens, invalid input and hidden/detached games', () => {
  const f = frame();
  for (const data of [{token: 'old'}, {x: -1}, {x: 1}, {y: 1},
    {deltaY: 0}, {deltaY: null}, {deltaY: '120'}, {kind: 'click'}]) f.send(data);
  f.bridge.onmessage({data: 'not json'});
  f.document.hidden = true;
  f.send();
  f.document.hidden = false;
  f.canvas.isConnected = false;
  f.send();
  f.mutate();
  assert.equal(f.events.length, 0);
  assert.equal(f.messages.at(-1).available, false);
});

test('enabled DOM changes and resize keep discovering and withdrawing the canvas', () => {
  const f = frame();
  f.setCanvas(null);
  f.mutate();
  assert.equal(f.messages.at(-1).available, false);
  f.setCanvas(f.canvas);
  f.mutate();
  assert.equal(f.messages.at(-1).available, true);
  f.setRect({left: 5, top: 6, width: 0, height: 0});
  f.emit('resize');
  assert.equal(f.messages.at(-1).available, false);
  f.setRect({left: 5, top: 6, width: 600, height: 360});
  f.emit('resize');
  assert.equal(f.messages.at(-1).available, true);
  f.send();
  assert.equal(f.events[0].clientX, 305);
  assert.equal(f.events[0].clientY, 96);
});

test('disable disconnects observation and blocks even already queued DOM callbacks', () => {
  const f = frame();
  f.configure(false);
  const before = {...f.reads};
  assert.equal(f.messages.at(-1).available, false);
  assert.equal(f.observers.filter(o => o.observing).length, 0);
  assert.equal(f.listenerCount('resize'), 0);
  f.mutate();
  f.queuedMutation();
  f.emit('resize');
  f.send();
  assert.deepEqual(f.reads, before);
  assert.equal(f.events.length, 0);
});

test('pagehide disconnects and pageshow handshakes for the current native preference', () => {
  const f = frame();
  f.emit('pagehide');
  assert.equal(f.messages.at(-1).kind, 'gone');
  const before = {...f.reads};
  f.configure(true); // An in-flight enable reply must not revive a hidden document.
  f.queuedMutation();
  f.emit('resize');
  f.send();
  assert.deepEqual(f.reads, before);
  assert.equal(f.observers.filter(o => o.observing).length, 0);
  f.configure(false);
  f.emit('pageshow');
  assert.equal(f.messages.at(-1).kind, 'ready');
  assert.deepEqual(f.reads, before);
  f.configure(true);
  assert.equal(f.messages.at(-1).available, true);
  f.send();
  assert.equal(f.events.length, 1);
});

test('wrong-token and non-boolean configuration cannot enable a disabled frame', () => {
  const f = frame('/kcs2/index.php', false);
  f.send({kind: 'configure', token: 'previous-document', enabled: true, revision: 1});
  f.send({kind: 'configure', enabled: 'true', revision: 1});
  assert.deepEqual(f.reads, {canvas: 0, layout: 0});
  assert.equal(f.observers.filter(o => o.observing).length, 0);
});

test('availability identifies the current configuration and stale enable replies are ignored', () => {
  const f = frame('/kcs2/index.php', false);
  f.configure(true);
  assert.equal(f.messages.at(-1).revision, 1);
  f.configure(false);
  const before = {...f.reads};
  f.send({kind: 'configure', enabled: true, revision: 1});
  f.send();
  assert.deepEqual(f.reads, before);
  assert.equal(f.events.length, 0);
  f.configure(true);
  assert.equal(f.messages.at(-1).revision, 3);
});
