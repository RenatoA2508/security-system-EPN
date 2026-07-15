# 07 — Diseño del Frontend

> **Autoridad de este documento:** define **cómo se ve y cómo se navega** el sistema — layout,
> componentes, patrones de interacción. **No define datos, catálogos, reglas de negocio ni
> permisos** — eso lo definen exclusivamente `01_AUTENTICACION_Y_ROLES.md` a `06_DESPLIEGUE_...md`
> y `types/database.types.ts`. Si algo en este documento choca con esos, **ganan esos**, pero el
> componente/layout se mantiene y solo se ajusta el campo o la validación en conflicto.
>
> **Referencia visual única:** el prototipo del módulo GPI (`PrototipoGPI_Actualizado.pdf`,
> evaluado 2026-07-14). Reemplaza cualquier referencia anterior del módulo GPE — no mezclar
> patrones de ambos. Los 6 módulos deben verse como si los hubiera construido el mismo equipo,
> con esta base.

---

## 1. Identidad visual

Paleta institucional EPN (confirmada por los tres prototipos recibidos hasta ahora — GPE y GPI
coinciden en navy/rojo/dorado, es la identidad del escudo):

| Token | Hex | Uso |
|---|---|---|
| `navy` | `#14284B` | Barra superior, textos de énfasis, botones primarios |
| `red` | `#B3262D` | Botón "Salir", acciones destructivas, alertas |
| `gold` | `#D4AF37` | Línea de acento bajo el título de login, detalles secundarios |
| `beige` | `#D8D1A7` | Superficies secundarias (poco uso) |
| `gray-bg` | `#F5F7FA` | Fondo general de la aplicación |
| `white` | `#FFFFFF` | Tarjetas, paneles, formularios |

Tipografía: sans-serif del sistema (o similar a la usada en el mockup), tamaño base ~14–15px,
títulos de sección en negrita, subtítulos en gris (`#5a6a82` aprox.) y tamaño menor.

Componentes base: tarjetas blancas con esquinas redondeadas y sombra suave; badges de estado
con punto de color + texto; botones primarios navy con texto blanco, botones secundarios de
borde sin relleno.

---

## 2. Estructura de navegación

### 2.1 Login
Tarjeta centrada sobre fondo gris claro. Header navy con logo institucional, título
"Sistema de Seguridad — EPN", subtítulo, línea dorada de acento. Formulario: usuario, contraseña
(con toggle mostrar/ocultar), checkbox "Recordar sesión", enlace "¿Olvidó su contraseña?", botón
primario "Ingresar al sistema".

⚠️ **Diferencia obligatoria vs. el mockup:** el login real usa `supabase.auth.signInWithPassword`,
no credenciales de demo hardcodeadas. El texto "Acceso de demostración: admin/admin123" no debe
existir en producción — como mucho, puede quedar detrás de una variable de entorno de desarrollo.
"Recordar sesión" es decorativo: por decisión ya tomada (`01_AUTENTICACION_Y_ROLES.md` §5),
`recordar_sesion` está deshabilitado a nivel de proyecto Supabase.

### 2.2 Pantalla de bienvenida (opcional)
Transición breve tras el login con checklist de verificación ("Verificando credenciales...",
"Cargando módulos...", "Bienvenido"). Es un detalle de pulido, no bloqueante — implementar solo si
sobra tiempo; no debe retrasar artificialmente el login real.

### 2.3 Home — Panel Principal
Barra superior fija: logo + nombre del sistema a la izquierda; a la derecha, nombre de usuario +
rol, indicador "En línea", botón "Salir" en rojo. **No lleva barra de KPIs** (a diferencia del
mockup de GPE, descartado).

Grid de 6 tarjetas, una por módulo (Personal Interno, Puntos de Control, Personal Externo,
Control de Accesos, Administración, Monitoreo — mismos íconos/colores ya usados en ambos
mockups). Cada tarjeta tiene ícono, título, descripción corta y botón "Acceder al módulo".

⚠️ **Diferencia obligatoria vs. el mockup:** las etiquetas "DISPONIBLE" / "NO DISPONIBLE" /
"PROTOTIPO" eran decorativas (solo GPI estaba "disponible" porque era el único construido). En
el sistema real, **qué tarjetas se muestran depende de `allowed_modules()`** (RPC) según el rol
del usuario autenticado — no hay tarjetas deshabilitadas visualmente, simplemente no aparecen las
que el usuario no puede usar.

### 2.4 Home de módulo
Breadcrumb (`← Panel Principal › Nombre del módulo`) + título + subtítulo con el rol actor.
Grid de tarjetas de submódulo (ej. GPI: Personas, Vehículos). Incluso si un módulo solo tiene un
submódulo, mantener el mismo patrón de tarjeta por consistencia.

### 2.5 Navegación anidada (categorías dentro de un submódulo)
Cuando un submódulo se divide en categorías (ej. Personas → Docentes/Estudiantes/Empleados/
Empresas de Servicios; Estudiantes → EPN/CEC; Empleados → Administrativo/Trabajadores), se repite
el mismo patrón de grid de tarjetas con breadcrumb creciente. No inventar un patrón de navegación
distinto por nivel de profundidad.

---

## 3. Patrones de pantalla reutilizables

### Patrón A — Listado con panel de detalle lateral
Usar para cualquier entidad consultable (Docentes, Estudiantes, Empleados, Vehículos, etc.):
- Barra de búsqueda simple (una caja de texto, sin filtros adicionales salvo que el mockup de
  GPI los muestre explícitamente para esa pantalla).
