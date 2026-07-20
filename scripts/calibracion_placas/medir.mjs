/**
 * Mide el lector de placas del sistema contra el banco de `generar_banco.py`.
 *
 * Usa EL CÓDIGO REAL: importa `web/src/lib/placas.ts` compilado con esbuild, así que lo que se
 * mide aquí es lo que corre en la garita. Una copia "equivalente" del algoritmo se desviaría
 * del original en la primera corrección y las cifras dejarían de valer.
 *
 * Responde a tres preguntas:
 *   1. ¿Cuántas placas se leen bien en cada condición? (limpia, pantalla del móvil, etc.)
 *   2. ¿Qué variante de preprocesado gana en cada condición?
 *   3. ¿Qué confianza separa una lectura correcta de una equivocada? De ahí salen
 *      UMBRAL_PLACA y UMBRAL_PLACA_REVISION.
 *
 * Uso:  node medir.mjs <carpeta-del-banco> [maximo-por-condicion]
 */

import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { PNG } from 'pngjs';
import { createWorker } from 'tesseract.js';
import {
  VARIANTES_OCR, aplicarVariante, corregirPlacaOcr, extraerPlacaDeTexto,
} from './placas.build.mjs';

/** Réplica exacta de la política de `leerPlacaLocal`: voto entre variantes y confianza por
 *  consenso. Se reimplementa aquí (y no se importa) solo porque esa función necesita el worker
 *  de Tesseract, que aquí ya está creado; el algoritmo es el mismo, línea por línea. */
function elegirPorConsenso(lecturas) {
  if (lecturas.length === 0) return null;
  const votos = new Map();
  for (const l of lecturas) {
    const clave = corregirPlacaOcr(l);
    votos.set(clave, (votos.get(clave) ?? 0) + 1);
  }
  const ganadora = [...votos.entries()].sort((a, b) => b[1] - a[1])[0][0];
  const coincidencias = lecturas.filter((l) => corregirPlacaOcr(l) === ganadora).length;
  const acuerdo = coincidencias / lecturas.length;
  const cobertura = lecturas.length / VARIANTES_OCR.length;
  return { placa: ganadora, confianza: Number((acuerdo * (0.5 + 0.5 * cobertura)).toFixed(2)) };
}

