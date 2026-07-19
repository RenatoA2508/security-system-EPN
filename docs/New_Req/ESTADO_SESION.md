# Estado del sistema — punto de partida para la sesión de CAC

La ronda de PCO está cerrada y verificada. Sustituye al documento de la ronda de GPE + GPI.

---

## ⚠️ Tres cosas que hacer ANTES de empezar

**1. Fusionar el PR de PCO.**
Rama `feat/pco-mejoras`. Mientras no se fusione, `main` y producción NO tienen los cambios de
esta ronda, pero **la base de datos SÍ** (las migraciones se aplican por MCP, no por el PR). Es
la única ventana en la que el esquema va por delante del frontend desplegado: en producción el
catálogo de estados de zona ya no admite `BLOQUEADA` aunque el bundle antiguo aún lo ofrezca.

**2. Volver a proteger los previews.**
Panel de Vercel → proyecto `security-system-epn` → **Settings → Deployment Protection** →
**Vercel Authentication** → **Enabled**. Sigue desactivado desde el 19/07 para que TestSprite
pueda entrar; mientras siga así, cualquier URL de preview es accesible para quien la tenga.

**3. La cuenta `guardia.demo@epn.edu.ec` NO usa `admin1234`.**
Tiene una contraseña propia, que **no se escribe aquí a propósito**: este documento está en un
repositorio. Pídesela a Sebastián o resetéala desde el panel de Supabase Auth. Verificada el
19/07: la cuenta entra bien con ella.

Y ojo al montar pruebas de la Garita: aunque el login funcione, **ese guardia no puede operar**,
porque su punto ("Puerta - Laboratorio de Suelos") está en MANTENIMIENTO y `esta_en_turno_guardia()`
exige que el punto esté ACTIVO. Es el comportamiento correcto (§D60), no un fallo: si necesitas
probar la Garita, reasigna ese guardia a un punto activo desde PCO.

---

## Dónde está todo

| Qué | Dónde |
|---|---|
| Producción | https://security-system-epn.vercel.app (rama `main`) |
| Decisiones | `docs/03_DECISIONES_Y_CORRECCIONES.md` — §D53-D61 son de la ronda de PCO |
| Dudas y pendientes | `docs/99_DUDAS_PARA_EL_EQUIPO.md` — §V24-V30 son de la ronda de PCO |
| Despliegue | `docs/DESPLIEGUE.md` |
| Revisión manual de GPE/GPI | `docs/New_Req/GUIA_REVISION_GPE_GPI.md` |
| Feedback de PCO | `docs/New_Req/Requerimientos_PCO.docx` |

## Cómo trabajar esta sesión (lo que funcionó en la anterior)

```bash
git checkout main && git pull
git checkout -b feat/pco-mejoras
```

1. **Las migraciones van por MCP**, una a una con `apply_migration`, y **después** se guarda el
   archivo en `supabase/migrations/` con el `version_name` que devuelve `list_migrations`.
   `supabase db push` sigue sin funcionar (§5 de pendientes).
2. **Un commit por grupo lógico.** No un commit gigante.
3. **Verificar antes de dar nada por hecho:**
   ```bash
   cd web && npm run verificar     # typecheck + 142 pruebas + build
   ```
4. **Push a la rama** → Vercel genera un preview automáticamente. Ya funciona (se arregló en la
   ronda anterior); antes había que desplegar a mano.

## TestSprite: lee esto antes de crear una sola prueba

Aquí se perdió más tiempo en la ronda anterior. Tres cosas que ya están resueltas y no hay que
volver a descubrir:

**1. La credencial del proyecto pisa la del plan.** TestSprite inyecta
`admin@epn.edu.ec` en el formulario de login, ignorando el correo que pida el plan. Y esa cuenta
es `ADMINISTRADOR_SISTEMA`: **solo ve el módulo Administración**. Para que un plan entre a PCO,
el primer paso tiene que decirlo de forma explícita:

> "Abrir la aplicación. En la pantalla de inicio de sesión, BORRAR cualquier valor que venga
> precargado en el campo de correo y escribir exactamente `heidy.tenelema@epn.edu.ec`; en el
> campo de contraseña escribir `admin1234`. Es imprescindible usar esa cuenta y no otra: es la
> única con acceso al módulo Puntos de Control. Después pulsar 'Ingresar al sistema'."

Y justo después, una aserción de que la sesión es la correcta y el módulo se ve.

**Qué cuenta usar según el módulo** (todas con contraseña `admin1234`):

