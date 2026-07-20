# PR — Ronda de CAC (Control de Accesos)

> Texto listo para pegar al abrir el pull request de `feat/cac-mejoras` → `main`.
> **Ojo al orden:** esta rama sale de `feat/pco-mejoras`. Hay que fusionar primero la de PCO.

---

## Qué trae

Aplica el documento `Requerimientos_CAC.docx` completo (RF-CA-001 a 025 y RNF-CA-001 a 005) y
añade la **segunda vía de autenticación** que pedía la sesión: reconocimiento de placas
vehiculares, además del facial que ya existía.

## Los cinco fallos que se encontraron por el camino

Ninguno era visible desde la interfaz. Salieron al ejercitar el flujo contra la base real.

**1. La validación de acceso no sabía por qué denegaba.** Resolvía categoría, garita y horario en
una sola consulta: cuando no encontraba regla, no podía distinguir cuál de las tres condiciones
había fallado y lo reportaba todo como `FUERA_DE_HORARIO`.

Eso escondía el fallo de verdad: **seis docentes y seis administrativos no tenían ninguna regla
de acceso activa y no podían entrar al campus.** Con el mensaje antiguo el síntoma era "fuera de
horario" a cualquier hora del día, y se leía como un problema de horarios.

**2. `requiere_memorando` era decorativo para el personal interno.** La comprobación solo corría
en la rama de personas externas. Una regla que declaraba exigir memorando dejaba pasar a
cualquier interno sin mirar si lo tenía — que es literalmente lo que RF-CA-001 prohíbe.

**3. El estado de la persona solo se comprobaba a los internos.** Una persona externa
**bloqueada** entraba si su memorando seguía vigente (RF-CA-008 no distingue ámbitos).

**4. Los horarios nocturnos no casaban nunca.** Una regla de 22:00 a 06:00 fallaba a las 23:00
(`hora <= 06:00`) y a las 02:00 (`22:00 <= hora`). Mismo error de medianoche que ya apareció en
los turnos del guardia (§D59).

**5. Registrar a una persona desconocida era imposible.** `evento_acceso.id_persona` era NOT NULL
y la función devolvía 404 sin escribir nada: el caso que más interesa registrar (RF-CA-021) era
el único que no dejaba rastro.

## Reconocimiento de placas

Motor híbrido: **Plate Recognizer** cuando hay token configurado, **Tesseract.js** en el propio
navegador cuando no. El sistema funciona en los dos casos y el guardia siempre puede teclear la
placa a mano.

Lo que hace que acierte con placas reales no es el motor, son tres detalles:

- **Captura a 1280×720 con la cámara trasera.** El panel de rostro captura a 320×240, que para
  una cara basta y para una matrícula no: a esa resolución los caracteres no llegan a diez
  píxeles.
- **Recorte guiado.** El marco que se dibuja sobre el vídeo delimita exactamente la región que se
  lee. Todo lo demás (capó, calle, otros coches) es ruido.
- **Corrección de erratas por posición.** La placa ecuatoriana tiene forma fija: tres letras y
  tres o cuatro dígitos. Un dígito en la zona de letras es necesariamente un error de lectura, y
  al revés. Se corrige sin consultar la base, y **no puede convertir una placa en otra placa
  válida distinta** porque solo toca caracteres que estaban en la clase equivocada.

La tolerancia difusa (`levenshtein`) se aplica después y es deliberadamente cobarde: **solo si
una única placa registrada queda a esa distancia**. Con dos candidatas no elige ninguna. Escoger
"la más parecida" entre dos sería autorizar un vehículo por parecido.

## Umbrales, medidos

Los dos reconocimientos se calibraron con datos, no a ojo. Las herramientas quedan en
`scripts/calibracion_biometria` y `scripts/calibracion_placas`, y usan el mismo modelo y el
mismo detector que la garita.

**Rostro** — 1200 pares de LFW (862 útiles), con su protocolo de parejas etiquetadas:

| Confianza | FAR (entra quien no es) | FRR (se rechaza a quien sí es) |
|---|---|---|
| **0.45** ← vigente | **0.00 %** | 11.0 % |
| 0.40 | 0.72 % | 4.5 % |
| 0.35 ← suelo de revisión | 2.9 % | 4.0 % |

A 0.45 no se cuela ninguno de los 416 impostores medidos. El 11 % de legítimos que se rechazan
no se pierde: cae en la banda de revisión, donde el guardia confirma.

**Placa** — 200 imágenes con la placa correcta conocida. Aquí apareció un fallo de bulto: la
confianza que se guardaba era **siempre 0**, porque tesseract.js 5 devuelve `confidence` a cero
en todos los niveles. `UMBRAL_PLACA` no filtraba absolutamente nada. Se sustituye por el
**acuerdo entre variantes de preprocesado**, que sí discrimina (correctas mediana 1.00,
equivocadas 0.63), con corte en 0.75 → 1.2 % de error entre las aceptadas.

