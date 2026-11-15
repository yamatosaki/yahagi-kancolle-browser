const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const kotlin = fs.readFileSync(process.argv[2], 'utf8');
const script = kotlin.match(/val source = """([\s\S]*?)"""\.trimIndent\(\)/)[1];

function fixture(hostname = 'w16s.kancolle-server.com', protocol = 'https:', port = '') {
  const messages = [];
  const window = new EventTarget();
  let canPost = true;

  class NativeSocket extends EventTarget {
    static CONNECTING = 0;
    static OPEN = 1;
    static CLOSING = 2;
    static CLOSED = 3;

    constructor(url, protocols) {
      super();
      this.url = new URL(url).href;
      if (this.url === 'ws://localhost:99/rejected') throw new Error('native policy');
      this.protocols = protocols;
      this.readyState = NativeSocket.CONNECTING;
      this.sent = [];
      this.closes = 0;
    }

    open() {
      this.readyState = NativeSocket.OPEN;
      this.dispatchEvent(new Event('open'));
    }

    send(data) {
      this.sent.push(data);
    }

    close() {
      ++this.closes;
      this.readyState = NativeSocket.CLOSED;
      const event = new Event('close');
      this.dispatchEvent(event);
      this.onclose?.(event);
    }

    receive(data) {
      this.dispatchEvent(new MessageEvent('message', {data}));
    }
  }

  const bridge = {
    postMessage(raw) {
      if (!canPost) throw new Error('native listener unavailable');
      assert.equal(typeof raw, 'string');
      messages.push(raw);
    },
  };
  window.WebSocket = NativeSocket;
  window.__yahagiKanxySocket = bridge;
  const context = vm.createContext({
    window, location: {hostname, protocol, port}, URL, TextEncoder, EventTarget,
  });
  const install = () => vm.runInContext(script, context);
  const reconnect = generation =>
    bridge.onmessage({data: JSON.stringify({kind: 'reconnect', generation})});
  install();
  return {messages, window, NativeSocket, bridge, install, reconnect,
    disablePost: () => { canPost = false; }};
}

const {window, NativeSocket, bridge, messages, install, reconnect, disablePost} = fixture();
const observedWebSocket = window.WebSocket;
assert.deepEqual(messages, ['ready']);
install();
assert.equal(window.WebSocket, observedWebSocket, 'duplicate injection is inert');
assert.deepEqual(messages, ['ready']);
assert.equal(observedWebSocket.OPEN, NativeSocket.OPEN);

const protocols = ['kanxy-new-version'];
const socket = new observedWebSocket('ws://localhost:9099/new-path?version=2', protocols);
assert.ok(socket instanceof NativeSocket);
assert.ok(socket instanceof observedWebSocket);
assert.strictEqual(socket.protocols, protocols);
assert.equal(socket.url, 'ws://localhost:9099/new-path?version=2');
assert.equal(socket.readyState, NativeSocket.CONNECTING);
assert.deepEqual(messages, ['ready', 'WS_REQUESTED']);

const external = new observedWebSocket('wss://localhost.example.com:9099/new-path');
external.open();
assert.deepEqual(messages, ['ready', 'WS_REQUESTED']);
const connecting = new observedWebSocket('wss://[::1]:6111/next');
const ipv4 = new observedWebSocket('ws://127.0.0.1:6112/');
socket.open();
ipv4.open();
socket.send('ping');
assert.deepEqual(socket.sent, ['ping']);
socket.receive('ping');
socket.receive('{"Command":"SPH","SPH":false}');
socket.receive('{"Command":"SPH","SPH":42}');
socket.receive('{"Command":"SPH","SPH":43}');
assert.equal(messages.filter(message => message === 'WS_SPH_RECEIVED').length, 1);
assert.ok(messages.every(message => !message.includes('42') && !message.includes('43')));

let replacement;
socket.onclose = () => {
  replacement = new observedWebSocket(socket.url, protocols);
  replacement.open();
};
bridge.onmessage({data: 'bad json'});
reconnect(0);
assert.equal(socket.closes, 0);
reconnect(5);
assert.equal(socket.closes, 1);
assert.equal(ipv4.closes, 1);
assert.equal(external.closes, 0);
assert.equal(connecting.closes, 0, 'an in-progress connection already establishes a new session');
assert.equal(replacement.closes, 0, 'do not close a socket created by Kanxy onclose during the command');
assert.equal(messages.filter(message => message === 'WS_ROUTE_CLOSED').length, 1);
reconnect(5);
reconnect(4);
assert.equal(replacement.closes, 0, 'duplicate and stale route notices are ignored');

window.dispatchEvent(new Event('pagehide'));
assert.equal(messages.at(-1), 'retired');
reconnect(6);
assert.equal(replacement.closes, 0, 'a retired document ignores commands');
window.dispatchEvent(new Event('pageshow'));
assert.equal(messages.at(-1), 'ready');
reconnect(6);
assert.equal(replacement.closes, 1);

const subclass = class extends observedWebSocket {};
assert.ok(new subclass('ws://localhost:8080/') instanceof subclass);
assert.throws(() => observedWebSocket('ws://localhost:8080/'), TypeError);
assert.throws(() => new observedWebSocket('ws://localhost:99/rejected'), /native policy/);
assert.equal(messages.at(-1), 'WS_TRANSPORT_FAILED');
disablePost();
const unaffected = new observedWebSocket('ws://localhost:8080/');
unaffected.open();
assert.equal(unaffected.readyState, NativeSocket.OPEN, 'listener failure cannot affect native connection');

const retiring = fixture();
const retiringSocket = new retiring.window.WebSocket('ws://localhost:6617/');
retiringSocket.open();
const pendingSocket = new retiring.window.WebSocket('wss://[::1]:6618/');
const externalSocket = new retiring.window.WebSocket('wss://example.com/');
externalSocket.open();
let failedRetry = false;
retiringSocket.onclose = () => {
  assert.throws(
    () => new retiring.window.WebSocket(new URL('ws://127.0.0.1:6617/')),
    /retired/i,
  );
  failedRetry = true;
};
retiring.bridge.onmessage({data: JSON.stringify({kind: 'retire'})});
assert.ok(failedRetry, 'Kanxy cannot create a new local socket from the retired frame');
assert.equal(retiringSocket.closes, 1);
assert.equal(pendingSocket.closes, 1);
assert.equal(externalSocket.closes, 0);
const retiredMessages = [...retiring.messages];
retiring.window.dispatchEvent(new Event('pageshow'));
retiring.reconnect(7);
assert.deepEqual(retiring.messages, retiredMessages);
assert.throws(
  () => new retiring.window.WebSocket('https://localhost:6619/'),
  /retired/i,
);
assert.ok(new retiring.window.WebSocket('wss://example.com/') instanceof retiring.NativeSocket);

for (const other of [
  fixture('kancolle-server.com'),
  fixture('w16s.kancolle-server.com.example.com'),
  fixture('w16s.kancolle-server.com', 'http:'),
  fixture('w16s.kancolle-server.com', 'https:', '444'),
]) {
  assert.equal(other.window.WebSocket, other.NativeSocket);
  assert.deepEqual(other.messages, []);
}
