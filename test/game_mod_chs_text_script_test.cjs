// Exercise the production script with PIXI-compatible game text components.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const [textSource, bgmSource] = process.argv.slice(2);
function kotlinSource(path) {
  const kotlin = fs.readFileSync(path, 'utf8');
  return kotlin.match(/val source: String\s*=\s*"""([\s\S]*?)"""/)[1]
    .replace(/\$\{'\$'\}/g, '$');
}
const hook = kotlinSource(textSource);
const bgm = kotlinSource(bgmSource);

function page({late = false, locked = false} = {}) {
  const calls = [];
  const listeners = new Map();
  class TextStyle {
    constructor(properties) { Object.assign(this, properties); }
    clone() { return new TextStyle(this); }
  }
  class Text {
    constructor(value = '') {
      this.style = new TextStyle({fontSize: 20, fill: '#000'});
      this.text = value;
    }
    get text() { return this._text; }
    set text(value) {
      calls.push(value);
      this._text = value == null || value === '' ? ' ' : String(value);
    }
  }
  if (locked) Object.defineProperty(Text.prototype, 'text', {configurable: false});
  const pixi = {Text, TextStyle};
  const document = {
    addEventListener(type, listener, capture) {
      if (type !== 'load') return;
      assert.equal(capture, true);
      listeners.set(type, listener);
    },
    removeEventListener(type, listener, capture) {
      assert.equal(capture, true);
      if (listeners.get(type) === listener) listeners.delete(type);
    },
  };
  const browser = {
    document,
    addEventListener() {},
    removeEventListener() {},
  };
  if (!late) browser.PIXI = pixi;
  const vmContext = vm.createContext({window: browser});
  vm.runInContext(bgm + '\n' + hook, vmContext, {timeout: 1500});
  return {
    browser, calls, pixi, listeners,
    addPixi() {
      browser.PIXI = pixi;
      listeners.get('load')?.({target: {localName: 'script'}});
    },
    install(data) {
      vmContext.testData = JSON.stringify(data);
      vm.runInContext("installGameText(testData === undefined ? undefined : JSON.parse(testData));", vmContext,
        {timeout: 1500});
    },
  };
}

const data = {
  dictionaries: {
    map: {
      '母港': '港口',
      '作戦': '<s0.5><c#ffcc00><wbold><n210><l2>作战',
      '第一艦隊<br>出撃': '第一舰队<br>出击',
      '先行作戦': '前进',
      '長い説明': '',
      '未変換': '<img src=x onerror=throw()>说明',
      '特瓦': '特',
      '特': '不可重复翻译',
    },
    jukebox: {'工廠': '精确工厂'},
  },
  regex: {
    malformed: [['[', 'bad'], ['(a+)+$', 'bad'], ['(a|aa)+$', 'bad']],
    stats: [['(/?)対空(\\+|\\-)', '$1对空$2']],
    terms: [
      ['を([0-9]+)個手に入れました。', '获得了$1个'],
      ['(.+?)\\s*が\\s*【遠征】から帰投しました。', '$1 从【远征】返回了。'],
      ['^[速]+い$', '快'],
      ['^た$', ''],
      ['^レシピ (.+)$', '配方 $1'],
      ['^配方 ', '舰装 '],
      ['^予定\\n', '计划\n'],
    ],
  },
  bgm: {
    titles: {'工廠': 'BGM工厂', '出撃の曲': '出击之曲'},
    port: {'101': {ja: '母港', zh: 'BGM母港'}, '102': {ja: '春の歌', zh: '春之歌'}},
  },
};

{
  const p = page({late: true});
  p.install();
  p.install({});
  p.install({regex: {bad: [['[', 'bad'], ['(a+)+$', 'bad']]}});
  assert.equal(p.listeners.size, 0);
  assert.equal(Object.hasOwn(p.browser, 'PIXI'), false);
  p.addPixi();
  assert.equal(new p.pixi.Text('母港').text, '母港');
}

{
  const p = page({late: true});
  const original = Object.getOwnPropertyDescriptor(p.pixi.Text.prototype, 'text');
  p.install(data);
  assert.equal(p.listeners.size, 1);
  p.addPixi();
  assert.equal(p.listeners.size, 0);
  assert.equal(Object.getOwnPropertyDescriptor(p.pixi.Text.prototype, 'text').get, original.get);
  assert.equal(new p.pixi.Text('母港').text, '港口');
  p.install(data);
  assert.equal(new p.pixi.Text('特瓦').text, '特');
}

