-- Datos de seguridad y catalogos base del Sistema de Seguridad EPN.
-- Fuente: docs/02_MATRIZ_PERMISOS_RLS.md (rol, permiso, rol_permiso),
-- docs/03_DECISIONES_Y_CORRECCIONES.md §D17 (parametro_sistema).
--
-- Va como MIGRACION (no como seed) porque es el modelo de permisos del que
-- dependen TODAS las politicas RLS: debe existir en cada entorno (local y
-- remoto) apenas se crea el esquema, no solo tras un `db reset`. Idempotente
-- via ON CONFLICT, se puede reaplicar sin efectos secundarios.

-- ================= ROL =================
insert into public.rol (nombre_rol, descripcion, estado_rol) values
  ('ADMINISTRADOR_SISTEMA', 'Seguridad logica: usuarios, roles, permisos, parametros, auditoria, catalogos maestros.', 'ACTIVO'),
  ('DIRECTOR_ADMINISTRATIVO', 'Consultas, reportes y auditoria. No modifica ningun dato.', 'ACTIVO'),
  ('RESPONSABLE_PERSONAL_INTERNO', 'Personal interno, biometria, asociaciones vehiculares.', 'ACTIVO'),
  ('RESPONSABLE_PERSONAL_EXTERNO', 'Personal externo, memorandos, autorizaciones, biometria de externos.', 'ACTIVO'),
  ('RESPONSABLE_PUNTOS_CONTROL', 'Zonas, puntos de control, dispositivos.', 'ACTIVO'),
  ('RESPONSABLE_CONTROL_ACCESOS', 'Reglas de acceso, supervision de eventos, atencion de alertas.', 'ACTIVO'),
  ('GUARDIA_SEGURIDAD', 'Operacion diaria: validaciones, entradas/salidas, visitas sin memorando.', 'ACTIVO')
on conflict (nombre_rol) do nothing;