Y el preprocesado de un solo paso era el cuello de botella: la binarización de Otsu es lo mejor
con una placa metálica y de lo peor con una foto de pantalla. Con la variante suavizada, el
acierto sobre placa real en malas condiciones pasa de **12.5 % a 60 %**.

## Seguridad

`identificar_placa` quedó ejecutable por el rol `anon`, es decir, **sin iniciar sesión**.
Cualquiera con la clave publicable podía ir probando placas y quedarse con las que devolvían
fila: enumerar qué vehículos entran a la EPN, sin cuenta y sin dejar rastro. Cerrada, junto con
otras tres funciones de la ronda y `rls_auto_enable` (que ya venía así de antes).

## Cambios de esquema

| Cambio | Motivo |
|---|---|
| `evento_acceso.id_persona` → nullable | RF-CA-021, con CHECK que lo ata a su único caso |
| `evento_acceso`: `tipo_acceso`, `placa_detectada`, confianzas, `id_evento_ingreso` | RF-CA-013/020/024/025 |
| `regla_acceso_punto_control` (N:M) | RF-CA-007: "garitas" en plural |
| `error_reconocimiento` | RF-CA-022 |
| Índice único de propietario | RF-CA-018: nada impedía dos propietarios activos |
| 5 reglas de acceso nuevas | Las categorías que no tenían ninguna |

**Semántica que conviene tener presente:** una regla **sin garitas asociadas aplica en TODAS**.
Cero filas no es "no vale en ninguna parte", es lo contrario — por eso la pantalla dice "Todas
las garitas" y no un guion.

## Verificación

- **179 pruebas locales** en verde (36 nuevas: motor de placas, navegación de la garita,
  pantallas de CAC, persistencia de formularios).
- **TestSprite contra el preview: los 6 planes en verde** (100/100 pasos entre todos).
  TestSprite encontró además
  un fallo que las pruebas locales no veían: al teclear `PDFI234` en el campo manual, la
  validación de formato lo rechazaba antes de que el corrector actuara, cuando el sistema sabía
  de sobra que eso era `PDF1234`. Corregido.
- **Flujo completo ejercitado contra la base real**: ingreso peatonal, vehicular, doble
  autenticación, pasajeros, salida ligada al ingreso, persona desconocida, placa no registrada.

## Lo que NO se hizo, a propósito

- **Los dos vehículos sin propietario no se rellenaron** (§V31): no hay forma de saber de quién
  son. Quedan expuestos en `vista_vehiculo_sin_propietario`.
- **No se cambió el detector facial.** `TinyFaceDetector` no encontró rostro en el 28 % de las
  fotos de LFW, que son de prensa y están bien iluminadas; en una garita fallará más. Cambiarlo
  a `SsdMobilenetv1` invalidaría la calibración, así que queda medido y anotado en §V32 en vez
  de cambiado a ciegas.
- **Que falte el propietario no bloquea el ingreso.** Lo que decide un acceso es que la persona
  esté asociada al vehículo (RF-CA-015); que el vehículo tenga propietario es integridad del
  maestro (RF-CA-018). Denegarle el paso a un conductor legítimo por un hueco administrativo
  sería castigarle por algo que no le corresponde.
- **Los horarios de las cinco reglas nuevas son plausibles pero no acordados** (§V34). Que los
  revise el equipo: son los horarios que deciden quién entra al campus.

## Ojo: producción muestra un dato incorrecto hasta que esto se fusione

Las migraciones ya están aplicadas en la base (van por MCP, no por el PR), así que **el esquema
va por delante del frontend desplegado**. No rompe nada, pero al retirarse
`regla_acceso.id_punto_control`, PostgREST resuelve el embed antiguo a través de la tabla nueva
y devuelve un array donde el bundle viejo espera un objeto: la columna "Punto" de Reglas de
acceso dice **"Todos"** en todas las filas, que es lo contrario de la verdad para las reglas que
sí tienen garita. Se arregla solo al fusionar.

## Antes de fusionar

1. Fusionar primero `feat/pco-mejoras`.
2. Volver a activar **Vercel Authentication** en Deployment Protection (sigue desactivado para
   que TestSprite pueda entrar).
3. Opcional: configurar `PLATE_RECOGNIZER_TOKEN` en los secrets de Supabase para activar el
   lector en la nube.

Detalle completo en `docs/03_DECISIONES_Y_CORRECCIONES.md` §D62–D69 y
`docs/99_DUDAS_PARA_EL_EQUIPO.md` §V31–V36. Guía de la prueba con placas reales en
`docs/New_Req/GUIA_PRUEBAS_PLACAS.md`.
