package app.yahagi.kancollebrowser.mods

/** Builds a lookup for track titles already displayed by the game. */
internal object GameModChsBgmNames {
    val source: String =
        """
        const buildGameBgmNames = (bgm) => {
          const names = new Map();
          if (!bgm || typeof bgm !== 'object') return names;
          const entries = (group) => group && typeof group === 'object' && !Array.isArray(group)
            ? Object.entries(group) : [];
          const hasText = (value) => typeof value === 'string' && value.trim().length > 0;
          for (const [original, translated] of entries(bgm.titles)) {
            if (hasText(original) && hasText(translated)) names.set(original, translated);
          }

          // Audio IDs belong to separate channels. Only use their title pairs
          // when every supplied translation for an original title agrees.
          const candidates = new Map();
          for (const channel of [bgm.port, bgm.battle]) {
            for (const [, track] of entries(channel)) {
              if (!track || !hasText(track.ja) || !hasText(track.zh) || names.has(track.ja)) continue;
              const previous = candidates.get(track.ja);
              candidates.set(track.ja, previous === undefined || previous === track.zh ? track.zh : null);
            }
          }
          for (const [original, translated] of candidates) {
            if (translated !== null) names.set(original, translated);
          }
          return names;
        };
        """.trimIndent()
}