-- ================= PERMISO =================
-- Formato MODULO_ENTIDAD_ACCION. El MODULO es desde donde actua el usuario,
-- no el dueño de la tabla (§D19) -- no renombrar/normalizar estos codigos.
insert into public.permiso (codigo_permiso, descripcion, estado_permiso) values
  ('ADM_MODULO_ACCEDER', 'Acceso al modulo ADM', 'ACTIVO'),
  ('GPI_MODULO_ACCEDER', 'Acceso al modulo GPI', 'ACTIVO'),
  ('GPE_MODULO_ACCEDER', 'Acceso al modulo GPE', 'ACTIVO'),
  ('PCO_MODULO_ACCEDER', 'Acceso al modulo PCO', 'ACTIVO'),
  ('CAC_MODULO_ACCEDER', 'Acceso al modulo CAC', 'ACTIVO'),

  ('ADM_USUARIO_SELECT', 'Consultar usuarios del sistema', 'ACTIVO'),
  ('ADM_USUARIO_INSERT', 'Crear usuarios del sistema', 'ACTIVO'),
  ('ADM_USUARIO_UPDATE', 'Actualizar usuarios del sistema', 'ACTIVO'),
  ('ADM_ROL_SELECT', 'Consultar roles', 'ACTIVO'),
  ('ADM_ROL_INSERT', 'Crear roles', 'ACTIVO'),
  ('ADM_ROL_UPDATE', 'Actualizar roles', 'ACTIVO'),
  ('ADM_PERMISO_SELECT', 'Consultar permisos', 'ACTIVO'),
  ('ADM_PERMISO_INSERT', 'Crear permisos', 'ACTIVO'),
  ('ADM_PERMISO_UPDATE', 'Actualizar permisos', 'ACTIVO'),
  ('ADM_USUARIO_ROL_SELECT', 'Consultar asignaciones de rol', 'ACTIVO'),
  ('ADM_USUARIO_ROL_INSERT', 'Asignar roles a usuarios', 'ACTIVO'),
  ('ADM_USUARIO_ROL_UPDATE', 'Actualizar/revocar asignaciones de rol', 'ACTIVO'),
  ('ADM_ROL_PERMISO_SELECT', 'Consultar matriz rol-permiso', 'ACTIVO'),
  ('ADM_ROL_PERMISO_INSERT', 'Asignar permisos a roles', 'ACTIVO'),
  ('ADM_ROL_PERMISO_UPDATE', 'Actualizar/revocar permisos de un rol', 'ACTIVO'),
  ('ADM_PARAMETRO_SELECT', 'Consultar parametros del sistema', 'ACTIVO'),
  ('ADM_PARAMETRO_INSERT', 'Crear parametros del sistema', 'ACTIVO'),
  ('ADM_PARAMETRO_UPDATE', 'Actualizar parametros del sistema', 'ACTIVO'),
  ('ADM_EMPRESA_SELECT', 'Consultar empresas', 'ACTIVO'),
  ('ADM_EMPRESA_INSERT', 'Crear empresas', 'ACTIVO'),
  ('ADM_EMPRESA_UPDATE', 'Actualizar empresas', 'ACTIVO'),
  ('ADM_CATEGORIA_SELECT', 'Consultar categorias de persona', 'ACTIVO'),
  ('ADM_CATEGORIA_INSERT', 'Crear categorias de persona', 'ACTIVO'),
  ('ADM_CATEGORIA_UPDATE', 'Actualizar categorias de persona', 'ACTIVO'),
  ('ADM_PERSONA_SELECT', 'Consultar personas', 'ACTIVO'),
  ('ADM_PERSONA_UPDATE', 'Actualizar/dar de baja personas (sin INSERT: §D5)', 'ACTIVO'),
  ('ADM_VEHICULO_SELECT', 'Consultar vehiculos', 'ACTIVO'),
  ('ADM_VEHICULO_INSERT', 'Crear vehiculos', 'ACTIVO'),
  ('ADM_VEHICULO_UPDATE', 'Actualizar vehiculos', 'ACTIVO'),
  ('ADM_PERSONA_VEHICULO_SELECT', 'Consultar relaciones persona-vehiculo', 'ACTIVO'),
  ('ADM_PERSONA_VEHICULO_INSERT', 'Crear relaciones persona-vehiculo', 'ACTIVO'),
  ('ADM_PERSONA_VEHICULO_UPDATE', 'Actualizar relaciones persona-vehiculo', 'ACTIVO'),
  ('ADM_BITACORA_SELECT', 'Consultar bitacora del sistema', 'ACTIVO'),
  ('ADM_BITACORA_EXPORTAR', 'Exportar bitacora del sistema', 'ACTIVO'),
  -- Codigo añadido en el bloque 4 (RLS): el PDF/matriz marca ADMIN=L (solo
  -- metadatos, footnote 4) en registro_biometrico pero el listado de codigos
  -- no definia ninguno ADM_* para esa tabla. Ver docs/99_DUDAS_PARA_EL_EQUIPO.md.
  ('ADM_BIOMETRIA_SELECT', 'Consultar metadatos de registro_biometrico (nunca el archivo)', 'ACTIVO'),

  ('GPI_PERSONA_SELECT', 'Consultar personal interno', 'ACTIVO'),
  ('GPI_PERSONA_INSERT', 'Crear personal interno', 'ACTIVO'),
  ('GPI_PERSONA_UPDATE', 'Actualizar personal interno', 'ACTIVO'),
  ('GPI_PERSONA_DETALLE_SELECT', 'Consultar detalle de personal interno', 'ACTIVO'),
  ('GPI_PERSONA_DETALLE_INSERT', 'Crear detalle de personal interno', 'ACTIVO'),
  ('GPI_PERSONA_DETALLE_UPDATE', 'Actualizar detalle de personal interno', 'ACTIVO'),
  ('GPI_BIOMETRIA_SELECT', 'Consultar registros biometricos', 'ACTIVO'),
  ('GPI_BIOMETRIA_INSERT', 'Enrolar biometria', 'ACTIVO'),
  ('GPI_BIOMETRIA_UPDATE', 'Actualizar registros biometricos', 'ACTIVO'),
  ('GPI_VEHICULO_SELECT', 'Consultar vehiculos (desde GPI)', 'ACTIVO'),
  ('GPI_VEHICULO_INSERT', 'Crear vehiculos (desde GPI)', 'ACTIVO'),
  ('GPI_PERSONA_VEHICULO_SELECT', 'Consultar relaciones persona-vehiculo (desde GPI)', 'ACTIVO'),
  ('GPI_PERSONA_VEHICULO_INSERT', 'Crear relaciones persona-vehiculo (desde GPI)', 'ACTIVO'),
  ('GPI_PERSONA_VEHICULO_UPDATE', 'Actualizar relaciones persona-vehiculo (desde GPI)', 'ACTIVO'),

  ('GPE_PERSONA_SELECT', 'Consultar personal externo', 'ACTIVO'),
  ('GPE_PERSONA_INSERT', 'Crear personal externo', 'ACTIVO'),
  ('GPE_PERSONA_UPDATE', 'Actualizar personal externo', 'ACTIVO'),
  ('GPE_MEMORANDO_SELECT', 'Consultar memorandos', 'ACTIVO'),
  ('GPE_MEMORANDO_INSERT', 'Crear memorandos', 'ACTIVO'),
  ('GPE_MEMORANDO_UPDATE', 'Actualizar memorandos', 'ACTIVO'),
  ('GPE_PERSONA_MEMORANDO_SELECT', 'Consultar personas asociadas a memorandos', 'ACTIVO'),
  ('GPE_PERSONA_MEMORANDO_INSERT', 'Asociar personas a memorandos', 'ACTIVO'),
  ('GPE_PERSONA_MEMORANDO_UPDATE', 'Actualizar asociaciones persona-memorando', 'ACTIVO'),
  ('GPE_AUTORIZACION_SELECT', 'Consultar autorizaciones de visita diaria (desde GPE)', 'ACTIVO'),
  ('GPE_AUTORIZACION_INSERT', 'Crear autorizaciones de visita diaria (desde GPE)', 'ACTIVO'),
  ('GPE_AUTORIZACION_UPDATE', 'Actualizar autorizaciones de visita diaria (desde GPE)', 'ACTIVO'),
  ('GPE_VEHICULO_SELECT', 'Consultar vehiculos (desde GPE)', 'ACTIVO'),
  ('GPE_VEHICULO_INSERT', 'Crear vehiculos (desde GPE)', 'ACTIVO'),
  ('GPE_PERSONA_VEHICULO_SELECT', 'Consultar relaciones persona-vehiculo (desde GPE)', 'ACTIVO'),
  ('GPE_PERSONA_VEHICULO_INSERT', 'Crear relaciones persona-vehiculo (desde GPE)', 'ACTIVO'),
  ('GPE_PERSONA_VEHICULO_UPDATE', 'Actualizar relaciones persona-vehiculo (desde GPE)', 'ACTIVO'),

  ('PCO_ZONA_SELECT', 'Consultar zonas', 'ACTIVO'),
  ('PCO_ZONA_INSERT', 'Crear zonas', 'ACTIVO'),
  ('PCO_ZONA_UPDATE', 'Actualizar zonas', 'ACTIVO'),
  ('PCO_PUNTO_CONTROL_SELECT', 'Consultar puntos de control', 'ACTIVO'),
  ('PCO_PUNTO_CONTROL_INSERT', 'Crear puntos de control', 'ACTIVO'),
  ('PCO_PUNTO_CONTROL_UPDATE', 'Actualizar puntos de control', 'ACTIVO'),
  ('PCO_DISPOSITIVO_SELECT', 'Consultar dispositivos', 'ACTIVO'),
  ('PCO_DISPOSITIVO_INSERT', 'Crear dispositivos', 'ACTIVO'),
  ('PCO_DISPOSITIVO_UPDATE', 'Actualizar dispositivos', 'ACTIVO'),
  ('PCO_ASIGNACION_SELECT', 'Consultar asignaciones guardia-punto (desde PCO)', 'ACTIVO'),
  ('PCO_ASIGNACION_INSERT', 'Crear asignaciones guardia-punto (desde PCO)', 'ACTIVO'),
  ('PCO_ASIGNACION_UPDATE', 'Actualizar asignaciones guardia-punto (desde PCO)', 'ACTIVO'),

  ('CAC_EVENTO_SELECT', 'Consultar eventos de acceso', 'ACTIVO'),
  ('CAC_EVENTO_INSERT', 'Registrar eventos de acceso manuales', 'ACTIVO'),
  ('CAC_EVENTO_SELECT_PUNTO_ASIGNADO', 'Consultar eventos del punto de control asignado (guardia)', 'ACTIVO'),
  ('CAC_ALERTA_SELECT', 'Consultar alertas de seguridad', 'ACTIVO'),
  ('CAC_ALERTA_ATENDER', 'Atender alertas de seguridad', 'ACTIVO'),
  ('CAC_REGLA_SELECT', 'Consultar reglas de acceso', 'ACTIVO'),
  ('CAC_REGLA_INSERT', 'Crear reglas de acceso', 'ACTIVO'),
  ('CAC_REGLA_UPDATE', 'Actualizar reglas de acceso', 'ACTIVO'),
  ('CAC_VALIDACION_EJECUTAR', 'Ejecutar la validacion de un acceso', 'ACTIVO'),
  ('CAC_PERSONA_EXTERNA_INSERT', 'Crear persona EXTERNA desde CAC (visitante sin cita, §D6)', 'ACTIVO'),
  ('CAC_AUTORIZACION_INSERT', 'Crear autorizaciones de visita diaria (desde CAC/guardia, §D3)', 'ACTIVO'),
  ('CAC_AUTORIZACION_UPDATE', 'Revocar autorizaciones de visita diaria (desde CAC/guardia)', 'ACTIVO'),
  -- Codigo añadido en el bloque 4: la matriz por tabla exige SELECT en
  -- autorizacion_visita_diaria para CAC y GUA (footnote 6), pero el listado
  -- original solo definia CAC_AUTORIZACION_INSERT/UPDATE, sin su SELECT.
  ('CAC_AUTORIZACION_SELECT', 'Consultar autorizaciones de visita diaria (desde CAC/guardia)', 'ACTIVO'),
  ('CAC_ASIGNACION_SELECT', 'Consultar asignaciones guardia-punto (desde CAC)', 'ACTIVO'),
  ('CAC_ASIGNACION_INSERT', 'Crear asignaciones guardia-punto (desde CAC)', 'ACTIVO'),
  ('CAC_ASIGNACION_UPDATE', 'Actualizar asignaciones guardia-punto (desde CAC)', 'ACTIVO'),
  ('CAC_ASIGNACION_SELECT_PROPIA', 'Consultar la propia asignacion de punto de control (guardia)', 'ACTIVO')