{
  const p = page();
  p.install(data);
  assert.equal(p.listeners.size, 0);
  const text = new p.pixi.Text('/対空-2');
  assert.equal(text.text, '/对空-2');
  text.text = '第三艦隊が【遠征】から帰投しました。';
  assert.equal(text.text, '第三艦隊 从【远征】返回了。');
  text.text = 'レシピ 15';
  assert.equal(text.text, '舰装 15');
  text.text = '予定\nABC';
  assert.equal(text.text, '计划\nABC');
  text.text = 'た';
  assert.equal(text.text, ' ');
  text.text = '速速い';
  assert.equal(text.text, '快');
  text.text = '第一艦隊<br>出撃';
  assert.equal(text.text, '第一舰队\n出击');
  text.text = '第一艦隊\r\n出撃';
  assert.equal(text.text, '第一舰队\n出击');
  text.text = '未変換';
  assert.equal(text.text, '<img src=x onerror=throw()>说明');
  text.text = 'unknown<br>line';
  assert.equal(text.text, 'unknown<br>line');
  text.text = 'toString';
  assert.equal(text.text, 'toString');
  text.text = '工廠';
  assert.equal(text.text, '精确工厂');
  text.text = '出撃の曲';
  assert.equal(text.text, '出击之曲');
  text.text = '♪「工廠」';
  assert.equal(text.text, '♪「精确工厂」');
  text.text = '♪「春の歌」';
  assert.equal(text.text, '♪「春之歌」');
  text.text = '♪「未変換」';
  assert.equal(text.text, '♪「未変換」');
  text.text = null;
  assert.equal(p.calls.at(-1), null);
  const rawValue = {toString() { return '母港'; }};
  text.text = rawValue;
  assert.equal(p.calls.at(-1), rawValue);
  assert.equal(text.text, '母港');
  text.text = 'a'.repeat(512) + '!';
  assert.equal(text.text.length, 513);
  text.text = 'a'.repeat(384) + '!';
  assert.equal(text.text.length, 385);
  const base = text.style;
  text.text = '作戦';
  assert.equal(text.text, '作战');
  assert.equal(text.style.fontSize, 10);
  assert.equal(text.style.fill, '#ffcc00');
  assert.equal(text.style.fontWeight, 'bold');
  assert.equal(text.style.wordWrap, true);
  assert.equal(text.style.wordWrapWidth, 210);
  assert.equal(text.style.leading, 2);
  text.text = 'unknown';
  assert.equal(text.style, base);
}

{
  const p = page({locked: true});
  p.install(data);
  assert.equal(new p.pixi.Text('母港').text, '母港');
}

{
  const p = page();
  p.install(data);
  class MessageBox {
    constructor() {
      this._text = new p.pixi.Text();
      this._t = null;
      this._text.parent = this;
    }
    initializeForSlot(message) {
      this._text.text = '';
      this._message = message;
    }
    initializeForShip() {}
    activate(done) {
      assert.equal(this._t, null);
      this._t = true;
      return () => {
        while (this._message.length) {
          this._text.text = (this._text.text === ' ' ? '' : this._text.text) + this._message[0];
          this._message = this._message.slice(1);
        }
        this._t = null;
        done();
      };
    }
  }
  const box = new MessageBox();
  let elapsed = 0;
  box.initializeForSlot('特瓦');
  box.activate(() => ++elapsed)();
  assert.equal(box._text.text, '特');
  box.initializeForSlot('を9個手に入れました。');
  box.activate(() => ++elapsed)();
  assert.equal(box._text.text, '获得了9个');
  box.initializeForSlot('長い説明');
  box.activate(() => ++elapsed)();
  assert.equal(box._text.text, ' ');
  assert.equal(elapsed, 3);

  class RemodelBox {
    constructor() {
      this._text = new p.pixi.Text();
      this._text.parent = this;
    }
    initialize() { this._text.text = '未登録'; }
    _startAnimation(message) { return message; }
    _stopAnimation() {}
    changeText(message) { return this._startAnimation(message); }
  }
  const remodel = new RemodelBox();
  remodel.initialize();
  assert.equal(remodel.changeText('第一艦隊<br>出撃'), '第一舰队\n出击');
  assert.equal(remodel.changeText('unknown<br>line'), 'unknown<br>line');

  class MessageBoxView {
    constructor() {
      this.message = new p.pixi.Text();
      this.message.parent = this;
      this.message.text = '';
    }
    flashText(message, speed) { return [message, speed]; }
    start() {}
    dispose() {}
  }
  const tutorial = new MessageBoxView();
  assert.deepEqual(tutorial.flashText('先行作戦', 20), ['前进', 20]);
  assert.deepEqual(tutorial.flashText('unknown<br>line', 80), ['unknown<br>line', 80]);
}

console.log('CHS display translations passed');
