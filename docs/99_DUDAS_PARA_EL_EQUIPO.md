# 99 — Dudas para el equipo → **TODAS RESUELTAS**

> Registro de las 11 dudas/inferencias que surgieron durante la construcción autónoma del backend.
> En la primera sesión se implementó la opción más conservadora y se anotaron aquí. En la segunda
> sesión (despliegue al proyecto remoto de Supabase) **todas quedaron resueltas y verificadas
> contra la base real**. Cada entrada indica la **resolución** y **cómo se ejecutó/verificó**.
>
> Para el detalle completo del despliegue ver `docs/06_DESPLIEGUE_Y_RESOLUCIONES.md`.

| # | Tema | Estado |
|---|---|---|
| E1 | Validación local sin Docker | ✅ Resuelta: validado y desplegado contra el remoto |
| E2 | `dispositivo.codigo_mac` UNIQUE | ✅ Confirmada como decisión de diseño |
| E3 | `rol.nombre_rol` con CHECK | ✅ Confirmada como decisión de diseño |
| E4 | `ambito` de la categoría CONDUCTOR | ✅ Decidido: EXTERNA |
| E5 | Bootstrap de `auth.users` | ✅ Resuelta: cuentas creadas por Auth Admin API y login verificado |
| E6 | Lectura vía `*_MODULO_ACCEDER` | ✅ Confirmada; RLS verificada rol por rol |
| E7 | 2 permisos nuevos | ✅ Confirmados y en uso |
| E8 | Permisos revocados a CAC | ✅ Confirmado a favor de la matriz por tabla |
| E9 | Clasificación de `tipo_alerta` | ✅ Resuelta: clasificación determinista por código canónico |
| E10 | Bucket de Storage solo GPI | ✅ Resuelta: confirmado por el usuario, desplegado |
| E11 | Huecos de la Edge Function | ✅ Resueltos (3 sub-puntos) |

---

## E1 — Validación local sin Docker → **RESUELTA**
**Duda original:** no se pudo correr `supabase db reset` (sin Docker/psql en el entorno de la 1ª sesión).
**Resolución:** en la 2ª sesión se instaló `psql`, y como la integración WSL de Docker Desktop seguía
rota, se validó y desplegó **directamente contra el proyecto remoto** de Supabase (`supabase db push`
autenticado con credenciales cacheadas + el MCP de Supabase para pruebas transaccionales con
`ROLLBACK`). **Las 26 migraciones están aplicadas en el remoto**, el `smoke_test.sql` corrió en verde
contra la base real, y las Edge Functions se probaron en vivo. Ya no es una duda: el backend está
desplegado y verificado.

## E2 — `dispositivo.codigo_mac` UNIQUE → **DECISIÓN CONFIRMADA**
Se mantiene el `UNIQUE`. Es coherente con `01_AUTENTICACION_Y_ROLES.md` §4 (el `codigo_mac` previene
la suplantación de hardware; debe identificar un dispositivo de forma inequívoca). La Edge Function
`registrar-evento-acceso` lo usa junto con `direccion_ip` para autenticar al dispositivo, y se
verificó en vivo que un dispositivo desconocido recibe **HTTP 401**.