on conflict (codigo_permiso) do nothing;

-- ================= ROL_PERMISO =================
-- ADMINISTRADOR_SISTEMA: todos los ADM_* (incluye ADM_MODULO_ACCEDER).
insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
  from public.rol r
  join public.permiso p on p.codigo_permiso like 'ADM\_%' escape '\'
 where r.nombre_rol = 'ADMINISTRADOR_SISTEMA'
on conflict (id_rol, id_permiso) do nothing;

-- DIRECTOR_ADMINISTRATIVO: ADM_MODULO_ACCEDER + todos los *_SELECT + ADM_BITACORA_EXPORTAR.
-- Ningun _INSERT ni _UPDATE.
insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
  from public.rol r
  join public.permiso p on (
    p.codigo_permiso = 'ADM_MODULO_ACCEDER'
    or p.codigo_permiso = 'ADM_BITACORA_EXPORTAR'
    or right(p.codigo_permiso, 7) = '_SELECT'
  )
 where r.nombre_rol = 'DIRECTOR_ADMINISTRATIVO'
on conflict (id_rol, id_permiso) do nothing;

-- RESPONSABLE_PERSONAL_INTERNO: todos los GPI_*.
insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
  from public.rol r
  join public.permiso p on p.codigo_permiso like 'GPI\_%' escape '\'
 where r.nombre_rol = 'RESPONSABLE_PERSONAL_INTERNO'
