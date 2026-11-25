const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const vm = require('node:vm');

const kotlin = fs.readFileSync(process.argv[2], 'utf8');
const source = kotlin.match(/val source: String\s*=\s*"""([\s\S]*?)"""/)[1];
const context = vm.createContext({});
const buildGameBgmNames = vm.runInContext(`${source}\nbuildGameBgmNames;`, context);

test('absent BGM data yields an empty lookup without installing global hooks', () => {
  assert.equal(buildGameBgmNames(undefined).size, 0);
  assert.equal(buildGameBgmNames(null).size, 0);
  assert.equal(buildGameBgmNames({}).size, 0);
  assert.deepEqual(Object.keys(context), []);
});

test('BGM titles match exactly and preserve surrounding spaces and case', () => {
  const names = buildGameBgmNames({
    titles: { 'ＢＧＭ X ': '译名 A', '海原越えて': '跨越海原' },
  });
  assert.equal(names.get('ＢＧＭ X '), '译名 A');
  assert.equal(names.get('ＢＧＭ X'), undefined);
  assert.equal(names.get('ＢＧＭ x '), undefined);
  assert.equal(names.get('海原越えて'), '跨越海原');
});

test('port and battle supply distinct and consistently translated names', () => {
  const names = buildGameBgmNames({
    port: {
      101: { ja: '母港', zh: '母港' },
      102: { ja: '出撃', zh: '出击' },
    },
    battle: {
      101: { ja: '夜戦', zh: '夜战' },
      103: { ja: '出撃', zh: '出击' },
    },
  });
  assert.equal(names.get('母港'), '母港');
  assert.equal(names.get('夜戦'), '夜战');
  assert.equal(names.get('出撃'), '出击');
  assert.equal(names.get('101'), undefined);
});

test('conflicting variants are skipped unless an explicit title resolves them', () => {
  const names = buildGameBgmNames({
    titles: { '照明弾': '照明弹' },
    port: {
      101: { ja: '索敵', zh: '侦察' },
      102: { ja: '照明弾', zh: '照明用弹' },
    },
    battle: {
      101: { ja: '索敵', zh: '索敌' },
      102: { ja: '照明弾', zh: '照明炮弹' },
      103: { ja: '索敵', zh: '侦察' },
    },
  });
  assert.equal(names.get('索敵'), undefined);
  assert.equal(names.get('照明弾'), '照明弹');
});

test('empty and malformed translations do not mask usable data', () => {
  const names = buildGameBgmNames({
    titles: { '夜戦': ' ' },
    port: {
      101: null,
      102: { ja: '無題' },
      103: { ja: '夜戦', zh: '夜战' },
      104: { ja: ' ', zh: '译名' },
    },
    battle: ['bad'],
  });
  assert.deepEqual(Array.from(names, ([original, translated]) => [original, translated]), [
    ['夜戦', '夜战'],
  ]);
});