const carpeta = process.argv[2];
const tope = Number(process.argv[3] ?? 0);
if (!carpeta) {
  console.error('Uso: node medir.mjs <carpeta-del-banco> [maximo-por-condicion]');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// El mismo recorte y escalado que hace el navegador, sin canvas
// ---------------------------------------------------------------------------
// `prepararImagenParaOcr` usa canvas para recortar el marco guía y ampliar a 1000 px de ancho.
// Aquí se reproduce ese paso sobre los píxeles del PNG; el preprocesado en sí (grises,
// contraste, Otsu, suavizado) sale del módulo real vía `aplicarVariante`.
function escalarA(png, anchoDestino) {
  const escala = anchoDestino / png.width;
  const alto = Math.max(1, Math.round(png.height * escala));
  const salida = new PNG({ width: anchoDestino, height: alto });
  for (let y = 0; y < alto; y++) {
    for (let x = 0; x < anchoDestino; x++) {
      // Vecino más cercano: al ampliar, el resultado es prácticamente el mismo que el
      // bilineal del canvas para lo que aquí importa (el tamaño de los caracteres).
      const sx = Math.min(png.width - 1, Math.floor(x / escala));
      const sy = Math.min(png.height - 1, Math.floor(y / escala));
      const o = (png.width * sy + sx) << 2;
      const d = (anchoDestino * y + x) << 2;
      salida.data[d] = png.data[o];
      salida.data[d + 1] = png.data[o + 1];
      salida.data[d + 2] = png.data[o + 2];
      salida.data[d + 3] = 255;
    }
  }
  return salida;
}

function aDataUrl(png) {
  return 'data:image/png;base64,' + PNG.sync.write(png).toString('base64');
}

// ---------------------------------------------------------------------------
const indice = JSON.parse(await readFile(join(carpeta, 'indice.json'), 'utf8'));
const porCondicion = new Map();
for (const item of indice) {
  const lista = porCondicion.get(item.condicion) ?? [];
  if (!tope || lista.length < tope) lista.push(item);
  porCondicion.set(item.condicion, lista);
}

const worker = await createWorker('eng');
await worker.setParameters({
  tessedit_char_whitelist: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  tessedit_pageseg_mode: '7',
});

const resultados = [];
const totalImagenes = [...porCondicion.values()].reduce((s, l) => s + l.length, 0);
let hechas = 0;

for (const [condicion, items] of porCondicion) {
  for (const item of items) {
    const png = PNG.sync.read(await readFile(join(carpeta, item.archivo)));
    const ampliada = escalarA(png, 1000);

    const lecturas = [];
    for (const variante of VARIANTES_OCR) {
      // Cada variante parte de la misma imagen ampliada, no se encadenan.
      const copia = new PNG({ width: ampliada.width, height: ampliada.height });
      ampliada.data.copy(copia.data);
      aplicarVariante({ datos: copia.data, ancho: copia.width, alto: copia.height }, variante);

      const { data } = await worker.recognize(aDataUrl(copia));
      const texto = data.text ?? '';
      const extraida = extraerPlacaDeTexto(texto);
      lecturas.push({
        variante,
        placa: extraida,
        confianza: Math.max(0, Math.min(1, (data.confidence ?? 0) / 100)),
      });
    }

    const elegida = elegirPorConsenso(lecturas.filter((l) => l.placa).map((l) => l.placa));
    const correcta = elegida ? elegida.placa === item.placa : false;
    resultados.push({ condicion, esperada: item.placa, elegida, correcta, lecturas });

    hechas++;
    if (hechas % 10 === 0) process.stdout.write(`\r  ${hechas}/${totalImagenes}`);
  }
}
await worker.terminate();
console.log('');

// ---------------------------------------------------------------------------
// Informe
// ---------------------------------------------------------------------------
const pct = (n, d) => (d === 0 ? '—' : `${((n / d) * 100).toFixed(1)} %`);

console.log('\n=== ACIERTO POR CONDICIÓN ===');
console.log('  condición                    n    leída bien    leída mal    no se leyó');
for (const [condicion, items] of porCondicion) {
  const rs = resultados.filter((r) => r.condicion === condicion);
  const bien = rs.filter((r) => r.correcta).length;
  const mal = rs.filter((r) => r.elegida && !r.correcta).length;
  const nada = rs.filter((r) => !r.elegida).length;
  console.log(
    `  ${condicion.padEnd(24)} ${String(items.length).padStart(4)}` +
    `   ${pct(bien, rs.length).padStart(9)}` +
    `   ${pct(mal, rs.length).padStart(9)}` +
    `   ${pct(nada, rs.length).padStart(10)}`,
  );
}

console.log('\n=== QUÉ VARIANTE DE PREPROCESADO GANA ===');
console.log('  condición              ' + VARIANTES_OCR.map((v) => v.padStart(10)).join('   '));
for (const [condicion] of porCondicion) {
  const rs = resultados.filter((r) => r.condicion === condicion);
  const fila = VARIANTES_OCR.map((v) => {
    const aciertos = rs.filter((r) => {
      const l = r.lecturas.find((x) => x.variante === v);
      return l?.placa && corregirPlacaOcr(l.placa) === r.esperada;
    }).length;
    return pct(aciertos, rs.length).padStart(10);
  });
  console.log(`  ${condicion.padEnd(24)} ${fila.join('   ')}`);
}

// Confianza: ¿separa las lecturas buenas de las malas?
const conf = (filtro) => resultados.filter(filtro).map((r) => r.elegida.confianza);
const buenas = conf((r) => r.elegida && r.correcta);
const malas = conf((r) => r.elegida && !r.correcta);
const percentil = (xs, p) => {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.round((p / 100) * (s.length - 1)))];
};

console.log('\n=== CONFIANZA DE LA LECTURA ELEGIDA ===');
for (const [nombre, xs] of [['lecturas CORRECTAS', buenas], ['lecturas EQUIVOCADAS', malas]]) {
  if (!xs.length) { console.log(`  ${nombre.padEnd(22)} (ninguna)`); continue; }
  console.log(
    `  ${nombre.padEnd(22)} n=${String(xs.length).padStart(4)}  ` +
    `p5 ${percentil(xs, 5).toFixed(2)}  mediana ${percentil(xs, 50).toFixed(2)}  ` +
    `p95 ${percentil(xs, 95).toFixed(2)}`,
  );
}

console.log('\n=== EFECTO DE CADA UMBRAL DE CONFIANZA ===');
console.log('  umbral   se aceptan   de ellas equivocadas   correctas que se pierden');
for (let u = 0.5; u <= 0.95; u += 0.05) {
  const aceptadas = resultados.filter((r) => r.elegida && r.elegida.confianza >= u);
  const malasAceptadas = aceptadas.filter((r) => !r.correcta).length;
  const buenasPerdidas = resultados.filter((r) => r.correcta && r.elegida.confianza < u).length;
  const totalBuenas = resultados.filter((r) => r.correcta).length;
  console.log(
    `  ${u.toFixed(2).padStart(6)}   ${String(aceptadas.length).padStart(10)}` +
    `   ${pct(malasAceptadas, aceptadas.length).padStart(20)}` +
    `   ${pct(buenasPerdidas, totalBuenas).padStart(24)}`,
  );
}

console.log(`\n  Total: ${resultados.length} imágenes, ${resultados.filter((r) => r.correcta).length} leídas correctamente (${pct(resultados.filter((r) => r.correcta).length, resultados.length)}).`);