on conflict (id_rol, id_permiso) do nothing;

-- RESPONSABLE_PERSONAL_EXTERNO: todos los GPE_*.
insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
  from public.rol r
  join public.permiso p on p.codigo_permiso like 'GPE\_%' escape '\'
 where r.nombre_rol = 'RESPONSABLE_PERSONAL_EXTERNO'
on conflict (id_rol, id_permiso) do nothing;

-- RESPONSABLE_PUNTOS_CONTROL: todos los PCO_*.
insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
  from public.rol r
  join public.permiso p on p.codigo_permiso like 'PCO\_%' escape '\'
 where r.nombre_rol = 'RESPONSABLE_PUNTOS_CONTROL'
on conflict (id_rol, id_permiso) do nothing;

-- RESPONSABLE_CONTROL_ACCESOS: todos los CAC_* excepto CAC_PERSONA_EXTERNA_INSERT
-- (excepcion explicita del documento) y, ademas -- segun la matriz tabla x
-- accion x rol (mas granular que el resumen "todos los CAC_*", y la fuente de
-- verdad declarada de RLS) -- excepto CAC_EVENTO_INSERT y
-- CAC_AUTORIZACION_INSERT/UPDATE: esas tres son insert/update exclusivos del
-- guardia (footnotes 6 y 9 de docs/02_MATRIZ_PERMISOS_RLS.md; el supervisor
-- CAC solo tiene L en evento_acceso y autorizacion_visita_diaria, no C/A).
-- Ver docs/99_DUDAS_PARA_EL_EQUIPO.md.
insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
  from public.rol r
  join public.permiso p on p.codigo_permiso like 'CAC\_%' escape '\'
   and p.codigo_permiso not in (
     'CAC_PERSONA_EXTERNA_INSERT', 'CAC_EVENTO_INSERT',
     'CAC_AUTORIZACION_INSERT', 'CAC_AUTORIZACION_UPDATE'
   )
 where r.nombre_rol = 'RESPONSABLE_CONTROL_ACCESOS'
