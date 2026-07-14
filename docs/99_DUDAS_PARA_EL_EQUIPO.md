# 99 — Dudas para el equipo

> Acumulado por Claude Code durante la construcción autónoma del backend.
> Ninguna de estas dudas bloqueó el avance: en cada caso se implementó la opción
> más conservadora y se documenta aquí para revisión posterior.

---

## Entorno de trabajo

### E1 — No se pudo ejecutar `supabase db reset` en este entorno (sin Docker)
El flujo de trabajo obligatorio (CLAUDE.md) pide validar cada migración localmente con
`supabase db reset` antes de tocar el proyecto remoto. Este entorno de ejecución (sandbox en
segundo plano) **no tiene acceso a Docker** (`Cannot connect to the Docker daemon`) ni a
`psql`/PostgreSQL instalable sin privilegios `sudo`. Tampoco se creó un *branch* de desarrollo de
Supabase para validar de forma remota-pero-aislada, porque la herramienta lo marca explícitamente
como una acción con **costo** (`confirm_cost_id` requerido) — y gastar dinero de la cuenta del
usuario no es una decisión que corresponda tomar en automático.

**Decisión conservadora aplicada:** todas las migraciones, seed, políticas RLS, triggers, vistas
y Edge Functions se escribieron con revisión manual exhaustiva (orden de dependencias entre
tablas, nombres de columnas cruzados entre archivos, tipos y CHECKs contra los documentos fuente),
pero **sin ejecución real contra una base de datos**. `supabase db push` seguirá pidiendo tu
aprobación como estaba previsto; se recomienda ejecutar `supabase db reset` en tu máquina (con
Docker disponible) **antes** de aprobar el push, como primera verificación real.

---

## Inferencias razonables (no contradicen ningún documento, pero van más allá de lo explícito)

### E2 — `dispositivo.codigo_mac` con restricción `UNIQUE`
Ningún documento lo pide explícitamente, pero `01_AUTENTICACION_Y_ROLES.md` §4 describe el
`codigo_mac` como lo que "previene la suplantación de hardware": si dos dispositivos pudieran
compartir el mismo `codigo_mac`, la Edge Function no podría usarlo para identificar un dispositivo
de forma inequívoca. Se agregó `UNIQUE` sobre `dispositivo.codigo_mac`.

### E3 — `rol.nombre_rol` restringido por `CHECK` a los 7 roles definitivos
`01_AUTENTICACION_Y_ROLES.md` §3 dice explícitamente "estos son los únicos valores válidos de
`rol.nombre_rol`". Se interpretó como un `CHECK` cerrado a esos 7 valores, en vez de dejar la
columna como texto libre con solo `UNIQUE`. Si el equipo decide permitir roles adicionales en el
futuro, esto requiere un `ALTER TABLE ... DROP CONSTRAINT` trivial.

### E4 — `categoria_persona.CONDUCTOR` sembrada con `ambito = EXTERNA`
El catálogo de `codigo_categoria` (§6 del PDF) incluye `CONDUCTOR` sin especificar su `ambito`.
Las demás categorías se reparten claramente entre internas (DOCENTE, ESTUDIANTE, ADMINISTRATIVO,
TRABAJADOR) y externas (EMPRESA_SERVICIO, VISITANTE, PROVEEDOR, CONTRATISTA). Se sembró
`CONDUCTOR` como `EXTERNA` (conductor de una empresa de transporte/servicio contratada), pero es
una inferencia: un conductor interno de la EPN encajaría igual de bien en `TRABAJADOR`. Si el
equipo lo confirma como interno, es un `UPDATE` de una fila.

### E5 — Bootstrap de `auth.users` en `seed.sql` sin verificación de ejecución
Por §D13, el primer administrador (y, para que `guardia_punto_control` no quede vacío en la demo,
también un guardia) se siembran insertando directamente en `auth.users` (con `encrypted_password`
vía `pgcrypto`) para poder loguearse con Supabase Auth real, no solo con filas de `usuario_sistema`
huérfanas. Este patrón es el estándar de la comunidad Supabase, pero **no se pudo ejecutar en este
entorno** (ver E1) para confirmar que las columnas obligatorias de `auth.users` coinciden
exactamente con las de esta versión del CLI (`supabase_cli 2.105.0` / Postgres 17). Verificar con
el primer `supabase db reset` real que ambas cuentas (`admin@epn.edu.ec`,
`guardia.demo@epn.edu.ec`, contraseña `CambiarInmediatamente#2026`) pueden loguearse.
