# Plan de la sesión final — prototipo 3 del sistema completo

Esta sesión no añade módulos: **cierra el sistema**. El objetivo es que el prototipo 3 se
comporte como se comportaría en la Politécnica de verdad, y que lo que no funcione esté
identificado y decidido, no descubierto por sorpresa en la defensa.

Cinco rondas cerradas (validaciones, ADM, GPE+GPI, PCO, CAC) y cada una verificó lo suyo. Lo que
**nunca** se ha probado es el sistema entero de punta a punta, y ahí es donde han aparecido los
peores fallos de este proyecto: un cambio en PCO dejó sin nombre al guardia en CAC, y una política
de CAC más estrecha que la de su tabla padre vació un embed sin dar ningún error.

---

## 1. Qué hacer, en orden

### Paso 1 — Fotografía del estado (30 min)

Antes de tocar nada, dejar por escrito de dónde se parte:

```bash
cd web && npm run verificar                       # typecheck + suite + build
python3 scripts/verificar_numeracion_docs.py      # numeración de decisiones y dudas
```

Y por MCP: `get_advisors` de seguridad y de rendimiento. Son cinco rondas de migraciones sin una
revisión conjunta.

### Paso 2 — La batería de integración con TestSprite

Están **escritos y listos** en `tests/testsprite/planes/integracion/`, trece recorridos que siguen
la vida real del sistema:

| Plan | Qué recorre | Cuenta |
|---|---|---|
| INT-01 | Una persona interna es la misma en GPI y en ADM, identificada por cédula | GPI → ADM |
| INT-02 | Un externo con memorando: la vigencia manda sobre el permiso | GPE |
| INT-03 | Visita de un día sin memorando | GPE |
| INT-04 | Zona → punto de control → dispositivo → guardia asignado | PCO |
| INT-05 | Una regla de CAC se apoya en los puntos de control de PCO | CAC |
| INT-06 | La garita permite el ingreso y lo deja registrado | Guardia |
| INT-07 | Un ingreso denegado dice **por qué** | CAC |
| INT-08 | Un vehículo tiene dueño y se sabe quién lo conduce | ADM |
| INT-09 | Trazabilidad: auditoría y sesiones legibles, sin secretos | ADM |
| INT-10 | Cada rol ve exactamente su módulo y ninguno más | PCO → GPE → ADM |
| INT-11 | Fallos de cámara y de placas registrados y entendibles | CAC |
| INT-12 | La misma persona no está dos veces; biometría sin exponer el rostro | ADM |
| INT-13 | El panel de Monitoreo reúne lo que está pasando ahora | CAC |

Crearlos y ejecutarlos:

```bash
for p in tests/testsprite/planes/integracion/*.json; do
  testsprite test create --plan-from "$p"
done
testsprite test run <testId> --target-url <preview> --wait --timeout 1800
```

> **Máximo dos o tres a la vez, y siempre con cuentas distintas.** Está medido: doce pruebas en
> paralelo con la misma cuenta dieron cinco fallos con síntoma de "faltan permisos", y la misma
> prueba pasó 15/15 al ejecutarla sola. Y no consultes la API con esa cuenta mientras corren.

### Paso 3 — Lo que TestSprite no puede ver

La batería anterior recorre la interfaz. Estas comprobaciones son de la base y hay que lanzarlas
aparte:

```bash
psql "$DATABASE_URL" -f scripts/smoke_test.sql
psql "$DATABASE_URL" -f scripts/pruebas_rls_por_rol.sql        # cada rol ve lo suyo y nada más
psql "$DATABASE_URL" -f scripts/pruebas_cobertura_docs.sql     # el esquema concuerda con los documentos
psql "$DATABASE_URL" -f scripts/pruebas_adm_cuentas.sql
psql "$DATABASE_URL" -f scripts/pruebas_gpe_gpi_nuevas.sql
psql "$DATABASE_URL" -f scripts/pruebas_validaciones_nuevas.sql
python3 scripts/prueba_multisesion.py                          # requiere SB_URL, SB_ANON, SB_PASSWORD
```

### Paso 4 — Cerrar las decisiones pendientes

Están en la sección 3 de este documento, con opciones concretas. Casi todas necesitan un dato que
solo tiene el equipo; ninguna necesita programar mucho.

### Paso 5 — El repaso de "vida real"

Con el sistema entero delante, mirar lo que ninguna prueba automática detecta y sí nota un tribunal:

- **Datos de demostración creíbles.** Quedan **18 cédulas ficticias** (§V11) y vehículos sin
  propietario (§V31). Un prototipo con datos absurdos parece a medio hacer aunque funcione.
- **Coherencia de vocabulario** entre módulos: que "garita", "punto de control" y "acceso" no se
  usen indistintamente si significan cosas distintas.
- **Los caminos sin salida**: qué ve el usuario cuando algo está vacío, cuando no tiene permiso y
  cuando algo falla. Ya se corrigió el caso de la lista filtrada (§D61); conviene repasar el resto.
- **El recorrido del guardia**, que es el único que usa el sistema con prisa y de pie.

---

## 2. Cuándo está listo el prototipo 3

Criterios de aceptación. No vale "casi":

1. **Los trece planes de integración en verde**, ejecutados contra el preview de la rama final.
2. **La suite local en verde** (200 pruebas a día de hoy) más typecheck y build.
3. **Los scripts SQL de la sección 3 sin fallos.**
4. **`get_advisors` sin avisos nuevos** de seguridad respecto a los ya conocidos.
5. **Ninguna duda abierta sin decidir o sin fecha**: o se resuelve, o se anota por qué se deja.
6. **Un recorrido manual completo**: dar de alta a una persona, autorizarla, crear su regla,
   asignarle un guardia a la garita y hacerla entrar. Si ese camino se puede recorrer entero sin
   tocar la base a mano, el prototipo está listo.
