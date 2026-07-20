/**
 * Calibración del umbral biométrico del Sistema de Seguridad EPN.
 *
 * Calcula el descriptor facial de cada foto con EL MISMO modelo que usa el sistema
 * (face-api.js, 128 dimensiones), mide la distancia L2 dentro de cada par y responde a la
 * pregunta que decide el umbral:
 *
 *   ¿a qué distancia está la misma persona de sí misma, y a qué distancia están dos personas
 *   distintas?
 *
 * Con el banco de la EPN solo se podía medir lo segundo (una foto por persona), y por eso el
 * umbral anterior se fijó "a ojo" con el margen que quedaba. Aquí se miden las dos
 * distribuciones y el umbral sale de ellas.
 *
 * El sistema trabaja en CONFIANZA, no en distancia: `confianza = max(0, 1 - distancia_L2)`
 * (ver `public.identificar_por_descriptor`). Todo se reporta en las dos escalas.
 *
 * Métricas que se usan para decidir:
 *   - FAR (False Accept Rate): proporción de pares de personas DISTINTAS que el umbral
 *     aceptaría. Es el error grave: dejar entrar a quien no es.
 *   - FRR (False Reject Rate): proporción de pares de la MISMA persona que el umbral
 *     rechazaría. Es el error molesto: el guardia repite la captura o teclea la cédula.
 *
 * No toca la base de datos ni enrola a nadie. Es una herramienta de medición.
 *
 * Uso:  node calibrar.mjs <carpeta-con-pares>
 */

import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import jpeg from 'jpeg-js';
import * as tf from '@tensorflow/tfjs';
import * as faceapi from '@vladmandic/face-api/dist/face-api.node-wasm.js';

const carpeta = process.argv[2];
if (!carpeta) {
  console.error('Uso: node calibrar.mjs <carpeta-con-pares>');
  process.exit(1);
}

// Los pesos se cargan del paquete instalado en el frontend, que son exactamente los mismos
// que descarga el navegador: calibrar con otro modelo daría un número que no aplica.
const RUTA_MODELOS = new URL('./modelos', import.meta.url).pathname;

await faceapi.tf.setBackend('cpu');
await faceapi.tf.ready();

console.log('Cargando modelos...');
// TinyFaceDetector, el mismo que usa `web/src/lib/faceapi.ts` en la garita. Calibrar con otro
// detector daría un número que no aplica: el recorte que hace cada uno es distinto y el
// descriptor sale del recorte.
await faceapi.nets.tinyFaceDetector.loadFromDisk(RUTA_MODELOS);
await faceapi.nets.faceLandmark68Net.loadFromDisk(RUTA_MODELOS);
await faceapi.nets.faceRecognitionNet.loadFromDisk(RUTA_MODELOS);

/** Convierte un JPEG en el tensor que espera face-api, sin dependencias nativas. */
async function tensorDesdeJpeg(ruta) {
  const crudo = await readFile(ruta);
  const { data, width, height } = jpeg.decode(crudo, { useTArray: true });
  // jpeg-js devuelve RGBA; el modelo espera RGB.
  const rgb = new Uint8Array((data.length / 4) * 3);
  for (let i = 0, j = 0; i < data.length; i += 4, j += 3) {
    rgb[j] = data[i];
    rgb[j + 1] = data[i + 1];
    rgb[j + 2] = data[i + 2];
  }
  return tf.tensor3d(rgb, [height, width, 3]);
}

const descriptores = new Map();

async function descriptorDe(nombre) {
  if (descriptores.has(nombre)) return descriptores.get(nombre);
  const tensor = await tensorDesdeJpeg(join(carpeta, nombre));
  try {
    const deteccion = await faceapi
      .detectSingleFace(tensor, new faceapi.TinyFaceDetectorOptions())
      .withFaceLandmarks()
      .withFaceDescriptor();
    const valor = deteccion ? deteccion.descriptor : null;
    descriptores.set(nombre, valor);
    return valor;
  } finally {
    tensor.dispose();
  }
}

const distanciaL2 = (a, b) => {
  let suma = 0;
  for (let i = 0; i < a.length; i++) suma += (a[i] - b[i]) ** 2;
  return Math.sqrt(suma);
};

// ---------------------------------------------------------------------------
// Medición
// ---------------------------------------------------------------------------
const indice = JSON.parse(await readFile(join(carpeta, 'indice.json'), 'utf8'));
console.log(`Midiendo ${indice.length} pares...`);

const mismas = [];
const distintas = [];
let sinRostro = 0;

for (const [i, par] of indice.entries()) {
  const [a, b] = await Promise.all([descriptorDe(par.a), descriptorDe(par.b)]);
  if (!a || !b) {
    sinRostro++;
  } else {
    const d = distanciaL2(a, b);
    (par.mismaPersona ? mismas : distintas).push(d);
  }
  if ((i + 1) % 25 === 0) process.stdout.write(`\r  ${i + 1}/${indice.length}`);
}
console.log('');

