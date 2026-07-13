# Sistema de Seguridad EPN — Reglas del proyecto

Backend en Supabase (PostgreSQL) para el Sistema de Seguridad y Control de Accesos de la
Escuela Politécnica Nacional. Proyecto académico — Ingeniería de Software I, periodo 2026-A.

## Documentos fuente (leer antes de actuar)

| Archivo | Qué contiene | Autoridad |
|---|---|---|
| `docs/Modelo_Datos_Consolidado_EPN.pdf` | 24 entidades, atributos, tipos, PK/FK, CHECKs, relaciones. **+1 tabla añadida: ver doc 03 §D11 → 25 en total** | **Fuente de verdad del esquema** |
| `docs/01_AUTENTICACION_Y_ROLES.md` | Modelo de autenticación, 7 roles, identidad de dispositivos | **Fuente de verdad de auth** |
| `docs/02_MATRIZ_PERMISOS_RLS.md` | Matriz permiso × rol por tabla y acción | **Fuente de verdad de RLS** |
| `docs/03_DECISIONES_Y_CORRECCIONES.md` | Conflictos ya resueltos entre documentos previos | **No re-litigar estas decisiones** |
| `docs/04_REGLAS_NEGOCIO.md` | Flujo completo de acceso y reglas de negocio (todas resueltas) | **Fuente de verdad del comportamiento** |

Si un documento contradice a otro, gana el que aparece como autoridad en esta tabla.
Si encuentras una contradicción no cubierta aquí, **detente y pregunta** — no la resuelvas en silencio.

## Principios de arquitectura (no negociables)

- **Una sola base de datos.** Sistema monolítico modular. NO microservicios.
- **Sin entidades duplicadas.** `persona`, `vehiculo`, `empresa` y `categoria_persona` son
  maestras únicas propiedad de ADM. Ningún módulo crea copias; se referencian por FK.
- **Sin DELETE físico.** Ninguna baja (personas, vehículos, reglas, usuarios) elimina la fila:
  se cambia el estado (`ACTIVO` / `INACTIVO` / `DADO_DE_BAJA`, etc.).
- **`evento_acceso` y `bitacora_sistema` son históricos:** solo INSERT. Nunca UPDATE ni DELETE.
- **Dos vías de validación (§D20):** el personal **interno** se identifica con **biometría facial**
  (`origen_registro = AUTOMATICA`); el personal **externo** se identifica con su **cédula**, tecleada
  por el guardia (`origen_registro = MANUAL`). **Los externos NUNCA tienen registro biométrico.**
  Esto anula la regla del Contexto General §6 que decía "solo biometría facial".
- El **login al sistema** (`usuario_sistema`) y la **validación de acceso físico** son dos
  mecanismos distintos. No confundirlos.

## Convenciones

- `snake_case` en todas las tablas y columnas.
- Valores de catálogo (`CHECK`) en MAYÚSCULAS y **sin tildes** (`AUTENTICACION`, no `AUTENTICACIÓN`).
- `uuid` con `gen_random_uuid()` como PK en todas las entidades.
- Códigos de permiso: `MODULO_ENTIDAD_ACCION` (ej. `GPI_PERSONA_INSERT`).
- Timestamps: `timestamptz`, `DEFAULT now()`.

## Flujo de trabajo obligatorio

1. Todo cambio de esquema se escribe **primero** como archivo en `supabase/migrations/`.
   Nunca aplicar SQL suelto vía MCP sin dejar el archivo de migración correspondiente.
2. Validar localmente con `supabase db reset` antes de aplicar al proyecto remoto.
3. **Pedir confirmación humana** antes de aplicar al remoto y antes de hacer push a `main`.
4. Un commit por entidad o grupo lógico de entidades. No un commit gigante.
5. RLS habilitado en **todas** las tablas. Ninguna tabla queda expuesta sin políticas.

## Estado del entorno

- Proyecto de Supabase: ya existe (usar el MCP configurado con `project_ref`).
- Repositorio de GitHub: ya existe.
- Frontend: **no existe todavía.** El objetivo es un backend probable de forma independiente
  (SQL / API REST de Supabase), que después se conectará a prototipos hechos en Figma.
- Reconocimiento facial: **mockeado** en este prototipo (ver `docs/01_AUTENTICACION_Y_ROLES.md`).
