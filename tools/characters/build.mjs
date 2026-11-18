// Writes the player characters out for both apps, from the drawings in art.mjs.
//
//   node tools/characters/build.mjs
//
// It rewrites three files; change a drawing in art.mjs and run this again, never edit them by hand:
//   android/app/src/main/java/com/doyourwork/app/engine/CharacterArt.kt
//   ios/DoYourWorkCore/Sources/DoYourWorkCore/CharacterArt.swift
//   launch/brand/characters.svg   (a sheet of all of them, for looking at)
import { writeFileSync } from 'node:fs';
import { characters } from './art.mjs';

const root = new URL('../../', import.meta.url);
const note = 'Written by tools/characters/build.mjs from tools/characters/art.mjs. Change the drawings there.';

for (const c of characters) for (const l of c.layers) {
  if (!/^[MLCQZ0-9. ]+$/.test(l.d)) throw new Error(`${c.id}: a path uses something other than absolute M, L, C, Q and Z`);
  for (const v of l.d.match(/[0-9.]+/g)) if (+v < 0 || +v > 40) throw new Error(`${c.id}: ${v} is outside the 40 × 40 square`);
}

writeFileSync(new URL('android/app/src/main/java/com/doyourwork/app/engine/CharacterArt.kt', root), `// ${note}
package com.doyourwork.app.engine

internal object CharacterArt {
    val ALL: List<PlayerCharacter> = listOf(
${characters.map((c) => `        PlayerCharacter("${c.id}", "${c.name}", listOf(
${c.layers.map((l) => `            PlayerCharacter.Layer(${l.detail}, "${l.d}"),`).join('\n')}
        )),`).join('\n')}
    )
}
`);

writeFileSync(new URL('ios/DoYourWorkCore/Sources/DoYourWorkCore/CharacterArt.swift', root), `// ${note}

enum CharacterArt {
    static let all: [PlayerCharacter] = [
${characters.map((c) => `        PlayerCharacter(id: "${c.id}", name: "${c.name}", layers: [
${c.layers.map((l) => `            .init(detail: ${l.detail}, path: "${l.d}"),`).join('\n')}
        ]),`).join('\n')}
    ]
}
`);

const heat = ['#D90015', '#DB2A15', '#E04A19', '#E2751C', '#E99A22', '#EDB82A'];
const cell = 120, cols = 4;
writeFileSync(new URL('launch/brand/characters.svg', root), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${cols * cell} ${Math.ceil(characters.length / cols) * cell}">
<!-- ${note} -->
${characters.map((c, i) => { const x = (i % cols) * cell, y = Math.floor(i / cols) * cell;
  return `<g transform="translate(${x} ${y})"><title>${c.name}</title><rect width="${cell}" height="${cell}" fill="${heat[(i + Math.floor(i / cols)) % heat.length]}"/><g transform="translate(20 20) scale(2)">${c.layers.map((l) => `<path d="${l.d}" fill="${l.detail ? '#fff' : '#000'}"/>`).join('')}</g></g>`; }).join('\n')}
</svg>
`);
console.log(`${characters.length} characters written for Android and iOS.`);
