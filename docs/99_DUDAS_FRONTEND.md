# 99 — Dudas del frontend para el equipo

> Registro de las brechas de negocio y hallazgos técnicos que surgieron construyendo el frontend
> (`web/`) contra el backend real. Mismo patrón que `docs/99_DUDAS_PARA_EL_EQUIPO.md`: se implementó
> la opción más conservadora, se documenta aquí, y no bloqueó el desarrollo. Ninguna de estas dudas
> impidió construir los 6 módulos — son puntos a revisar con el equipo, no bugs pendientes.

| # | Tema | Estado |
|---|---|---|
| F1 | "Dar de baja" temporal con duración (persona/vehículo) | Implementado sin duración |
| F2 | Ámbito de `EMPRESA_SERVICIO` | Resuelto por el backend real: EXTERNA |
| F3 | Límite de "2 vehículos por persona" | No implementado en UI |
| F4 | `usuario_rol` bloqueada por RLS para 5 de 7 roles | Resuelto en frontend sin tocar RLS |
| F5 | DIRECTOR_ADMINISTRATIVO no puede navegar a módulos fuera de ADM | Documentado, no resuelto |
| F6 | `requiere_cambio_password` no se puede limpiar desde 6 de 7 roles | Resuelto: descarte local del aviso |

---

## F1 — "Dar de baja" temporal con duración (Patrón D) → **implementado sin duración**
**Duda original (07 §6.1):** el mockup de GPI ofrecía "Permanente / Temporal + duración", pero
`persona.estado` solo admite `ACTIVO, INACTIVO, DADO_DE_BAJA` sin columna de fecha de reactivación.
**Resolución aplicada:** el modal de baja (`ResourceScreen` → `BajaModal`) solo pide motivo (textarea
obligatoria) y cambia el campo de estado a `INACTIVO` (persona) o al valor de baja correspondiente
(vehículo → `DADO_DE_BAJA`, memorando/autorización → `REVOCADA`/`VENCIDO`, etc.). El motivo se guarda
en `persona.detalle_estado` cuando existe la columna. **No se ofrece "temporal" ni selector de
duración** en ninguna pantalla. Si el equipo decide implementarlo, necesita antes una columna de
fecha de reactivación (o un `parametro_sistema` de referencia) — es un cambio de esquema, no de UI.

## F2 — Ámbito de `EMPRESA_SERVICIO` → **resuelto por el backend real: EXTERNA**
**Duda original (07 §6.2):** el mockup de GPI gestionaba `EMPRESA_SERVICIO` como personal interno
(biometría), pero el modelo de datos también contemplaba que fuera externo.
**Resolución aplicada:** se consultó `categoria_persona` en el proyecto remoto — `EMPRESA_SERVICIO`
está sembrada con `ambito = 'EXTERNA'` (verificado 2026-07-14). El frontend sigue este dato real:
`EMPRESA_SERVICIO` aparece en `CATEGORIAS_EXTERNAS` (`src/lib/catalogos.ts`) y solo es seleccionable
en las pantallas de GPE (`Personal externo`), nunca en GPI. No requiere biometría, coherente con §D20.

## F3 — Límite de "2 vehículos por persona" → **no implementado en UI**
**Duda original (07 §6.3):** el mockup mostraba "0/2 vehículos" como regla dura, no documentada en
`04_REGLAS_NEGOCIO.md`.
**Resolución aplicada:** el formulario de asociación persona–vehículo (`cfgPersonaVehiculo`) **no**
valida ningún límite de cantidad — se registra el vínculo sin tope. Si el equipo confirma que es una
regla real, debe decidirse si se valida en el frontend, en un trigger, o en ambos (recomendado:
trigger, para que ninguna vía de escritura la esquive).

