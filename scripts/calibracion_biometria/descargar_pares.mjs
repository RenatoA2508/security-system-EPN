/**
 * Descarga una muestra de pares de LFW (Labeled Faces in the Wild) para calibrar el umbral
 * biométrico del sistema.
 *
 * Por qué LFW y por qué "pares": el protocolo estándar de LFW no es una lista de caras sueltas,
 * son parejas etiquetadas con "misma persona" o "personas distintas". Eso es exactamente lo que
 * hace falta y lo que el banco de la EPN no puede dar hoy: con una sola foto por persona se
 * puede medir cuánto se separan dos personas DISTINTAS, pero no cuánto varía la MISMA persona
 * entre dos fotos — y ese segundo número es el que fija el techo del umbral.
 *
 * Las imágenes se descargan a una carpeta temporal fuera del repositorio y se usan solo para
 * medir. NO se enrolan en `registro_biometrico` ni se suben a ningún sitio: son fotografías de
 * personas reales que no han consentido formar parte de un control de accesos.
 *
 * Uso:  node descargar_pares.mjs <carpeta-destino> [numero-de-pares]
 */

import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const API = 'https://datasets-server.huggingface.co/rows';
const DATASET = 'logasja/lfw';
const LOTE = 100; // el máximo que admite la API por petición

const destino = process.argv[2];
const objetivo = Number(process.argv[3] ?? 600);

if (!destino) {
  console.error('Uso: node descargar_pares.mjs <carpeta-destino> [numero-de-pares]');
  process.exit(1);
}

async function conReintento(url, intentos = 4) {
  for (let i = 0; i < intentos; i++) {
    try {
      const r = await fetch(url);
      if (r.ok) return r;
      // 429 y 5xx merecen otro intento; el resto no.
      if (r.status !== 429 && r.status < 500) throw new Error(`HTTP ${r.status}`);
    } catch (e) {
      if (i === intentos - 1) throw e;
    }
    await new Promise((r) => setTimeout(r, 1500 * (i + 1)));
  }
  throw new Error('agotados los reintentos');
}

await mkdir(destino, { recursive: true });

/** Cuántas filas tiene el split, para saber desde dónde muestrear cada clase. */
async function totalFilas() {
  const r = await conReintento(`https://datasets-server.huggingface.co/size?dataset=${encodeURIComponent(DATASET)}`);
  const d = await r.json();
  const split = (d.size?.splits ?? []).find((s) => s.config === 'pairs' && s.split === 'test');
  return split?.num_rows ?? 2200;
}

// El split NO está mezclado: primero vienen todos los pares de la misma persona y después
// todos los de personas distintas. Descargar los primeros N daría 600 positivos y ni un solo
// negativo — es decir, se podría medir cuánto varía una persona consigo misma y nada sobre
// cuánto se separan dos personas, que es justo la otra mitad del problema.
// Por eso se muestrea desde los dos extremos hasta llenar la cuota de cada clase.
const total = await totalFilas();
const cuota = Math.ceil(objetivo / 2);

const indice = [];
const contador = { pos: 0, neg: 0 };

async function muestrear(desdeOffset, hastaOffset, paso) {
  for (let offset = desdeOffset; paso > 0 ? offset < hastaOffset : offset >= hastaOffset; offset += paso * LOTE) {
    if (contador.pos >= cuota && contador.neg >= cuota) return;

    const url = `${API}?dataset=${encodeURIComponent(DATASET)}&config=pairs&split=test&offset=${Math.max(0, offset)}&length=${LOTE}`;
    const datos = await (await conReintento(url)).json();
    const filas = datos.rows ?? [];
    if (filas.length === 0) return;

    for (const fila of filas) {
      const { pair, img_0, img_1 } = fila.row;
      const misma = pair === 1;
      const clave = misma ? 'pos' : 'neg';
      if (contador[clave] >= cuota) continue;

      const n = String(contador[clave]).padStart(4, '0');
      const nombreA = `${clave}${n}_a.jpg`;
      const nombreB = `${clave}${n}_b.jpg`;

      const [a, b] = await Promise.all([conReintento(img_0.src), conReintento(img_1.src)]);
      await writeFile(join(destino, nombreA), Buffer.from(await a.arrayBuffer()));
      await writeFile(join(destino, nombreB), Buffer.from(await b.arrayBuffer()));

      indice.push({ a: nombreA, b: nombreB, mismaPersona: misma });
      contador[clave]++;
      process.stdout.write(`\r  misma persona: ${contador.pos}/${cuota}   personas distintas: ${contador.neg}/${cuota}`);
    }
  }
}

// Desde el principio salen los positivos; desde el final, los negativos.
await muestrear(0, total, 1);
await muestrear(total - LOTE, 0, -1);

await writeFile(join(destino, 'indice.json'), JSON.stringify(indice, null, 2));
console.log(`\n  ${indice.length} pares: ${contador.pos} de la misma persona, ${contador.neg} de personas distintas`);
