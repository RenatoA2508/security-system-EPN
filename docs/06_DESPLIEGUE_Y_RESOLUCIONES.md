# 06 — Despliegue al remoto, resoluciones y estado final

> Documento de cierre de la 2ª sesión. Resume **todo lo que se hizo** para dejar el backend
> desplegado y funcional en el proyecto remoto de Supabase, las **inconsistencias detectadas y
> corregidas**, la **verificación end-to-end**, y **lo que queda pendiente** para continuar en otra
> sesión.

---

## 1. Resultado en una línea

**El backend completo está desplegado y verificado en el proyecto remoto de Supabase**
(`hwfayejcwpmercvmmyvw`, `https://hwfayejcwpmercvmmyvw.supabase.co`): 26 migraciones aplicadas,
datos de seguridad sembrados, 2 Edge Functions desplegadas, bucket de Storage, job `pg_cron`, cuentas
de arranque creadas, y todas las pruebas en verde. Todo el código está en Git (pendiente solo el
`git push`, que requiere aprobación).

---

## 2. Qué se hizo esta sesión

### 2.1 Entorno
- Se instaló `psql` (client 16). Docker Desktop está corriendo en Windows pero su **integración WSL
  con este distro está rota** (`/mnt/wsl/docker-desktop/cli-tools` vacío, sin socket), así que
  `supabase start`/`db reset` local no era posible. Se optó por **validar y desplegar directamente
  contra el remoto**, que además era el objetivo.
- Se corrigió `config.toml` (`[local_smtp]` → `[inbucket]`) para desbloquear el CLI, y se aplicaron
  los timeouts de sesión de §D10.

### 2.2 Despliegue
- **`supabase db push`** aplicó las 26 migraciones al remoto (autenticado con credenciales cacheadas
  del `link`, sin prompt).
- **Datos de seguridad** (roles, permisos, `rol_permiso`, categorías, parámetros) se movieron de
  `seed.sql` a la **migración `20260713192400_datos_seguridad.sql`**, porque son el modelo de
  permisos del que depende toda la RLS y deben existir en cada entorno vía `db push`.
- **Cuentas de arranque** creadas con la **Auth Admin API** (`scripts/seed_remoto.mjs`).
- **Edge Functions** desplegadas con `supabase functions deploy` (bundling nativo, sin Docker).
- **Datos demo** (`scripts/seed_demo.sql`) para ejercitar el flujo end-to-end.

### 2.3 Inconsistencias detectadas y corregidas (durante el despliegue/pruebas)
| # | Problema | Corrección | Cómo se detectó |
|---|---|---|---|
| 1 | Funciones en esquema `auth` prohibidas en Supabase hosted (`permission denied for schema auth`) | Los 5 helpers de RLS movidos de `auth.*` a `public.*` (180 referencias) | `db push` (migración 190500) |
| 2 | `vista_vehiculos_dentro` dejaba un vehículo "dentro" para siempre si INGRESO y SALIDA compartían `fecha_hora` | Reescrita con lógica "el último movimiento manda" (window function; SALIDA gana empates) | `smoke_test.sql` contra el remoto |
| 3 | Clasificación de `tipo_alerta` frágil (E9) | Determinista por código canónico en `motivo_resultado` | Revisión de diseño |
| 4 | Advisors: 6 funciones sin `search_path`; funciones ejecutables por `anon` | `search_path` fijo + `REVOKE EXECUTE` a `anon`/`PUBLIC` (migración de hardening) | `get_advisors(security)` |

### 2.4 Las 11 dudas
Todas resueltas — ver `docs/99_DUDAS_PARA_EL_EQUIPO.md` (tabla resumen + detalle por entrada).

---

## 3. Qué está vivo en el remoto (verificado)

- **25 tablas** con RLS habilitada (advisor no reporta ninguna tabla sin RLS).
- **26 migraciones** aplicadas (`supabase_migrations.schema_migrations`).
- **Modelo de seguridad**: 7 roles, 100 permisos, 144 asignaciones `rol_permiso`, 9 categorías, 8
  parámetros.
- **Funciones**: `tiene_permiso`, `permisos_efectivos`, `allowed_modules`, `tiene_algun_modulo`,
  `tiene_acceso_operativo_cac`, `puntos_control_asignados`, `registrar_sesion` + triggers de negocio.
- **Vistas**: `vista_vigencia_acceso`, `vista_vehiculos_dentro`.
- **Storage**: bucket privado `registro-biometrico` (`public=false`) con 3 políticas GPI.
- **pg_cron**: job `revisar-permanencia-vehiculos` cada hora (`0 * * * *`).
- **Edge Functions**: `validar-biometria` y `registrar-evento-acceso` desplegadas.
- **Cuentas de arranque** (⚠️ rotar contraseña en el primer login):

  | Cuenta | Email | Contraseña inicial | Rol |
  |---|---|---|---|
  | Admin | `admin@epn.edu.ec` | `CambiarInmediatamente#2026` | ADMINISTRADOR_SISTEMA |
  | Guardia demo | `guardia.demo@epn.edu.ec` | `CambiarInmediatamente#2026` | GUARDIA_SEGURIDAD (garita demo) |