// ---------------------------------------------------------------------------
// Estadística
// ---------------------------------------------------------------------------
const percentil = (xs, p) => {
  const s = [...xs].sort((x, y) => x - y);
  return s[Math.min(s.length - 1, Math.max(0, Math.round((p / 100) * (s.length - 1))))];
};
const media = (xs) => xs.reduce((s, x) => s + x, 0) / xs.length;

const resumen = (nombre, xs) => {
  console.log(
    `  ${nombre.padEnd(22)} n=${String(xs.length).padStart(4)}  ` +
    `min ${percentil(xs, 0).toFixed(3)}  p5 ${percentil(xs, 5).toFixed(3)}  ` +
    `mediana ${percentil(xs, 50).toFixed(3)}  p95 ${percentil(xs, 95).toFixed(3)}  ` +
    `max ${percentil(xs, 100).toFixed(3)}  media ${media(xs).toFixed(3)}`,
  );
};

console.log('\n=== DISTANCIA L2 ENTRE LOS DOS ROSTROS DEL PAR ===');
resumen('MISMA persona', mismas);
resumen('personas DISTINTAS', distintas);
if (sinRostro) console.log(`  (${sinRostro} pares descartados: no se detectó rostro en alguna de las dos fotos)`);

// Barrido de umbrales: para cada distancia de corte, cuántos errores de cada tipo se cometen.
console.log('\n=== QUÉ PASA CON CADA UMBRAL ===');
console.log('  confianza  distancia   FAR (deja entrar a quien no es)   FRR (rechaza a quien sí es)');

const candidatos = [];
for (let corte = 0.30; corte <= 0.90; corte += 0.01) {
  const far = distintas.filter((d) => d <= corte).length / distintas.length;
  const frr = mismas.filter((d) => d > corte).length / mismas.length;
  candidatos.push({ corte, far, frr, confianza: 1 - corte });
}

for (const c of candidatos) {
  const marca = Math.abs(c.confianza - 0.45) < 0.005 ? '  <- umbral actual' : '';
  if (Math.abs(c.corte * 100 - Math.round(c.corte * 100)) < 1e-6 && Math.round(c.corte * 100) % 5 === 0) {
    console.log(
      `  ${c.confianza.toFixed(2).padStart(8)}   ${c.corte.toFixed(2).padStart(8)}   ` +
      `${(c.far * 100).toFixed(2).padStart(8)} %                    ` +
      `${(c.frr * 100).toFixed(2).padStart(8)} %${marca}`,
    );
  }
}

// El punto donde los dos errores se igualan (EER) es la referencia estándar para comparar
// sistemas, pero NO es el umbral que conviene a un control de acceso físico: ahí un impostor
// entra con la misma probabilidad con la que se rechaza a alguien legítimo, y las dos cosas no
// cuestan lo mismo.
const eer = candidatos.reduce((mejor, c) =>
  Math.abs(c.far - c.frr) < Math.abs(mejor.far - mejor.frr) ? c : mejor,
);

// Lo que se busca aquí: el umbral más permisivo que mantiene el FAR por debajo del objetivo.
// Cuanto más permisivo, menos veces tiene que repetir la captura una persona legítima.
const objetivos = [0.001, 0.005, 0.01];
console.log('\n=== UMBRALES RECOMENDADOS ===');
console.log(`  Punto de igual error (EER):  confianza ${eer.confianza.toFixed(3)} / distancia ${eer.corte.toFixed(3)} — FAR = FRR = ${(eer.far * 100).toFixed(2)} %`);
for (const objetivo of objetivos) {
  const validos = candidatos.filter((c) => c.far <= objetivo);
  const elegido = validos.length ? validos[validos.length - 1] : null;
  if (elegido) {
    console.log(
      `  FAR <= ${(objetivo * 100).toFixed(1)} %:  confianza ${elegido.confianza.toFixed(3)} / distancia ${elegido.corte.toFixed(3)} ` +
      `— rechazaría al ${(elegido.frr * 100).toFixed(1)} % de los intentos legítimos`,
    );
  } else {
    console.log(`  FAR <= ${(objetivo * 100).toFixed(1)} %:  no se alcanza en el rango medido`);
  }
}

// Solapamiento: si la peor foto de la misma persona está más lejos que el par de personas
// distintas más parecido, no existe ningún umbral que separe perfectamente. Es lo normal, y
// dice cuánta zona gris hay que dejar para que la decida un humano.
const peorMisma = percentil(mismas, 100);
const mejorDistinta = percentil(distintas, 0);
console.log('\n=== ZONA GRIS ===');
console.log(`  Par de la misma persona más lejano:      distancia ${peorMisma.toFixed(3)} (confianza ${(1 - peorMisma).toFixed(3)})`);
console.log(`  Par de personas distintas más parecido:  distancia ${mejorDistinta.toFixed(3)} (confianza ${(1 - mejorDistinta).toFixed(3)})`);
console.log(
  mejorDistinta < peorMisma
    ? `  Las dos distribuciones SE SOLAPAN entre ${mejorDistinta.toFixed(3)} y ${peorMisma.toFixed(3)}: ningún umbral las separa del todo,\n  y por eso el sistema tiene una banda de revisión en la que decide el guardia.`
    : '  No hay solapamiento en esta muestra.',
);