on conflict (id_rol, id_permiso) do nothing;

-- GUARDIA_SEGURIDAD: lista explicita (docs/02_MATRIZ_PERMISOS_RLS.md).
-- Sin CAC_REGLA_* ni CAC_ASIGNACION_INSERT/UPDATE.
insert into public.rol_permiso (id_rol, id_permiso, estado_asignacion)
select r.id_rol, p.id_permiso, 'ACTIVO'
  from public.rol r
  join public.permiso p on p.codigo_permiso in (
    'CAC_MODULO_ACCEDER', 'CAC_VALIDACION_EJECUTAR', 'CAC_EVENTO_INSERT',
    'CAC_EVENTO_SELECT_PUNTO_ASIGNADO', 'CAC_ALERTA_SELECT', 'CAC_PERSONA_EXTERNA_INSERT',
    'CAC_AUTORIZACION_INSERT', 'CAC_AUTORIZACION_UPDATE', 'CAC_ASIGNACION_SELECT_PROPIA',
    'GPE_MEMORANDO_SELECT', 'GPE_PERSONA_MEMORANDO_SELECT', 'ADM_VEHICULO_SELECT',
    -- CAC_AUTORIZACION_SELECT: ver nota mas arriba (codigo añadido en bloque 4);
    -- footnote 6 exige "L C A" para el guardia en autorizacion_visita_diaria.
    'CAC_AUTORIZACION_SELECT'
  )
 where r.nombre_rol = 'GUARDIA_SEGURIDAD'