## E3 — `rol.nombre_rol` con CHECK → **DECISIÓN CONFIRMADA**
Se mantiene el `CHECK` cerrado a los 7 roles (`01_AUTENTICACION_Y_ROLES.md` §3: "los únicos valores
válidos"). Ampliar el catálogo de roles es un `ALTER` trivial si el equipo lo decide.

## E4 — `ambito` de la categoría CONDUCTOR → **DECIDIDO: EXTERNA**
`CONDUCTOR` se siembra con `ambito = EXTERNA` (conductor de una empresa de transporte/servicio
contratada). Un conductor interno de la EPN encaja en `TRABAJADOR`. Si el equipo lo necesita interno,
es un `UPDATE` de una fila. Decisión tomada; no bloquea nada.

## E5 — Bootstrap de `auth.users` → **RESUELTA (cambio de implementación)**
**Duda original:** el `INSERT` crudo en `auth.users` desde `seed.sql` no estaba verificado en hosted.
**Resolución:** para el remoto se dejó de usar el INSERT crudo. Las dos cuentas de arranque (admin +
guardia demo) se crean con la **Auth Admin API de GoTrue** (`scripts/seed_remoto.mjs`), que genera
usuarios plenamente válidos (identidad, providers, tokens). El trigger `on_auth_user_created` crea
automáticamente su fila en `usuario_sistema`. **Se verificó login real** de ambas cuentas contra el
GoTrue del proyecto, y que `allowed_modules()` devuelve `["ADM"]` y `["CAC"]` respectivamente.
El `seed.sql` con INSERT crudo se conserva **solo para desarrollo local** (donde sí funciona).

## E6 — Lectura vía `*_MODULO_ACCEDER` para celdas "L" sin código dedicado → **CONFIRMADA Y VERIFICADA**
Se mantiene el patrón (helpers `public.tiene_algun_modulo()`, `public.tiene_acceso_operativo_cac()`).
Se verificó rol por rol contra la base real: p. ej. el guardia lee `categoria_persona` (9 filas) pero
no `rol` (0 filas, denegado por RLS); el admin lee `rol` (7 filas). El comportamiento coincide con la
matriz de `02_MATRIZ_PERMISOS_RLS.md`.

## E7 — Dos permisos nuevos (`ADM_BIOMETRIA_SELECT`, `CAC_AUTORIZACION_SELECT`) → **CONFIRMADOS**
Ambos siguen el formato `MODULO_ENTIDAD_ACCION` y cubren celdas de la matriz que no tenían código
propio, sin sobre-conceder. Están sembrados (100 permisos totales) y en uso por las políticas RLS.

## E8 — Permisos revocados a `RESPONSABLE_CONTROL_ACCESOS` → **CONFIRMADO**
Se mantiene la resolución a favor de la matriz por tabla (más granular): el supervisor CAC **no**
recibe `CAC_EVENTO_INSERT` ni `CAC_AUTORIZACION_INSERT/UPDATE` (esas son celdas C/A del guardia,
footnotes 6 y 9). Si el equipo quiere que el supervisor también registre, es un `INSERT` de 3 filas
en `rol_permiso`.

## E9 — Clasificación `motivo_resultado → tipo_alerta` → **RESUELTA (determinista)**
**Duda original:** la clasificación por coincidencia difusa de texto (`ilike`) era frágil.
**Resolución:** ahora es **determinista**. Quien deniega el acceso escribe `motivo_resultado` con un
**código canónico** como prefijo (`BIOMETRIA_FALLIDA: ...`, `MEMORANDO_VENCIDO: ...`, etc.); el
trigger toma el prefijo antes del `:` y lo mapea exacto contra el catálogo `tipo_alerta`, con
`PERSONA_NO_AUTORIZADA` como respaldo para motivos sin código. La Edge Function emite esos códigos en
cada denegación. **Verificado**: un evento DENEGADO con motivo `MEMORANDO_VENCIDO: ...` genera 1
alerta clasificada exactamente como `MEMORANDO_VENCIDO`.

## E10 — Bucket de Storage de biometría → **RESUELTA: solo GPI**
Confirmado por el usuario en la 1ª sesión: el bucket `registro-biometrico` es **privado y solo GPI**
(GPE nunca, por §D20; ADM ve solo metadatos, nunca el archivo). Desplegado en el remoto: bucket
`public=false` con 3 políticas (`select`/`insert`/`update`) atadas a `GPI_BIOMETRIA_*`.

## E11 — Huecos de la Edge Function `registrar-evento-acceso` → **RESUELTOS**
1. **Zona horaria** de `regla_acceso.horario_*`: decidido `America/Guayaquil` (UTC-5), correcto para
   la EPN. Es una decisión explícita, documentada en el código.
2. **`DISPOSITIVO_NO_RECONOCIDO` sin evento que referenciar**: se mantiene el diseño correcto — un
   dispositivo no identificado se rechaza (HTTP 401) y se registra en `bitacora_sistema` (no en
   `alerta_seguridad`, que exige `id_evento NOT NULL`). Verificado en vivo (401).
3. **Atribución de `bitacora_sistema.id_usuario`** en escrituras vía `service_role`: los eventos de
   dispositivo llevan `id_usuario` NULL (correcto, §4 doc 01: "id_usuario nulo donde aplique"); los
   registros manuales del guardia se atribuyen con una fila explícita de bitácora. Los eventos
   creados por inserción directa (REST) sí resuelven `auth.uid()` correctamente. Aceptado como
   diseño final del patrón "Edge Function + service_role".

---

## Nota adicional de la 2ª sesión (hallazgos y hardening)
Al desplegar y probar contra el remoto se detectaron y **corrigieron** además:
- **Funciones en el esquema `auth`**: Supabase hosted no permite crear funciones en `auth`; los 5
  helpers de RLS se movieron a `public` (funcionaba en local, fallaba en remoto).
- **`vista_vehiculos_dentro`**: fragilidad ante timestamps iguales (INGRESO y SALIDA en el mismo
  instante dejaban el vehículo "dentro" para siempre); reescrita con lógica "el último movimiento
  manda". Detectado por el smoke test.
- **Advisors de seguridad de Supabase**: se fijó `search_path` en 6 funciones de trigger y se revocó
  `EXECUTE` a `anon`/`PUBLIC` en todas las funciones propias. Warnings residuales: los 7 helpers que
  `authenticated` **debe** poder llamar (RLS + RPC del frontend) y `rls_auto_enable` (función de la
  plataforma), ambos aceptados; y la protección de contraseñas filtradas (HIBP), que **requiere plan
  Pro** — habilitarla en el dashboard tras el upgrade.
