# 06 — Cuentas del sistema (acceso)

> Roster de las cuentas de login sembradas en el proyecto remoto. La **fuente de
> verdad reproducible** es `scripts/seed_remoto.mjs` (idempotente); este documento
> lo resume para el equipo. La autoridad del modelo de autenticación es
> `01_AUTENTICACION_Y_ROLES.md`.

---

## Cómo se ingresa

El login es **Supabase Auth nativo** (correo + contraseña). Al autenticarse, los
permisos se calculan **en vivo** desde `usuario_rol → rol → rol_permiso → permiso`
(no se copian al JWT), de modo que revocar un rol surte efecto inmediato. Ver
`01_AUTENTICACION_Y_ROLES.md` §2.

Un mismo usuario puede acumular varios roles; sus permisos efectivos son la unión
de las asignaciones activas.

---

## Cuentas sembradas (2026-07-14)

Todas se crean con la contraseña de arranque **`CambiarInmediatamente#2026`** y
`requiere_cambio_password = true` (debe cambiarse en el primer login).

| Correo | Persona | Rol | Módulo | Alcance |
|---|---|---|---|---|
| `admin@epn.edu.ec` | Administrador del Sistema | `ADMINISTRADOR_SISTEMA` | ADM | Usuarios, roles, permisos, parámetros, auditoría, catálogos |
| `gary.defas@epn.edu.ec` | Gary Defas | `DIRECTOR_ADMINISTRATIVO` | ADM (solo lectura) | Consultas, reportes, auditoría; **no modifica datos** |
| `lenin.amangandi@epn.edu.ec` | Lenin Amangandi | `RESPONSABLE_PERSONAL_INTERNO` | GPI | Personal interno, biometría, asociaciones vehiculares |
| `joel.velastegui@epn.edu.ec` | Joel Velastegui | `RESPONSABLE_PERSONAL_EXTERNO` | GPE | Personal externo, memorandos, autorizaciones |
| `heidy.tenelema@epn.edu.ec` | Heidy Tenelema | `RESPONSABLE_PUNTOS_CONTROL` | PCO | Zonas, puntos de control, dispositivos |
| `carlos.chavez03@epn.edu.ec` | Sebastián Chávez | `RESPONSABLE_CONTROL_ACCESOS` | CAC | Reglas de acceso, supervisión de eventos, alertas |
| `guardia.demo@epn.edu.ec` | Guardia Demo | `GUARDIA_SEGURIDAD` | CAC (operativo) | Validaciones, entradas/salidas, visitas; garita demo |

Los 7 roles del sistema están definidos en `01_AUTENTICACION_Y_ROLES.md` §3.

---

## Pendientes / notas de seguridad

- ⚠️ **Cédulas placeholder.** Los 5 responsables se sembraron con cédulas
  `9999999990`–`9999999994` (la columna `persona.cedula` es `NOT NULL`). **ADM
  debe reemplazarlas por las reales.**
- ⚠️ **Cambiar la contraseña de arranque** en el primer login de cada cuenta.
- ⚠️ **Rotar la `service_role key`** si se usó fuera de un entorno controlado
  (se empleó una vez para sembrar estas cuentas vía la Admin API).
- La `service_role key` **nunca** va al repositorio ni al frontend.

---

## Recrear / añadir cuentas

```bash
SUPABASE_URL="https://<ref>.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="<service_role key>" \
node scripts/seed_remoto.mjs
```

El script es **idempotente**: no duplica cuentas ni personas existentes. Para
añadir una cuenta nueva, agrega una entrada al arreglo `RESPONSABLES` de
`scripts/seed_remoto.mjs` (persona UUID fijo, correo, rol) y vuelve a ejecutarlo.
El paso de crear la cuenta `auth` usa la **Admin API de GoTrue** (no un INSERT
crudo en `auth.users`, que la versión hosted rechaza — ver `99_DUDAS...` E5).