| Módulo | Cuenta | Rol |
|---|---|---|
| **PCO** | `heidy.tenelema@epn.edu.ec` | Responsable de Puntos de Control |
| ADM | `admin@epn.edu.ec` | Administrador del Sistema |
| GPI | `lenin.amangandi@epn.edu.ec` | Responsable de Personal Interno |
| GPE | `joel.velastegui@epn.edu.ec` | Responsable de Personal Externo |
| CAC | `carlos.chavez03@epn.edu.ec` | Responsable de Control de Accesos |
| Garita | `guardia.demo@epn.edu.ec` | Guardia (además ve GPI) |

**2. Una aserción negativa sola no prueba nada.** Tres pruebas dieron "passed" sin comprobar
nada: decían "no aparece la tarjeta X" y se cumplían solas porque el usuario no veía el módulo.
**Toda negativa debe ir precedida de una positiva sobre la misma pantalla** ("existe la tarjeta
Dispositivos" *y luego* "no existe la tarjeta Y").

**3. Las variables de entorno de Preview ya están configuradas.** `VITE_SUPABASE_URL` y
`VITE_SUPABASE_ANON_KEY` existían solo para `production`, y los previews arrancaban en blanco.
Ya están en ambos entornos; no hay que volver a tocarlo.

```bash
testsprite test create --plan-from tests/testsprite/planes/NN_nombre.json
testsprite test run <testId> --target-url <url-del-preview> --wait --timeout 1500
```

Se pueden lanzar **en paralelo** (`&` y `wait`): 10 pruebas tardan ~15 min en vez de dos horas.
Cada una tarda entre 5 y 15 minutos.

## Qué se hizo en la ronda de PCO

Todo el feedback del documento está aplicado. Lo que conviene saber para no repetir el análisis:

- **Estados simplificados** (§D53, §D54): zona queda ACTIVA/INACTIVA, punto de control pierde
  FALLA. El combo de Estado desapareció de todos los formularios de **alta** y se añadió el
  botón **Reactivar** (§D56).
- **Jerarquía de zonas** (§D55): CAMPUS → EDIFICIO → PARQUEADERO, en trigger y en el combo.
- **Turno estructurado** (§D57): `hora_inicio`/`hora_fin` son la fuente de verdad y el texto
  `turno` se deriva de ellas. `esta_en_turno_guardia()` (req 34) usa ya las columnas.
- **Jornada del guardia** (§D59): máximo 12 h por turno, aviso entre 8 y 12 (horas extra) y 12 h
  de descanso entre jornadas. Los límites viven en `parametro_sistema`, no en el código.
- **Dos bugs que parecían de pantalla y eran de RLS** (§D58). Lee esa decisión antes de
  investigar cualquier campo que salga vacío o como "—": un embed bloqueado por RLS se ve
  exactamente igual que un dato que no existe, y no da error.

**Tres cosas del motor genérico que ahora existen y sirven para CAC igual que para PCO:**

| Pieza | Para qué |
|---|---|
| `FieldConfig.derivarDeRegistro` | Rellenar un filtro de cascada al **editar**. Sin esto, cualquier campo auxiliar (`persistir: false`) arranca vacío en la edición y deja sin opciones al combo que cuelga de él. |
| `FieldConfig.aviso` | Advertencia bajo el campo que **no** bloquea el guardado. Para lo que es válido pero conviene mirar dos veces. |
| `ResourceConfig.reactivar` | Botón para deshacer una baja desde la ficha. |

Y un arreglo del motor que afecta a **todas** las pantallas: una lista vacía por culpa de un
filtro ya no dice "No hay X registrados" (§D61) — decía que no había datos mientras los ocultaba
ella misma.

**Lo que sigue abierto** (todo en `99_DUDAS_PARA_EL_EQUIPO.md`): §V24 el parqueadero que cuelga
del campus, §V25 las garitas de tipo campus, §V27 el choque entre PCO y GPI por el "código
único", §V28 la búsqueda por cédula completa o apellido, §V30 el descanso no se calcula con
turnos nocturnos combinados. §V26 (turnos solapados) y §V29 (guardia sin punto operativo) ya
están resueltas.

**Lo que NO se hizo a propósito:** el requisito de PCO de eliminar el "código único" choca con
un requisito de GPI ya implementado y probado. No se tocó GPI (§V27). Y "los guardias solo
entran durante su turno" **no** se convirtió en un bloqueo de inicio de sesión: la restricción
operativa ya existía (req 34) y dejar a un guardia sin poder entrar al sistema por un turno mal
tecleado es peor que el problema que resuelve.

## Sobre TestSprite en esta ronda

Los 7 planes de PCO (`tests/testsprite/planes/21_*` a `27_*`) pasan. Confirmado otra vez que la
receta del apartado de abajo funciona: cuenta explícita en el primer paso y positiva antes de
negativa.

**TestSprite encontró un bug que las 142 pruebas locales no cogieron:** al retirar "Campus" del
alta de puntos de control, las seis garitas que sí cuelgan del campus se quedaban con el
desplegable en "— Seleccionar —" y no se podían guardar. El mock de las pruebas locales solo
tenía un punto de control en un edificio, así que el caso no existía ahí. Merece la pena correr
los planes contra el preview aunque la suite local esté verde.

## Puntos a mirar en CAC

Cuando llegue `Requerimientos_CAC.docx`, manda ese documento. Mientras tanto, lo que se sabe:

- **Tablas**: `regla_acceso` (8 filas), `evento_acceso` (15), `alerta_seguridad` (4),
  `autorizacion_visita_diaria` (2). Cuenta: `carlos.chavez03@epn.edu.ec`.
- **Pantallas**: Reglas de acceso, Eventos de acceso y Alertas de seguridad (`AlertasScreen`, que
  es una pantalla a mano, no el motor genérico). "Asignaciones de guardia" **ya no está en CAC**:
  se movió a PCO por petición del propio CAC, y sus permisos INSERT/UPDATE están revocados.
- **`evento_acceso` y `bitacora_sistema` son históricos: solo INSERT.** Nunca UPDATE ni DELETE.
  Cualquier petición de "corregir un evento" choca con esto y hay que resolverla con un evento
  nuevo, no editando el anterior.

**Lo que conviene revisar, por analogía con lo que apareció en PCO, GPE y GPI:**

- El combo de **Estado** en el alta de `regla_acceso` sobra, como en todos los módulos anteriores
  (§D56). El patrón es `hideOnInsert: true` más `reactivar`.
- `regla_acceso` tiene **horario_inicio/horario_fin** y deliberadamente NO se exige
  `fin > inicio`, porque el turno nocturno es legítimo (nota en
  `20260717020325_constraints_validacion.sql`). Si CAC pide algo sobre horarios, reutiliza
  `esta_en_turno()`, `tramos_turno()` y `duracion_turno_min()`, que ya contemplan el cruce de
  medianoche — y **no** repitas el fallo de sumar 24 h a un `time`, que envuelve (§D59).
- Los estados de `alerta_seguridad` y el flujo de atención: comprobar que no haya un combo de
  estado en el alta y que "atender" sea una acción, no un campo editable.
- **Todo lo que dependa del calendario se calcula, lo que dependa de una decisión humana se
  almacena** (`estado_memorando_efectivo()`, `vigencia.ts`). Es el patrón que ya resolvió los
  estados desincronizados en GPE.

**Antes de tocar RLS en CAC**, mira §D58: dos "bugs de pantalla" de PCO eran políticas que
filtraban un embed en silencio. CAC lee muchas tablas de otros módulos (persona, vehículo, punto
de control), así que es el módulo con más probabilidad de repetir ese patrón.

## Reglas del proyecto que conviene tener presentes

- **La fecha de hoy se calcula con `public.hoy_ecuador()` (SQL) y `hoyISO()` (frontend)**, nunca
  con `current_date` ni `toISOString()`. El servidor va en UTC y Ecuador cinco horas por detrás:
  eso causó que un visitante con permiso válido fuera **denegado en la garita** cinco horas al
  día (§D52). Si tocas algo con fechas, usa esas dos funciones.
- Sin DELETE físico: las bajas cambian el estado.
- Catálogos en MAYÚSCULAS sin tildes en la base; la traducción a texto legible vive en
  `web/src/lib/catalogos.ts` (`ETIQUETA`, `ETIQUETA_CAMPO`). Al añadir un valor nuevo, añádelo
  también ahí o saldrá el código crudo en pantalla.
- Toda regla nueva va **primero en SQL** (migración) y después en el espejo de
  `web/src/lib/validacion.ts`, nunca al revés.

## Piezas reutilizables

- `FieldConfig.soloLectura` + `valorCalculado` — campo en gris con un valor que calcula el
  sistema, en vez de un desplegable que no se puede usar.
- `ResourceConfig.camposSensibles` — confirmación con el antes/después antes de guardar.
- `ResourceConfig.detalleExtra` — bloque dentro de la ficha, para gestionar registros
  relacionados sin salir (lo usa `AsociacionesVehiculo`).
- `ListaSeleccionMultiple` (en `ResourceScreen`) — lista de casillas con buscador.
- `BuscarPersonaPorCedula` — con `soloTipo` (ámbito) y `onNoEncontrada` (alta en el sitio).
- `public.estado_memorando_efectivo()` / `estado_autorizacion_efectivo()` y su espejo
  `web/src/lib/vigencia.ts` — el patrón: **lo que depende del calendario se calcula, lo que
  depende de una decisión humana se almacena**.
- `public.acentuar_texto(text)` — repone tildes en textos sembrados.

> Al añadir campos nuevos, asocia siempre la etiqueta con el control (`htmlFor` + `id`). El
> formulario genérico ya lo hace solo; si escribes una pantalla a mano, no lo olvides: sin eso
> un lector de pantalla no anuncia el campo, y las pruebas no pueden localizarlo.

## Qué cubren las 142 pruebas automáticas

| Archivo | Qué protege |
|---|---|
| `lib/validacion.test.ts` | Cédula, RUC, placa, nombres, fechas, correo, teléfono, número de memorando |
| `lib/vigencia.test.ts` | Estados calculados y que la fecha de referencia sea la de Ecuador |
| `lib/errores.test.ts` | Que ningún error del proveedor llegue en inglés |
| `lib/useBorrador.test.ts` | Persistencia de formularios, y que nunca se guarden contraseñas |
| `auth/password.test.ts` | Que la reautenticación no cierre la sesión real |
| `pages/LoginPage.test.tsx` | Que tras iniciar sesión se entre al panel |
| `pages/ModuleHome.test.tsx` | Qué tarjetas existen en cada módulo |
| `pages/modules/UsuariosScreen.test.tsx` | Panel único de usuarios, alta por cédula |
| `components/ResourceScreen.test.tsx` | Campos dinámicos, campo en gris, confirmación, borrador |
| `resources/configs-lectura.test.tsx` | Auditoría legible; biometría no pinta el rostro |
| `resources/configs-pco.test.tsx` | PCO: cascadas al editar, Reactivar, jerarquía de zonas, nombre del guardia, borrador |
| `lib/turnos.test.ts` | Turnos (incluido el nocturno), hora de Ecuador y ubicación E20/P3/E004 |

Pruebas contra la base real (no dejan rastro salvo auditoría):

```bash
psql "$DATABASE_URL" -f scripts/pruebas_gpe_gpi_nuevas.sql    # 18 casos, BEGIN … ROLLBACK
psql "$DATABASE_URL" -f scripts/pruebas_adm_nuevas.sql
python3 scripts/prueba_multisesion.py                          # requiere SB_URL, SB_ANON, SB_PASSWORD
```

## Pendientes que no bloquean

1. **§V18/§V19**: un docente sembrado (cédula 1750000232) tiene código único y carrera de
   estudiante. Sin resolver a la espera de que el equipo decida.
2. **§V21**: el Root Directory del proyecto de Vercel debería ser `web`. Mientras no lo sea,
   hace falta el `vercel.json` de la raíz; si se cambia, **hay que borrarlo**.
3. **SMTP propio**: la recuperación de contraseña usa el correo de Supabase, 2 correos/hora.
4. **Fuerza bruta**: el bloqueo por 5 intentos depende de que el intento pase por la Edge
   Function; cerrarlo del todo requiere el Auth Hook (plan de pago) o hCaptcha.
5. **SRI / ANT / Registro Civil**: sin integración; `estado_verificacion_ruc` queda
   `NO_VERIFICADO`.
6. **18 cédulas ficticias** pendientes de sustituir.
7. **Historial de migraciones**: sin reconciliar, por eso `supabase db push` no funciona.
8. **Auto-refresco del token de TestSprite**: es de plan Pro.
9. **`gh` (GitHub CLI)** está instalado en `~/.local/bin/gh` (v2.96.0, binario oficial verificado
   por checksum, sin `sudo`). **No está autenticado en WSL**: la sesión que existe es la del `gh`
   de *Windows*, y su token vive en el Credential Manager, así que el `gh` de Linux no puede
   usarlo. Para que funcione hay que ejecutar `gh auth login` **dentro de WSL**. Mientras tanto,
   los PR se abren desde el navegador.