7. **La protección de previews de Vercel, reactivada** (ver sección 4).

---

### Fotografía de los datos al cerrar la ronda de PCO v2

Consultado contra la base el 20/07/2026. Sirve para saber, en la sesión final, si algo cambió:

| Comprobación | Valor | Dónde se decide |
|---|---|---|
| Cédulas ficticias (`175000…`) | **18** | §V11 |
| Vehículos sin propietario | **2** | §V31 |
| Empresas con el RUC sin verificar | **4** | §V12 |
| Puntos de control en MANTENIMIENTO | **1** | §V29 |
| Asignaciones activas sin fecha de fin | **1** | §V42 |
| Puntos en edificios sin el código EPN | **2** | §V41 |
| Parqueaderos colgando del campus | **1** | §V24 |

Cada número de esta tabla es una decisión de la sección siguiente. Si al empezar la sesión final
alguno ha bajado a cero, esa decisión ya está tomada.

## 3. Decisiones que el equipo tiene que tomar

Ninguna necesita programar más de un rato; todas necesitan un dato o un criterio que el sistema no
puede inventarse. **Están ordenadas por lo que cuesta si no se deciden.**

### Bloquean el "funciona como en la vida real"

| # | Decisión | Qué hace falta |
|---|---|---|
| **§V41** | Dos puntos de control en edificios no siguen el estándar `E<edificio>/P<piso>/E<espacio>`: `Puerta - Laboratorio "Alan Turing"` (Edificio 20) y `Puerta - Laboratorio de Suelos` (Edificio 15) | En qué piso y aula están. El documento del v2 sugiere `E20/P4/E004` para el Alan Turing, pero es un ejemplo dentro de un texto, no un dato confirmado, y renombrar un punto cambia lo que ve el guardia. |
| **§V42** | Una asignación de guardia **activa sin fecha de fin** (`46a99012`, guardia.demo, 12:00–23:59:59) | Hasta cuándo dura. Es la única incompleta del sistema. |
| **§V24** | El "Parqueadero Subsuelo EARME" cuelga del campus, y la jerarquía exige que un parqueadero cuelgue de un edificio | O se crea el edificio EARME y se reasigna, o se acepta que un parqueadero pueda colgar del campus y se relaja el trigger. |
| **§V29** | El guardia de demostración no puede operar porque su punto está en MANTENIMIENTO | Si el mantenimiento es intencional, hay que asignarle otro punto para poder demostrar la garita. **El comportamiento del sistema es el correcto**, no hay que tocarlo. |
| **§V11** | 18 cédulas ficticias | Sustituirlas por cédulas válidas y coherentes, o asumirlas explícitamente como datos de demostración. |
| **§V31** | Dos vehículos sembrados sin propietario | A quién pertenecen. |

### No bloquean, pero conviene decidir antes de la defensa

| # | Decisión | Nota |
|---|---|---|
| **§V28** | La búsqueda "solo con 10 dígitos de cédula o por apellido" no se implementó | Vive en ADM y GPI, no en PCO. Afecta a pantallas ya validadas en otras rondas. |
| **§V30** | El descanso entre jornadas no se comprueba con turnos nocturnos combinados | Hoy no afecta a nadie. Si se usan turnos rotativos con nocturnos, hay que modelar el día laboral con fecha **y** hora, no solo horas. |
| **§V12** | `estado_verificacion_ruc` siempre `NO_VERIFICADO` | No hay integración con el SRI y no la va a haber en el prototipo. Conviene decir en pantalla que no está verificado en vez de dejarlo mudo. |
| **§V33** | El lector de placas en la nube depende de un tercero | Decidir si el prototipo se defiende con el lector local. |
| **§V13** | Bloqueo por intentos fallidos: hueco residual del plan gratuito | Cerrarlo del todo exige Auth Hook (de pago) o hCaptcha. |

---

## 4. Lo que hay que hacer sí o sí antes de cerrar

**Reactivar la protección de previews en Vercel.** Panel → `security-system-epn` → Settings →
Deployment Protection → **Vercel Authentication → Enabled**. Está desactivada desde el 19/07 para
que TestSprite pudiera entrar a los previews; mientras siga así, **cualquiera con la URL de un
preview entra a la aplicación completa contra la base real, sin autenticarse**.

Es lo único pendiente con consecuencias fuera del repositorio. Déjalo para el final de la sesión,
porque mientras TestSprite trabaje hace falta que siga abierta.

---

## 5. Cómo NO perder tiempo

Lo aprendido en cinco rondas, en cuatro líneas:

- **Ante un campo vacío o un "—", mira la política de RLS antes que el componente.** Un embed
  bloqueado por RLS se ve exactamente igual que un dato que no existe, y **no da error** (§D58).
- **Ante un fallo de TestSprite, relanza esa prueba sola antes de tocar código.** Cinco de los
  fallos de la última ronda eran interferencia entre navegadores, no bugs.
- **Cada vez que compares o muestres una fecha, pregúntate si es un instante o un día.** El error
  de medianoche ha aparecido **cuatro** veces (§D52, §D59, §D69, §D81).
- **Primero SQL, después el espejo en el frontend.** La base es la que manda; la pantalla solo
  adelanta el error.