---

## 4. Verificación end-to-end (contra la base real)

| Prueba | Resultado |
|---|---|
| Login de ambas cuentas (GoTrue real) | ✅ token emitido |
| `allowed_modules()` admin / guardia | ✅ `["ADM"]` / `["CAC"]` |
| RLS: admin ve 7 roles; guardia ve 0 roles | ✅ denegación correcta |
| RLS: guardia ve 9 categorías (L universal) | ✅ |
| `registrar_sesion()` RPC | ✅ fila de sesión con expiración |
| `smoke_test.sql` (triggers, vistas, bloqueos) | ✅ SMOKE_TEST_PASSED |
| Trigger biometría EXTERNA bloqueada | ✅ |
| Evento DENEGADO → 1 alerta `MEMORANDO_VENCIDO` | ✅ clasificación determinista |
| `vista_vehiculos_dentro` aparece/desaparece con INGRESO/SALIDA | ✅ (tras el fix) |
| Bloqueo de DELETE físico | ✅ |
| `validar-biometria` (docente con biometría / forzar_fallo) | ✅ `match:true` / `match:false` |
| `registrar-evento-acceso` AUTOMATICA (device válido) | ✅ AUTORIZADO, evento creado |
| `registrar-evento-acceso` AUTOMATICA (device desconocido) | ✅ HTTP 401 |
| `registrar-evento-acceso` MANUAL (guardia JWT, visitante por cédula) | ✅ AUTORIZADO |
| `registrar-evento-acceso` MANUAL sin JWT | ✅ HTTP 401 |
| RLS del guardia: solo ve eventos de su punto asignado | ✅ ve exactamente los 2 del punto demo |

---

## 5. Cómo operar / reproducir

```bash
# 1. Migraciones al remoto (ya aplicadas; para futuros cambios):
supabase db push --linked

# 2. Cuentas de arranque en el remoto (idempotente):
SUPABASE_URL="https://hwfayejcwpmercvmmyvw.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="<service_role key del dashboard>" \
node scripts/seed_remoto.mjs

# 3. Datos demo (opcional, vía SQL editor del dashboard o MCP):
#    scripts/seed_demo.sql

# 4. Edge Functions:
supabase functions deploy validar-biometria --project-ref hwfayejcwpmercvmmyvw
supabase functions deploy registrar-evento-acceso --project-ref hwfayejcwpmercvmmyvw

# 5. Tipos TypeScript (regenerar tras cambios de esquema):
supabase gen types typescript --linked > types/database.types.ts

# 6. Desarrollo LOCAL (cuando haya Docker): supabase start && supabase db reset
#    (db reset corre migraciones + seed.sql, que trae el bootstrap local).
```

Las llamadas de ejemplo a las Edge Functions están en `scripts/edge_functions.http`.
El contrato para el frontend Figma está en `docs/05_API_PARA_FRONTEND.md`.

---

## 6. Pendiente para otra sesión

Nada bloquea el uso del backend. Lo que queda es mejora/operación:

1. **`git push`** — 30+ commits locales listos; requiere aprobación humana (interceptado por
   `.claude/settings.json`). Ejecutar cuando se quiera publicar en GitHub.
2. **Rotar las contraseñas de arranque** en el primer login (`requiere_cambio_password = true` ya
   está forzado en ambas cuentas).
3. **Protección de contraseñas filtradas (HIBP)**: el advisor la marca deshabilitada; **requiere plan
   Pro** (la API devolvió HTTP 402). Habilitar en el dashboard tras el upgrade.
4. **Reconocimiento facial real**: reemplazar el mock de `validar-biometria` por un proveedor real
   (AWS Rekognition / Azure Face API). El `TODO` está marcado en el código; el resto del flujo no
   cambia (misma forma de respuesta).
5. **Validar con el equipo** los valores provisionales: catálogo `tipo_alerta` (§D16), límites de
   permanencia vehicular (§D25), y el `ambito = EXTERNA` de la categoría CONDUCTOR (E4).
6. **Frontend (Figma)**: conectar usando `docs/05_API_PARA_FRONTEND.md` y `types/database.types.ts`.
7. **Datos demo**: si se quiere una base limpia para producción, no correr `scripts/seed_demo.sql`
   (y opcionalmente borrar las filas demo `00000000-...-d1/d2/d3/da/db` y sus eventos).
8. **Advisors residuales aceptados**: los 7 helpers ejecutables por `authenticated` son necesarios
   (RLS + RPC); `rls_auto_enable` es de la plataforma. No requieren acción.

---

## 7. Notas de seguridad

- La `service_role` key **no** está en el repositorio ni en el código; se pasó por variable de
  entorno al correr `scripts/seed_remoto.mjs`. Mantenerla fuera de Git y del frontend.
- Las contraseñas de arranque son placeholders conocidos y **deben rotarse**.
- Toda la lógica de permisos vive en la base (RLS + funciones), no en el cliente: el frontend solo
  muestra/oculta UI según `allowed_modules()`; la base deniega por defecto.