on conflict (id_rol, id_permiso) do nothing;

-- ================= CATEGORIA_PERSONA =================
insert into public.categoria_persona (codigo_categoria, nombre_categoria, ambito, estado) values
  ('DOCENTE', 'Docente', 'INTERNA', 'ACTIVO'),
  ('ESTUDIANTE', 'Estudiante', 'INTERNA', 'ACTIVO'),
  ('ADMINISTRATIVO', 'Administrativo', 'INTERNA', 'ACTIVO'),
  ('TRABAJADOR', 'Trabajador', 'INTERNA', 'ACTIVO'),
  ('EMPRESA_SERVICIO', 'Empresa de servicio', 'EXTERNA', 'ACTIVO'),
  ('VISITANTE', 'Visitante', 'EXTERNA', 'ACTIVO'),
  ('PROVEEDOR', 'Proveedor', 'EXTERNA', 'ACTIVO'),
  ('CONTRATISTA', 'Contratista', 'EXTERNA', 'ACTIVO'),
  ('CONDUCTOR', 'Conductor de empresa de transporte/servicio externo', 'EXTERNA', 'ACTIVO')
on conflict (codigo_categoria) do nothing;

-- ================= PARAMETRO_SISTEMA (§D17) =================
insert into public.parametro_sistema (
  codigo_parametro, nombre_parametro, descripcion, modulo_aplicacion, tipo_dato, valor_parametro, estado_parametro, editable
) values
  ('MAX_INTENTOS_LOGIN', 'Maximo de intentos de login', 'Intentos fallidos antes de bloquear la cuenta', 'AUTENTICACION', 'ENTERO', '5', 'ACTIVO', true),
  ('TIEMPO_BLOQUEO_CUENTA_MIN', 'Tiempo de bloqueo de cuenta (min)', 'Minutos que la cuenta permanece bloqueada tras exceder los intentos', 'AUTENTICACION', 'ENTERO', '15', 'ACTIVO', true),
  ('TIEMPO_SESION_MIN', 'Tiempo de sesion (min)', 'Documenta el timeout de inactividad; lo aplica Supabase Auth nativamente (§D10)', 'SESION', 'ENTERO', '60', 'ACTIVO', true),
  ('UMBRAL_BIOMETRIA', 'Umbral de confianza biometrica', 'Confidence minimo para aceptar una coincidencia facial', 'SEGURIDAD', 'DECIMAL', '0.85', 'ACTIVO', true),
  ('PERMANENCIA_MAX_INTERNO_H', 'Permanencia maxima vehiculo - conductor interno (h)', 'Limite de permanencia de un vehiculo cuyo conductor es personal interno activo', 'SEGURIDAD', 'ENTERO', '16', 'ACTIVO', true),
  ('PERMANENCIA_MAX_EXTERNO_H', 'Permanencia maxima vehiculo - conductor externo con memorando (h)', 'Limite de permanencia de un vehiculo cuyo conductor es externo con memorando', 'SEGURIDAD', 'ENTERO', '12', 'ACTIVO', true),
  ('PERMANENCIA_MAX_VISITA_H', 'Permanencia maxima vehiculo - visita diaria (h)', 'Limite de permanencia de un vehiculo cuyo conductor tiene autorizacion de visita diaria', 'SEGURIDAD', 'ENTERO', '4', 'ACTIVO', true),
  ('PERMANENCIA_ABANDONO_H', 'Permanencia de abandono vehicular (h)', 'Umbral a partir del cual se considera un vehiculo abandonado', 'SEGURIDAD', 'ENTERO', '72', 'ACTIVO', true)
on conflict (codigo_parametro) do nothing;