## F4 — `usuario_rol` bloqueada por RLS para 5 de 7 roles → **resuelto en frontend, sin tocar RLS**
**Hallazgo (no estaba en las brechas del doc 07):** la matriz de permisos (doc 02, tabla ADM) da
`SELECT` sobre `usuario_rol` solo a `ADMIN` y `DIR`. El resto de roles (GPI, GPE, PCO, CAC,
GUARDIA_SEGURIDAD) reciben una fila vacía al consultar su propia asignación de rol — verificado en
vivo contra `guardia.demo@epn.edu.ec` y `carlos.chavez03@epn.edu.ec` (RESPONSABLE_CONTROL_ACCESOS).
Esto rompía dos cosas: (1) mostrar el nombre del rol en la barra superior, y (2) detectar si el
usuario autenticado es el guardia para activar su vista operativa (07 §5) — con `roles` siempre
vacío, el guardia nunca habría visto su pantalla y en su lugar habría caído al home de 6 módulos.
**Resolución aplicada:** el frontend deriva una etiqueta de rol (`rolLabel`) y la detección de
guardia (`esGuardia`) **a partir de permisos efectivos y `allowed_modules()`**, nunca leyendo
`usuario_rol` (`src/auth/AuthProvider.tsx` → `derivarRolLabel`). La señal para "es guardia" es el
permiso `CAC_EVENTO_INSERT`, exclusivo del guardia según la matriz real (única fila con INSERT en
`evento_acceso` fuera del dispositivo/`service_role`) — verificado comparando los permisos efectivos
reales de `guardia.demo` vs `carlos.chavez03`. Si el equipo prefiere que el frontend lea el nombre de
rol real, hace falta ampliar la política RLS de `usuario_rol` para permitir `SELECT` de la propia fila
a todo usuario autenticado (cambio de esquema/RLS, no de frontend).

## F5 — DIRECTOR_ADMINISTRATIVO no puede navegar a módulos fuera de ADM → **documentado, no resuelto**
**Hallazgo:** `DIRECTOR_ADMINISTRATIVO` tiene permisos `*_SELECT` de solo lectura en todos los
módulos (doc 02), pero solo el permiso `ADM_MODULO_ACCEDER` — verificado en vivo con
`gary.defas@epn.edu.ec`: `allowed_modules()` devuelve únicamente `["ADM"]`. Como la navegación de
módulos depende exclusivamente de `allowed_modules()` (07 §2.3, 05 §2.3 — regla explícita del
proyecto), DIR solo puede navegar al módulo ADM en el frontend, aunque técnicamente tenga permiso de
lectura sobre `regla_acceso`, `zona`, `memorando`, personal interno, etc. Sus permisos de auditoría
"todos los `_SELECT`" quedan sin superficie de UI para consultarlos fuera de ADM.
**No se resolvió** porque cualquier opción cambia el comportamiento documentado de navegación:
(a) dar a DIR los `*_MODULO_ACCEDER` de los demás módulos (cambio de datos en `rol_permiso`, no de
esquema), o (b) construir una vista transversal de "Auditoría" dentro de ADM que junte lectura de
otros módulos sin necesitar `allowed_modules()` para cada uno (cambio de frontend, mayor alcance).
El equipo debe decidir cuál prefiere; mientras tanto DIR es plenamente funcional dentro de ADM.

## F6 — `requiere_cambio_password` no se puede limpiar desde 6 de 7 roles → **resuelto: descarte local**
**Hallazgo:** la matriz de permisos (doc 02, tabla ADM) da `UPDATE` sobre `usuario_sistema` solo a
`ADMIN` (`L C A`); el resto de roles (DIR, GPI, GPE, PCO, CAC, GUARDIA_SEGURIDAD) tienen `L²`
(SELECT restringido a la propia fila, sin UPDATE). La pantalla "Mi cuenta" intentaba bajar
`requiere_cambio_password` a `false` tras un cambio de contraseña exitoso mediante un `UPDATE` sobre
la propia fila — **verificado en vivo** con `lenin.amangandi@epn.edu.ec` (RESPONSABLE_PERSONAL_INTERNO):
el `PATCH` devuelve `200` con lista vacía (RLS descarta la fila en silencio, no es un error) y el
valor permanece en `true` indefinidamente.
**Resolución aplicada:** se eliminó ese `UPDATE` de `src/pages/CuentaPage.tsx` — la contraseña sí
cambia (vía `supabase.auth.updateUser`, que no depende de esta tabla), pero el aviso "debes cambiar
tu contraseña" (`BannerPassword` en `App.tsx`) se descarta **solo localmente** (botón ✕, por sesión de
navegador), consistente con la decisión de la sesión de tratarlo como aviso suave y no bloqueante. Si
el equipo quiere que el aviso desaparezca permanentemente tras el cambio, hace falta ampliar el
`UPDATE` de `usuario_sistema` a "cuenta propia" en RLS (cambio de esquema/política, no de frontend).
