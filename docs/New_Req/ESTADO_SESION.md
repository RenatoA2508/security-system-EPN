# Estado del sistema al cierre de la ronda GPE + GPI

Sustituye al documento de la ronda de ADM. Punto de partida para la siguiente sesión.

## Dónde está todo

| Qué | Dónde |
|---|---|
| Rama de esta ronda | `feat/gpe-gpi-mejoras` — **sin PR abierto todavía** |
| Preview para revisar | el último `Preview` de `npx vercel ls` (pide sesión de Vercel) |
| Producción | https://security-system-epn.vercel.app (rama `main`) |
| Guía de revisión manual | `docs/New_Req/GUIA_REVISION_GPE_GPI.md` |
| Decisiones tomadas | `docs/03_DECISIONES_Y_CORRECCIONES.md` §D47-D52 |
| Dudas y pendientes | `docs/99_DUDAS_PARA_EL_EQUIPO.md` §V18-V21 |
| Requerimientos atendidos | `Requerimientos_GPE.docx`, `Requerimientos_GPI.docx` |

## Qué cambió

**Todo lo que pedían los dos documentos está implementado.** Resumen en
`GUIA_REVISION_GPE_GPI.md`, que es la lista con la que conviene hacer la revisión manual.

Además aparecieron **tres bugs que nadie había pedido arreglar**, y dos son serios:

1. **La fecha del sistema era la de UTC, no la de Ecuador** (§D52). `vista_vigencia_acceso`
   decide quién entra al campus y usaba `current_date`: a partir de las 19:00 hora local ya
   devolvía el día siguiente, así que **una autorización de visita para hoy dejaba de
   reconocerse y el visitante era denegado en la garita** durante las últimas cinco horas de
   cada jornada. Lo mismo con un memorando cuyo último día fuera hoy, en contra de §D24.
   Curiosamente la Edge Function de acceso ya lo hacía bien con `America/Guayaquil`, así que en
   un mismo ingreso la comprobación de horario usaba la hora local y la de vigencia la de UTC.
   No se había notado porque las pruebas manuales se hacen de día.
2. **`sincronizar_estado_memorandos` quedaba ejecutable por el rol `anon`**, y es SECURITY
   DEFINER: con la clave anónima —que va incrustada en el JavaScript y es pública— cualquiera
   podía reactivar memorandos vencidos. El `revoke from public` no bastaba.
3. **La integración de Vercel con Git nunca había funcionado** (§V21). Los despliegues que
   funcionaron eran todos manuales; el primero disparado por un push a `main` falló con
   `vite: command not found`. Corregido con `vercel.json` en la raíz (`docs/DESPLIEGUE.md`).

Y un cuarto, menor pero transversal: **ningún campo del formulario genérico asociaba su etiqueta
con el control**, así que un lector de pantalla no anunciaba de qué campo se trataba en ninguna
de esas pantallas.

## Cómo verificar

```bash
cd web && npm run verificar          # typecheck + 101 pruebas + build
psql "$DATABASE_URL" -f scripts/pruebas_gpe_gpi_nuevas.sql   # 18 casos, BEGIN … ROLLBACK
testsprite test run --all --project 25bd3dbb-b7dc-4688-8141-6f289513ea66   # backend
```

Las pruebas de frontend de TestSprite (20, de las cuales 10 nuevas) **no se han podido
ejecutar**: ver §V20. Las de backend sí, y pasan.

### Qué cubren las 101 pruebas automáticas

A las 8 tablas de la ronda anterior se suman:

| Archivo | Qué protege |
|---|---|
| `lib/vigencia.test.ts` | Estados calculados de memorandos y visitas, y que la fecha de referencia sea la de Ecuador incluso a las 19:30 |
| `components/ResourceScreen.test.tsx` | Campos dinámicos por categoría, estado en gris, confirmación de cambios sensibles y borrador de formularios |

## Piezas reutilizables nuevas

- `public.hoy_ecuador()` / `hoyISO()` — **usar siempre estas para "hoy"**. `current_date` y
  `toISOString()` mienten cinco horas al día.
- `public.estado_memorando_efectivo()` y `estado_autorizacion_efectivo()`, con espejo en
  `web/src/lib/vigencia.ts`. El patrón general: lo que depende del calendario se calcula, lo que
  depende de una decisión humana se almacena.
- `FieldConfig.soloLectura` + `valorCalculado` — campo en gris con un valor que calcula el
  sistema. `ResourceConfig.camposSensibles` — confirmación antes de guardar.
- `ListaSeleccionMultiple` — lista de casillas con buscador, dentro de `ResourceScreen`.
- `BuscarPersonaPorCedula` gana `soloTipo` (ámbito del módulo) y `onNoEncontrada` (para ofrecer
  el alta ahí mismo, como hace la garita).
- `AsociacionesVehiculo` está parametrizado por módulo: comprueba `{MODULO}_PERSONA_VEHICULO_*`.

## Lo que hace falta de una persona

1. **Desbloquear TestSprite para el preview** (§V20): una opción en el panel de Vercel.
2. **Decidir sobre §V18/§V19**: un docente sembrado tiene código único y carrera de estudiante.
3. **Abrir el PR** tras la revisión manual.
4. **Root Directory a `web` en el panel de Vercel** (§V21), y entonces borrar `vercel.json` de
   la raíz.

## Pendientes heredados (no bloquean)

1. **SMTP propio**: la recuperación de contraseña usa el correo de Supabase, 2 correos/hora.
2. **Fuerza bruta**: el conteo depende de que el intento pase por la Edge Function.
3. **SRI / ANT / Registro Civil**: sin integración.
4. **18 cédulas ficticias** pendientes de sustituir.
5. **Historial de migraciones**: sigue sin reconciliar, así que `supabase db push` no funciona y
   las migraciones se aplican una a una con el MCP (`apply_migration`), guardando después el
   archivo en `supabase/migrations/` con el `version_name` que devuelve `list_migrations`.
6. **Auto-refresco del token de TestSprite**: es de plan Pro.
