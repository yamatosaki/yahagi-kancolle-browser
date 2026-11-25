package app.yahagi.kancollebrowser.mods

/** Installs display-only translations on the game frame's PIXI text components. */
internal object GameModChsTextScript {
    val source: String =
        """
        const installGameText = (translations) => {
          if (!translations || typeof translations !== 'object' || window.__yahagiGameTextInstalled) return;
          const entries = (value) => value && typeof value === 'object' && !Array.isArray(value)
            ? Object.entries(value) : [];
          const dictionaries = new Map();
          const dictionaryLines = new Map();
          const jukeboxNames = new Map();
          const lineBreaks = (value) => value.replace(/<br\s*\/?>|\r\n?/gi, '\n');
          const normalize = (value) => lineBreaks(value).replace(/\u2019/g, "'");
          for (const [name, group] of entries(translations.dictionaries)) {
            for (const [key, value] of entries(group)) {
              if (!key || typeof value !== 'string' || key === 'dummy' || value === 'forNoComma') continue;
              dictionaries.set(key, value);
              if (name === 'jukebox') jukeboxNames.set(key, value);
              const clean = normalize(key);
              if (clean !== key) dictionaryLines.set(clean, value);
            }
          }
          const bgmNames = buildGameBgmNames(translations.bgm);

          // The native importer guards regex complexity. A required literal keeps
          // unrelated PIXI text from entering the regex engine on each assignment.
          const requiredLiteral = (pattern) => {
            let best = '', run = '', depth = 0, inClass = false;
            const finish = (suffixLength = 0) => {
              const literal = run.slice(0, run.length - suffixLength);
              if (literal.length > best.length) best = literal;
              run = '';
            };
            for (let index = 0; index < pattern.length; index++) {
              const char = pattern[index];
              if (char === '\\') {
                if (!inClass && depth === 0) {
                  finish();
                  if (/[0-9cuxpk]/.test(pattern[index + 1] || '')) return '';
                }
                index++;
              } else if (inClass) {
                if (char === ']') inClass = false;
              } else if (char === '[') {
                if (depth === 0) finish();
                inClass = true;
              } else if (char === '(') {
                if (depth === 0) finish();
                depth++;
              } else if (char === ')') {
                depth--;
              } else if (depth === 0) {
                if (char === '|') return '';
                if (char === '{') {
                  finish(1);
                  const end = pattern.indexOf('}', index + 1);
                  if (end === -1) return '';
                  index = end;
                } else if ('*+?'.includes(char)) {
                  finish(1);
                } else if ('.^${'$'}'.includes(char)) {
                  finish();
                } else {
                  run += char;
                }
              }
            }
            finish();
            return best;
          };
          const rules = [];
          for (const [, group] of entries(translations.regex)) {
            if (!Array.isArray(group)) continue;
            for (const row of group) {
              if (rules.length >= 1024) break;
              if (!Array.isArray(row) || row.length !== 2) continue;
              const [pattern, replacement] = row;
              if (typeof pattern !== 'string' || !pattern || pattern.length > 256 ||
                  typeof replacement !== 'string' || replacement.length > 1024 ||
                  /\)[*+]/.test(pattern) || pattern === 'dummy' || replacement === 'forNoComma') continue;
              try {
                rules.push([new RegExp(pattern, 'gm'), replacement, requiredLiteral(pattern)]);
              } catch (_) {}
            }
          }
          if (!dictionaries.size && !bgmNames.size && !rules.length) return;
          window.__yahagiGameTextInstalled = true;

          const regexCache = new Map();
          const replaceRules = (initial) => {
            if (!initial || initial.length > 512) return initial;
            if (regexCache.has(initial)) return regexCache.get(initial);
            let text = initial;
            for (const [pattern, replacement, required] of rules) {
              if (text.length > 512) break;
              if (required && !text.includes(required)) continue;
              const next = text.replace(pattern, replacement);
              if (next.length > 2048) {
                text = initial;
                break;
              }
              text = next;
            }
            if (regexCache.size >= 256) regexCache.delete(regexCache.keys().next().value);
            regexCache.set(initial, text);
            return text;
          };
          const translated = (raw, typewriter = false) => {
            if (typeof raw !== 'string' || !raw) return raw;
            let next = dictionaries.get(raw) ?? bgmNames.get(raw);
            // The Military Record screen surrounds the track name with this
            // fixed label, while the Jukebox writes the name directly.
            if (next === undefined && raw.startsWith('♪「') && raw.endsWith('」')) {
              const name = raw.slice(2, -1);
              const localized = jukeboxNames.get(name) ?? bgmNames.get(name);
              if (localized !== undefined) next = '♪「' + localized + '」';
            }
            const clean = /[<\r\u2019]/.test(raw) ? normalize(raw) : raw;
            if (next === undefined) {
              next = dictionaries.get(clean) ?? dictionaryLines.get(clean);
              if (typewriter && next === undefined) {
                const trimmed = clean.trim();
                const noFinalNewline = clean.replace(/\n+${'$'}/, '');
                next = dictionaries.get(trimmed) ?? dictionaryLines.get(trimmed) ??
                  dictionaries.get(noFinalNewline) ?? dictionaryLines.get(noFinalNewline);
              }
            }
            if (typewriter && next !== undefined) return lineBreaks(next);
            const base = next ?? clean;
            const result = rules.length ? replaceRules(base) : base;
            return next !== undefined || result !== clean ? lineBreaks(result) : raw;
          };

          const styled = new WeakMap();
          const readStyle = (value) => {
            const properties = {};
            let text = value;
            while (text.startsWith('<')) {
              const tag = /^<(?:([snl])(-?\d+(?:\.\d+)?)|c(#[0-9a-fA-F]{3,8})|w(normal|bold|bolder|lighter|[1-9]00))>/.exec(text);
              if (!tag) break;
              if (tag[1]) {
                const number = Number(tag[2]);
                if (tag[1] === 's' && number > 0 && number <= 4) properties.scale = number;
                if (tag[1] === 'n' && number > 0 && number <= 4096) properties.wrap = number;
                if (tag[1] === 'l' && Math.abs(number) <= 128) properties.leading = number;
              }
              if (tag[3]) properties.fill = tag[3];
              if (tag[4]) properties.weight = tag[4];
              text = text.slice(tag[0].length);
            }
            return {text, properties};
          };
          const prepareText = (node, message, changed) => {
            const previous = styled.get(node);
            if (previous?.message === message && changed && node.style === previous.applied) return previous.text;
            if (previous) {
              styled.delete(node);
              if (node.style === previous.applied) node.style = previous.base;
            }
            if (!changed || typeof message !== 'string' || !message.startsWith('<')) return message;
            const {text, properties} = readStyle(message);
            const base = node.style;
            if (Object.keys(properties).length && typeof base?.clone === 'function') {
              const next = base.clone();
              if (properties.scale !== undefined && Number.isFinite(base.fontSize)) {
                next.fontSize = base.fontSize * properties.scale;
              }
              if (properties.fill !== undefined) next.fill = properties.fill;
              if (properties.weight !== undefined) next.fontWeight = properties.weight;
              if (properties.leading !== undefined) next.leading = properties.leading;
              if (properties.wrap !== undefined) {
                next.wordWrap = true;
                next.wordWrapWidth = properties.wrap;
              }
              node.style = next;
              styled.set(node, {base, applied: next, message, text});
            }
            return text;
          };

          const animated = new WeakMap();
          const seenParents = new WeakSet();
          const animationText = (node, raw) => {
            if (typeof raw !== 'string' || !raw) return raw;
            const next = translated(raw, true);
            // A blank translation still needs one character so the game reaches
            // its final-character callback and releases the tween.
            const message = prepareText(node, next, next !== raw) || ' ';
            animated.set(node, message);
            return message;
          };
          const wrapAnimation = (parent, method, before) => {
            const original = parent[method];
            Object.defineProperty(parent, method, {
              configurable: true, writable: true,
              value: function (...args) {
                try { before(this, args); } catch (_) {}
                return Reflect.apply(original, this, args);
              },
            });
          };
          const discoverTypewriter = (node) => {
            const parent = node.parent;
            if (!parent || seenParents.has(parent)) return;
            if (parent._text === node) {
              if (typeof parent.activate === 'function' && typeof parent.initializeForSlot === 'function' &&
                  typeof parent.initializeForShip === 'function') {
                wrapAnimation(parent, 'activate', (box) => {
                  if (box._t == null && typeof box._message === 'string' && box._message) {
                    box._message = animationText(box._text, box._message);
                  }
                });
              } else if (typeof parent._startAnimation === 'function' && typeof parent._stopAnimation === 'function' &&
                  typeof parent.changeText === 'function') {
                wrapAnimation(parent, '_startAnimation', (box, args) => {
                  if (box._t == null) args[0] = animationText(box._text, args[0]);
                });
              } else return;
            } else if (parent.message === node && typeof parent.flashText === 'function' &&
                typeof parent.start === 'function' && typeof parent.dispose === 'function') {
              wrapAnimation(parent, 'flashText', (box, args) => {
                args[0] = animationText(box.message, args[0]);
              });
            } else return;
            seenParents.add(parent);
          };
          const hookPixi = () => {
            try {
              const prototype = window.PIXI?.Text?.prototype;
              const original = prototype && Object.getOwnPropertyDescriptor(prototype, 'text');
              if (!original?.configurable || typeof original.set !== 'function') return false;
              Object.defineProperty(prototype, 'text', {
                ...original,
                set(value) {
                  let target = value;
                  try {
                    discoverTypewriter(this);
                    const message = animated.get(this);
                    if (message !== undefined && typeof value === 'string' && message.startsWith(value)) {
                      if (message === value) animated.delete(this);
                    } else {
                      animated.delete(this);
                      const next = translated(value);
                      target = prepareText(this, next, next !== value);
                    }
                  } catch (_) {}
                  original.set.call(this, target);
                },
              });
              return true;
            } catch (_) {
              return false;
            }
          };
          const gameDocument = window.document;
          if (hookPixi() || typeof gameDocument?.addEventListener !== 'function') return;
          // Capturing the classic library script's load handles parser-order
          // PIXI exports without modifying a global or waiting for a poll.
          const stopWatching = () => {
            gameDocument.removeEventListener('load', onScriptLoad, true);
            window.removeEventListener('load', onDocumentLoad);
          };
          const onScriptLoad = (event) => {
            if (event.target?.localName === 'script' && hookPixi()) stopWatching();
          };
          const onDocumentLoad = () => {
            hookPixi();
            stopWatching();
          };
          gameDocument.addEventListener('load', onScriptLoad, true);
          window.addEventListener('load', onDocumentLoad);
        };
        """.trimIndent()
}
