# 04 — Reglas de Negocio

> **Estado: TODAS RESUELTAS.** No queda ninguna regla pendiente de decisión.
> Este documento es el índice: dice dónde vive la decisión final de cada regla, y resume el
> flujo completo de acceso.

Si aparece una regla nueva sin decidir, **se documenta aquí y se pregunta al equipo** — nunca
se inventa en una sesión de código.

---

| # | Regla | Estado | Decisión final |
|---|---|---|---|
| P1 | Bloqueo por intentos fallidos de login | ✅ | §D17 — `MAX_INTENTOS_LOGIN = 5`, `TIEMPO_BLOQUEO_CUENTA_MIN = 15` |
| P2 | Duración de sesión | ✅ | §D10 — inactividad 60 min + time-box 12 h, nativos de Supabase |
| P3 | Vigencia temporal (memorando vencido a mitad de día) | ✅ | §D24 — `fecha_fin` inclusiva; solo se valida en el INGRESO |
| P4 | Prioridad entre reglas de acceso solapadas | ✅ | §D24 — gana la más específica; si empatan, la más restrictiva |
| P5 | Asignación de guardia → punto de control | ✅ | §D11 — nueva tabla `guardia_punto_control` (25.ª entidad) |
| P6 | Salida por el mismo punto de control | ✅ | §D23 — solo visitantes con autorización diaria; DENEGADO + 2 válvulas de escape |
| P7 | Umbral de confianza del reconocimiento facial | ✅ | §D17 — `UMBRAL_BIOMETRIA = 0.85`, sin zona gris |
| P8 | Validación de acceso vehicular | ✅ | §D22 — la placa autoriza al vehículo; biometría/cédula autoriza a cada ocupante |
| P9 | Permanencia máxima de un vehículo en el campus | ✅ | §D25 — 16 h interno / 12 h externo / 4 h visita / 72 h abandono; alerta informativa |

Las referencias `§D#` apuntan a `03_DECISIONES_Y_CORRECCIONES.md`.

---

## Resumen operativo: el flujo completo de acceso

Para que Claude Code no tenga que reconstruirlo leyendo 24 decisiones sueltas.

### Ingreso peatonal — persona **INTERNA**
1. El dispositivo captura el rostro → Edge Function `validar-biometria` (mock).
2. Si `confidence >= UMBRAL_BIOMETRIA` (0.85) → identidad confirmada.
3. Se consulta la vista de vigencia: `persona.estado = 'ACTIVO'`.
4. Se evalúa `regla_acceso` (categoría + punto + horario). Si dos reglas solapan, gana la más
   específica; si empatan, la más restrictiva.
5. Se inserta `evento_acceso` con `origen_registro = 'AUTOMATICA'`.
6. Si `DENEGADO` → se genera `alerta_seguridad` automáticamente (trigger).

### Ingreso peatonal — persona **EXTERNA**
1. El **guardia teclea la cédula** → se busca en `persona.cedula` (necesita índice).
2. Se consulta la vista de vigencia: memorando vigente (vía `persona_memorando`) **o**
   `autorizacion_visita_diaria` de hoy.
3. Se evalúa `regla_acceso`.
4. Se inserta `evento_acceso` con `origen_registro = 'MANUAL'`.
5. **Nunca se consulta biometría** — los externos no tienen registro biométrico (§D20).

### Ingreso **vehicular**
1. El LPR lee la **placa** → valida que el `vehiculo` esté `ACTIVO`.
   **La placa autoriza al vehículo, no a las personas.** Una placa no es una credencial.
2. **Cada ocupante se valida individualmente** por su vía correspondiente
   (interno → biometría; externo → cédula ante el guardia).
3. Se genera **un `evento_acceso` por ocupante**, todos con el mismo `id_vehiculo`,
   `id_punto_control` y `fecha_hora`. El conductor lleva `es_conductor = true`.
4. Un pasajero **no necesita** estar en `persona_vehiculo`.
5. **Si cualquier ocupante es DENEGADO → el vehículo completo es DENEGADO.** Todos los eventos
   se registran con su resultado real. El guardia resuelve manualmente.
6. Un mismo vehículo puede llevar ocupantes de ambas vías (conductor interno `AUTOMATICA` +
   proveedores externos `MANUAL`). Es válido.

### **Salida**
1. La vigencia **nunca** se revalida: una `SALIDA` no se deniega por memorando vencido.
2. **Solo** para visitantes con `autorizacion_visita_diaria`: debe salir por el **mismo punto**
   por el que ingresó. Si no → `DENEGADO` + alerta `PUNTO_SALIDA_INCORRECTO`.
   No aplica a externos con memorando ni a personal interno.
3. **Válvula 1:** si el punto de ingreso tiene `estado_punto != 'ACTIVO'` (FALLA/MANTENIMIENTO)
   → se **autoriza** la salida por otro punto, con alerta.
4. **Válvula 2:** el guardia siempre puede forzar una salida `MANUAL` con justificación en
   `motivo_resultado`, generando alerta. **Nunca se construye un sistema de egreso físico sin
   override manual** (evacuaciones, emergencias).

### **Permanencia de vehículos** (§D25)

No es un flujo de acceso: es un **proceso en segundo plano**. Es la única regla del sistema que
se dispara por **la ausencia** de un evento (la salida que nunca llegó), no por su ocurrencia.

1. La vista `vista_vehiculos_dentro` calcula, para cada `id_vehiculo`, el tiempo transcurrido
   desde su último `INGRESO` `AUTORIZADO` sin `SALIDA` posterior.
2. El límite aplicable depende del **conductor** (`es_conductor = true`) de ese ingreso:

   | Conductor | Parámetro | Valor |
   |---|---|---|
   | `INTERNA` activo | `PERMANENCIA_MAX_INTERNO_H` | 16 h |
   | `EXTERNA` con memorando | `PERMANENCIA_MAX_EXTERNO_H` | 12 h |
   | Visita diaria | `PERMANENCIA_MAX_VISITA_H` | 4 h |
   | Cualquiera | `PERMANENCIA_ABANDONO_H` | 72 h |

3. Un job **`pg_cron` cada hora** revisa la vista y genera alertas:
   - Excedido el límite → `VEHICULO_PERMANENCIA_EXCEDIDA`, `nivel_riesgo = MEDIO`.
   - Superadas 72 h → `VEHICULO_ABANDONADO`, `nivel_riesgo = ALTO`.
   - La alerta apunta al `evento_acceso` de **INGRESO** que nunca recibió salida.
   - **Idempotente:** no generar una alerta nueva cada hora para el mismo vehículo.

4. **La alerta es informativa, NO bloqueante.** No se deniega la salida ni se suspende el
   vehículo. El Supervisor CAC la atiende y la marca `ATENDIDA` si el caso es legítimo
   (ej. un contratista autorizado a dejar maquinaria durante una obra).

**Intención:** lo que se detecta no es "estuvo mucho rato", es **"se quedó a dormir"**. 16 h
cubren una jornada de 06:00 a 22:00, clases nocturnas incluidas.