- Botón primario "+ Registrar [Entidad]" arriba a la derecha.
- Tabla con columnas relevantes a la entidad + columna de estado (badge).
- Click en una fila abre un **panel lateral derecho** (no modal) con: avatar/ícono con iniciales,
  nombre, subtítulo (rol/categoría + estado), lista de atributos clave-valor, y botones "Editar" /
  "Dar de baja" al final.

### Patrón B — Formulario de registro
Página completa (no modal), no un stepper salvo que la entidad lo requiera por dependencia real
(ver Patrón D). Grid de 2–3 columnas para los campos, campos obligatorios marcados con `*`.
Si la entidad tiene biometría (personal interno), incluir sección "Datos faciales" con botón
"Capturar / Subir foto" — este control debe conectar con el flujo real de enrolamiento
(`face-api.js` en el navegador + RPC `enrolar_biometria`, ver `01_AUTENTICACION_Y_ROLES.md` §6),
no ser un placeholder sin función.
Botones al final: primario "Registrar", secundario "Volver al panel".

### Patrón C — Formulario de edición
Misma estructura visual que el registro, pero con la mayoría de campos **deshabilitados** (grises)
y un aviso arriba indicando cuáles son editables. Qué campos son editables realmente lo decide la
matriz de permisos y el sentido común del dato (ej. cédula y nombres no deberían ser editables
libremente una vez creada la persona) — **no copiar literalmente la lista de 3 campos del mockup
de GPI sin revisar contra el esquema real de cada entidad**.

### Patrón D — "Dar de baja"
Modal (único caso donde sí se usa modal) con: textarea de motivo (obligatorio), selector de tipo
de baja, y confirmar/cancelar.

⚠️ **Este patrón necesita una decisión antes de construirse — ver sección 5.** El mockup de GPI
ofrece "Permanente / Temporal + duración", pero esa noción de baja temporal con duración **no
existe en el esquema real** (`persona.estado` solo admite `ACTIVO, INACTIVO, DADO_DE_BAJA`, sin
columna de fecha de reactivación). No construir el selector de duración hasta resolver dónde vive
ese dato.

### Patrón E — Flujo de pasos (solo cuando hay una dependencia real de datos)
Ejemplo real y válido: registrar un vehículo requiere primero **buscar y seleccionar la persona
propietaria** (paso 1, con resultados en vivo y contador "X/2 vehículos") antes de mostrar el
formulario de datos del vehículo (paso 2). Usar este patrón de 2 pasos solo cuando el segundo paso
depende de datos elegidos en el primero — no convertir cualquier formulario largo en un stepper.

---

## 4. Iconografía

Librería recomendada: `lucide-react` (ya usada en ambos prototipos recibidos). Mantener la
asignación de ícono por módulo ya usada consistentemente en los dos mockups:

| Módulo | Ícono sugerido |
|---|---|
| Personal Interno (GPI) | `Users` / `UserCog` |
| Puntos de Control (PCO) | `Shield` / `MapPin` |
| Personal Externo (GPE) | `UserCheck` |
| Control de Accesos (CAC) | `Fingerprint` / `Lock` |
| Administración (ADM) | `Settings` |
| Monitoreo | `Monitor` |

---

## 5. Vista del guardia (rol `GUARDIA_SEGURIDAD`)

No sigue el patrón de "6 tarjetas de módulo → submódulos". Es una vista operativa reducida,
condicional dentro de la misma aplicación (activada cuando el rol autenticado es guardia):
punto de control asignado, buscador de persona por cédula, registro de ingreso/salida, alertas de
su punto. No existe ninguna referencia visual de esto en los mockups recibidos — Claude Code debe
construirla reutilizando los componentes base (tarjetas, tablas, badges) del resto del sistema,
priorizando velocidad de uso sobre densidad de información (es una pantalla de garita, se usa de
pie, con prisa).

---

## 6. Brechas abiertas — resolver antes de construir esas pantallas

Estas no son decisiones de diseño, son decisiones de negocio que el mockup de GPI expuso pero que
`01_AUTENTICACION_Y_ROLES.md`–`06_DESPLIEGUE_Y_RESOLUCIONES.md` no cubren. Si Claude Code las
encuentra sin resolver, debe registrarlas en `docs/99_DUDAS_FRONTEND.md` y seguir con lo demás,
no bloquear todo el desarrollo por esto — mismo patrón que ya usaste con las dudas del backend.

1. **"Dar de baja" temporal con duración** (Patrón D): no hay dónde persistir la duración ni la
   fecha de reactivación automática en `persona`. Opciones a decidir: (a) usar `INACTIVO` +
   guardar el motivo/duración solo como texto en `bitacora_sistema`, sin reactivación automática;
   (b) no ofrecer "temporal" para personas, solo para vehículos (que sí tienen `fecha_fin` real en
   `persona_vehiculo`).
2. **Personal de empresas de seguridad/limpieza contratadas**: el mockup de GPI las gestiona como
   si fueran personal **interno** (biometría, categoría `EMPRESA_SERVICIO`). Pero el modelo de
   datos también contempla que ese tipo de personal podría ser **externo** (vía GPE, con cédula).
   Hay que decidir explícitamente el `ambito` de esa categoría antes de construir la pantalla.
3. **Límite de "2 vehículos por persona"**: el mockup lo muestra como regla dura ("0/2 vehículos").
   No está documentado en `04_REGLAS_NEGOCIO.md`. Confirmar si es una regla real a validar en el
   front (y en RLS/trigger) o solo un límite de UI de ese prototipo específico.
