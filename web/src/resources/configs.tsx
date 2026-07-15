import type { ResourceConfig } from './types'
import { CAT } from '../lib/catalogos'
import { fmtFecha, fmtFechaHora, fmtHora } from '../lib/format'
import { Badge } from '../components/ui'
import {
  opcionesCatalogo, optCategorias, optEmpresas, optPuntosControl, optZonas, optRoles,
  opcionesTabla,
} from './opciones'
import { hoyISO } from '../lib/format'

const d = (v: any) => (v == null || v === '' ? '—' : String(v))

/* =========================================================================
   ADM — entidades maestras y seguridad lógica
   ========================================================================= */

export const cfgEmpresa: ResourceConfig = {
  tabla: 'empresa',
  titulo: 'Empresas',
  singular: 'Empresa',
  idField: 'id_empresa',
  orderBy: { columna: 'nombre' },
  permisos: { select: ['ADM_EMPRESA_SELECT'], insert: ['ADM_EMPRESA_INSERT'], update: ['ADM_EMPRESA_UPDATE'] },
  buscarEn: ['nombre', 'ruc', 'tipo_servicio'],
  columnas: [
    { key: 'nombre', label: 'Nombre' },
    { key: 'ruc', label: 'RUC', render: (r) => d(r.ruc) },
    { key: 'tipo_servicio', label: 'Tipo de servicio', render: (r) => d(r.tipo_servicio) },
    { key: 'estado', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre,
  campoSubtituloDetalle: (r) => <Badge value={r.estado} />,
  detalle: [
    { label: 'RUC', render: (r) => d(r.ruc) },
    { label: 'Tipo de servicio', render: (r) => d(r.tipo_servicio) },
    { label: 'Registro', render: (r) => fmtFecha(r.fecha_registro) },
  ],
  campos: [
    { name: 'nombre', label: 'Nombre', required: true, colSpan: 2 },
    { name: 'ruc', label: 'RUC' },
    { name: 'tipo_servicio', label: 'Tipo de servicio' },
    { name: 'estado', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.empresa_estado), default: 'ACTIVO', editable: true },
  ],
  campoEstado: 'estado',
  baja: { campoEstado: 'estado', valorBaja: 'INACTIVO', etiqueta: 'Inactivar' },
}

export const cfgCategoria: ResourceConfig = {
  tabla: 'categoria_persona',
  titulo: 'Categorías de persona',
  singular: 'Categoría',
  idField: 'id_categoria',
  orderBy: { columna: 'codigo_categoria' },
  permisos: { select: ['ADM_CATEGORIA_SELECT'], insert: ['ADM_CATEGORIA_INSERT'], update: ['ADM_CATEGORIA_UPDATE'] },
  buscarEn: ['nombre_categoria', 'codigo_categoria'],
  columnas: [
    { key: 'codigo_categoria', label: 'Código' },
    { key: 'nombre_categoria', label: 'Nombre' },
    { key: 'ambito', label: 'Ámbito', badge: true },
    { key: 'estado', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre_categoria,
  campoSubtituloDetalle: (r) => <><Badge value={r.codigo_categoria} /> <Badge value={r.ambito} /></>,
  detalle: [
    { label: 'Código', render: (r) => r.codigo_categoria },
    { label: 'Ámbito', render: (r) => <Badge value={r.ambito} /> },
    { label: 'Estado', render: (r) => <Badge value={r.estado} /> },
  ],
  campos: [
    { name: 'codigo_categoria', label: 'Código', type: 'select', required: true, options: opcionesCatalogo(CAT.categoria_codigo), editable: false },
    { name: 'nombre_categoria', label: 'Nombre', required: true },
    { name: 'ambito', label: 'Ámbito', type: 'select', required: true, options: opcionesCatalogo(CAT.categoria_ambito), editable: false },
    { name: 'estado', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.categoria_estado), default: 'ACTIVO' },
  ],
  campoEstado: 'estado',
  baja: { campoEstado: 'estado', valorBaja: 'INACTIVO', etiqueta: 'Inactivar' },
}

export const cfgParametro: ResourceConfig = {
  tabla: 'parametro_sistema',
  titulo: 'Parámetros del sistema',
  singular: 'Parámetro',
  idField: 'id_parametro',
  orderBy: { columna: 'codigo_parametro' },
  permisos: { select: ['ADM_PARAMETRO_SELECT'], insert: ['ADM_PARAMETRO_INSERT'], update: ['ADM_PARAMETRO_UPDATE'] },
  buscarEn: ['codigo_parametro', 'nombre_parametro', 'modulo_aplicacion'],
  columnas: [
    { key: 'codigo_parametro', label: 'Código' },
    { key: 'nombre_parametro', label: 'Nombre' },
    { key: 'valor_parametro', label: 'Valor' },
    { key: 'modulo_aplicacion', label: 'Módulo' },
    { key: 'estado_parametro', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre_parametro,
  campoSubtituloDetalle: (r) => <><code className="text-xs">{r.codigo_parametro}</code> · <Badge value={r.estado_parametro} /></>,
  detalle: [
    { label: 'Valor', render: (r) => <b>{r.valor_parametro}</b> },
    { label: 'Tipo de dato', render: (r) => r.tipo_dato },
    { label: 'Módulo', render: (r) => r.modulo_aplicacion },
    { label: 'Editable', render: (r) => (r.editable ? 'Sí' : 'No') },
    { label: 'Descripción', render: (r) => d(r.descripcion) },
    { label: 'Modificado', render: (r) => fmtFechaHora(r.fecha_modificacion) },
  ],
  campos: [
    { name: 'codigo_parametro', label: 'Código', required: true, editable: false, colSpan: 2 },
    { name: 'nombre_parametro', label: 'Nombre', required: true, colSpan: 2 },
    { name: 'valor_parametro', label: 'Valor', required: true },
    { name: 'tipo_dato', label: 'Tipo de dato', type: 'select', required: true, options: opcionesCatalogo(CAT.parametro_tipo_dato) },
    { name: 'modulo_aplicacion', label: 'Módulo', type: 'select', required: true, options: opcionesCatalogo(CAT.parametro_modulo) },
    { name: 'estado_parametro', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.parametro_estado), default: 'ACTIVO' },
    { name: 'editable', label: '¿Editable?', type: 'checkbox', default: true },
    { name: 'descripcion', label: 'Descripción', type: 'textarea', colSpan: 3 },
  ],
}

export const cfgRol: ResourceConfig = {
  tabla: 'rol',
  titulo: 'Roles',
  singular: 'Rol',
  idField: 'id_rol',
  orderBy: { columna: 'nombre_rol' },
  permisos: { select: ['ADM_ROL_SELECT'], insert: ['ADM_ROL_INSERT'], update: ['ADM_ROL_UPDATE'] },
  buscarEn: ['nombre_rol', 'descripcion'],
  columnas: [
    { key: 'nombre_rol', label: 'Nombre del rol' },
    { key: 'descripcion', label: 'Descripción', render: (r) => d(r.descripcion) },
    { key: 'estado_rol', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre_rol,
  campoSubtituloDetalle: (r) => <Badge value={r.estado_rol} />,
  detalle: [
    { label: 'Descripción', render: (r) => d(r.descripcion) },
    { label: 'Estado', render: (r) => <Badge value={r.estado_rol} /> },
  ],
  campos: [
    { name: 'nombre_rol', label: 'Nombre del rol', type: 'select', required: true, options: opcionesCatalogo(CAT.rol_nombre), editable: false, colSpan: 2 },
    { name: 'descripcion', label: 'Descripción', type: 'textarea', colSpan: 3 },
    { name: 'estado_rol', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.categoria_estado), default: 'ACTIVO' },
  ],
}

export const cfgPermiso: ResourceConfig = {
  tabla: 'permiso',
  titulo: 'Permisos',
  singular: 'Permiso',
  idField: 'id_permiso',
  orderBy: { columna: 'codigo_permiso' },
  permisos: { select: ['ADM_PERMISO_SELECT'], insert: ['ADM_PERMISO_INSERT'], update: ['ADM_PERMISO_UPDATE'] },
  buscarEn: ['codigo_permiso', 'descripcion'],
  columnas: [
    { key: 'codigo_permiso', label: 'Código' },
    { key: 'descripcion', label: 'Descripción', render: (r) => d(r.descripcion) },
    { key: 'estado_permiso', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.codigo_permiso,
  detalle: [
    { label: 'Descripción', render: (r) => d(r.descripcion) },
    { label: 'Estado', render: (r) => <Badge value={r.estado_permiso} /> },
  ],
  campos: [
    { name: 'codigo_permiso', label: 'Código', required: true, editable: false, colSpan: 2, hint: 'Formato MODULO_ENTIDAD_ACCION' },
    { name: 'descripcion', label: 'Descripción', type: 'textarea', colSpan: 3 },
    { name: 'estado_permiso', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.categoria_estado), default: 'ACTIVO' },
  ],
}

export const cfgUsuarioRol: ResourceConfig = {
  tabla: 'usuario_rol',
  titulo: 'Asignaciones de rol',
  singular: 'Asignación',
  idField: 'id_usuario_rol',
  select: '*, usuario:usuario_sistema(nombre_usuario, correo_electronico), rol:rol(nombre_rol)',
  permisos: { select: ['ADM_USUARIO_ROL_SELECT'], insert: ['ADM_USUARIO_ROL_INSERT'], update: ['ADM_USUARIO_ROL_UPDATE'] },
  buscarEn: ['usuario.nombre_usuario', 'usuario.correo_electronico', 'rol.nombre_rol'],
  columnas: [
    { key: 'usuario', label: 'Usuario', render: (r) => r.usuario?.correo_electronico ?? d(r.id_usuario) },
    { key: 'rol', label: 'Rol', render: (r) => r.rol?.nombre_rol ?? '—' },
    { key: 'estado_asignacion', label: 'Estado', badge: true },
    { key: 'fecha_asignacion', label: 'Asignado', render: (r) => fmtFecha(r.fecha_asignacion) },
  ],
  campoTituloDetalle: (r) => r.rol?.nombre_rol ?? 'Asignación',
  campoSubtituloDetalle: (r) => r.usuario?.correo_electronico,
  detalle: [
    { label: 'Usuario', render: (r) => r.usuario?.correo_electronico ?? d(r.id_usuario) },
    { label: 'Rol', render: (r) => r.rol?.nombre_rol },
    { label: 'Estado', render: (r) => <Badge value={r.estado_asignacion} /> },
    { label: 'Observación', render: (r) => d(r.observacion) },
  ],
  campos: [
    { name: 'id_usuario', label: 'Usuario', type: 'select', required: true, editable: false, options: opcionesTabla('usuario_sistema', 'id_usuario', (u) => u.correo_electronico) },
    { name: 'id_rol', label: 'Rol', type: 'select', required: true, editable: false, options: optRoles },
    { name: 'estado_asignacion', label: 'Estado', type: 'select', options: opcionesCatalogo(['ACTIVO', 'REVOCADO']), default: 'ACTIVO' },
    { name: 'observacion', label: 'Observación', type: 'textarea', colSpan: 3 },
  ],
  baja: { campoEstado: 'estado_asignacion', valorBaja: 'REVOCADO', etiqueta: 'Revocar rol' },
}

export const cfgUsuario: ResourceConfig = {
  tabla: 'usuario_sistema',
  titulo: 'Usuarios del sistema',
  singular: 'Usuario',
  idField: 'id_usuario',
  select: '*, persona:persona!usuario_sistema_id_persona_fkey(nombres, apellidos, cedula)',
  orderBy: { columna: 'nombre_usuario' },
  // El alta de usuarios usa Supabase Auth (Admin API), no un INSERT REST (01 §2/§D12).
  // Desde el frontend ADM solo lista/consulta y actualiza estado. Ver docs/99_DUDAS_FRONTEND.md.
  permisos: { select: ['ADM_USUARIO_SELECT'], update: ['ADM_USUARIO_UPDATE'] },
  buscarEn: ['nombre_usuario', 'correo_electronico', 'persona.cedula'],
  columnas: [
    { key: 'nombre_usuario', label: 'Usuario' },
    { key: 'correo_electronico', label: 'Correo' },
    { key: 'persona', label: 'Persona', render: (r) => (r.persona ? `${r.persona.nombres} ${r.persona.apellidos}` : '—') },
    { key: 'estado_usuario', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre_usuario,
  campoSubtituloDetalle: (r) => r.correo_electronico,
  detalle: [
    { label: 'Persona', render: (r) => (r.persona ? `${r.persona.nombres} ${r.persona.apellidos}` : '—') },
    { label: 'Cédula', render: (r) => d(r.persona?.cedula) },
    { label: 'Estado', render: (r) => <Badge value={r.estado_usuario} /> },
    { label: 'Requiere cambio de contraseña', render: (r) => (r.requiere_cambio_password ? 'Sí' : 'No') },
    { label: 'Último login', render: (r) => fmtFechaHora(r.fecha_ultimo_login) },
    { label: 'Intentos fallidos', render: (r) => r.intentos_fallidos },
  ],
  campos: [
    { name: 'estado_usuario', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.usuario_estado) },
  ],
  campoEstado: 'estado_usuario',
}

/* =========================================================================
   Compartidos: vehículo, persona_vehiculo (ADM/GPI/GPE)
   ========================================================================= */

export function cfgVehiculo(modulo: 'ADM' | 'GPI' | 'GPE'): ResourceConfig {
  const select = [`${modulo}_VEHICULO_SELECT`]
  const insert = [`${modulo}_VEHICULO_INSERT`]
  // Solo ADM puede UPDATE / dar de baja el vehículo (matriz doc 02, nota ³).
  const update = modulo === 'ADM' ? ['ADM_VEHICULO_UPDATE'] : undefined
  return {
    tabla: 'vehiculo',
    titulo: 'Vehículos',
    singular: 'Vehículo',
    idField: 'id_vehiculo',
    orderBy: { columna: 'placa' },
    permisos: { select, insert, update },
    autoUsuarioRegistro: ['id_usuario_registro'],
    buscarEn: ['placa', 'marca', 'modelo', 'color'],
    columnas: [
      { key: 'placa', label: 'Placa', render: (r) => d(r.placa) },
      { key: 'tipo_vehiculo', label: 'Tipo' },
      { key: 'marca', label: 'Marca', render: (r) => d(r.marca) },
      { key: 'modelo', label: 'Modelo', render: (r) => d(r.modelo) },
      { key: 'estado_vehiculo', label: 'Estado', badge: true },
    ],
    campoTituloDetalle: (r) => r.placa ?? 'Vehículo',
    campoSubtituloDetalle: (r) => <><Badge value={r.tipo_vehiculo} /> <Badge value={r.estado_vehiculo} /></>,
    detalle: [
      { label: 'Marca / Modelo', render: (r) => `${d(r.marca)} ${d(r.modelo)}` },
      { label: 'Color', render: (r) => d(r.color) },
      { label: 'Registro', render: (r) => fmtFecha(r.fecha_registro) },
    ],
    campos: [
      { name: 'placa', label: 'Placa', colSpan: 1 },
      { name: 'tipo_vehiculo', label: 'Tipo', type: 'select', required: true, options: opcionesCatalogo(CAT.vehiculo_tipo) },
      { name: 'marca', label: 'Marca' },
      { name: 'modelo', label: 'Modelo' },
      { name: 'color', label: 'Color' },
      { name: 'estado_vehiculo', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.vehiculo_estado), default: 'ACTIVO', editable: modulo === 'ADM' },
    ],
    campoEstado: 'estado_vehiculo',
    baja: update ? { campoEstado: 'estado_vehiculo', valorBaja: 'DADO_DE_BAJA', etiqueta: 'Dar de baja' } : undefined,
  }
}

export function cfgPersonaVehiculo(modulo: 'ADM' | 'GPI' | 'GPE'): ResourceConfig {
  return {
    tabla: 'persona_vehiculo',
    titulo: 'Asociaciones persona–vehículo',
    singular: 'Asociación',
    idField: 'id_persona_vehiculo',
    select: '*, persona:persona(nombres, apellidos, cedula), vehiculo:vehiculo(placa, tipo_vehiculo)',
    permisos: {
      select: [`${modulo}_PERSONA_VEHICULO_SELECT`],
      insert: [`${modulo}_PERSONA_VEHICULO_INSERT`],
      update: [`${modulo}_PERSONA_VEHICULO_UPDATE`],
    },
    autoUsuarioRegistro: ['id_usuario_registro'],
    buscarEn: ['persona.cedula', 'persona.apellidos', 'vehiculo.placa'],
    columnas: [
      { key: 'persona', label: 'Persona', render: (r) => (r.persona ? `${r.persona.nombres} ${r.persona.apellidos}` : '—') },
      { key: 'vehiculo', label: 'Vehículo', render: (r) => r.vehiculo?.placa ?? '—' },
      { key: 'tipo_relacion', label: 'Relación' },
      { key: 'estado_relacion', label: 'Estado', badge: true },
    ],
    campoTituloDetalle: (r) => (r.persona ? `${r.persona.nombres} ${r.persona.apellidos}` : 'Asociación'),
    campoSubtituloDetalle: (r) => <>Vehículo {r.vehiculo?.placa ?? '—'} · <Badge value={r.tipo_relacion} /></>,
    detalle: [
      { label: 'Cédula', render: (r) => d(r.persona?.cedula) },
      { label: 'Vehículo', render: (r) => `${d(r.vehiculo?.placa)} (${d(r.vehiculo?.tipo_vehiculo)})` },
      { label: 'Responsable de trámite', render: (r) => (r.es_responsable_tramite ? 'Sí' : 'No') },
      { label: 'Vigencia', render: (r) => `${fmtFecha(r.fecha_inicio)} → ${r.fecha_fin ? fmtFecha(r.fecha_fin) : 'indefinida'}` },
    ],
    campos: [
      { name: 'id_persona', label: 'Persona', type: 'select', required: true, editable: false, options: opcionesTabla('persona', 'id_persona', (p) => `${p.apellidos} ${p.nombres} · ${p.cedula}`) },
      { name: 'id_vehiculo', label: 'Vehículo', type: 'select', required: true, editable: false, options: opcionesTabla('vehiculo', 'id_vehiculo', (v) => `${v.placa ?? v.id_vehiculo} · ${v.tipo_vehiculo}`) },
      { name: 'tipo_relacion', label: 'Tipo de relación', type: 'select', required: true, options: opcionesCatalogo(CAT.persona_vehiculo_tipo) },
      { name: 'es_responsable_tramite', label: '¿Responsable del trámite?', type: 'checkbox' },
      { name: 'fecha_inicio', label: 'Inicio', type: 'date', required: true },
      { name: 'fecha_fin', label: 'Fin (opcional)', type: 'date' },
      { name: 'estado_relacion', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.persona_vehiculo_estado), default: 'ACTIVA' },
    ],
    campoEstado: 'estado_relacion',
    baja: { campoEstado: 'estado_relacion', valorBaja: 'REVOCADA', campoMotivo: 'motivo_revocacion', etiqueta: 'Revocar' },
  }
}

/* =========================================================================
   PCO — infraestructura física
   ========================================================================= */

export const cfgZona: ResourceConfig = {
  tabla: 'zona',
  titulo: 'Zonas',
  singular: 'Zona',
  idField: 'id_zona',
  // Auto-join: PostgREST resuelve el embed por columna FK directamente (padre:columna(...)),
  // el hint de nombre de constraint falla para relaciones autorreferenciadas en esta versión.
  select: '*, padre:id_zona_padre(nombre_zona)',
  orderBy: { columna: 'nombre_zona' },
  permisos: { select: ['PCO_ZONA_SELECT'], insert: ['PCO_ZONA_INSERT'], update: ['PCO_ZONA_UPDATE'] },
  buscarEn: ['nombre_zona', 'tipo_zona'],
  columnas: [
    { key: 'nombre_zona', label: 'Nombre' },
    { key: 'tipo_zona', label: 'Tipo', badge: true },
    { key: 'padre', label: 'Zona padre', render: (r) => r.padre?.nombre_zona ?? '—' },
    { key: 'estado_zona', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre_zona,
  campoSubtituloDetalle: (r) => <Badge value={r.tipo_zona} />,
  detalle: [
    { label: 'Zona padre', render: (r) => r.padre?.nombre_zona ?? '—' },
    { label: 'Estado', render: (r) => <Badge value={r.estado_zona} /> },
    { label: 'Registro', render: (r) => fmtFecha(r.fecha_registro) },
  ],
  campos: [
    { name: 'nombre_zona', label: 'Nombre', required: true, colSpan: 2 },
    { name: 'tipo_zona', label: 'Tipo', type: 'select', required: true, options: opcionesCatalogo(CAT.zona_tipo) },
    { name: 'id_zona_padre', label: 'Zona padre (opcional)', type: 'select', options: optZonas },
    { name: 'estado_zona', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.zona_estado), default: 'ACTIVA' },
  ],
  campoEstado: 'estado_zona',
  baja: { campoEstado: 'estado_zona', valorBaja: 'INACTIVA', etiqueta: 'Inactivar' },
}

export const cfgPuntoControl: ResourceConfig = {
  tabla: 'punto_control',
  titulo: 'Puntos de control',
  singular: 'Punto de control',
  idField: 'id_punto_control',
  select: '*, zona:zona(nombre_zona)',
  orderBy: { columna: 'nombre_punto' },
  permisos: { select: ['PCO_PUNTO_CONTROL_SELECT'], insert: ['PCO_PUNTO_CONTROL_INSERT'], update: ['PCO_PUNTO_CONTROL_UPDATE'] },
  buscarEn: ['nombre_punto'],
  columnas: [
    { key: 'nombre_punto', label: 'Nombre' },
    { key: 'zona', label: 'Zona', render: (r) => r.zona?.nombre_zona ?? '—' },
    { key: 'estado_punto', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre_punto,
  campoSubtituloDetalle: (r) => <Badge value={r.estado_punto} />,
  detalle: [
    { label: 'Zona', render: (r) => r.zona?.nombre_zona ?? '—' },
    { label: 'Estado', render: (r) => <Badge value={r.estado_punto} /> },
    { label: 'Registro', render: (r) => fmtFecha(r.fecha_registro) },
  ],
  campos: [
    { name: 'nombre_punto', label: 'Nombre', required: true, colSpan: 2 },
    { name: 'id_zona', label: 'Zona', type: 'select', required: true, options: optZonas },
    { name: 'estado_punto', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.punto_estado), default: 'ACTIVO' },
  ],
  campoEstado: 'estado_punto',
}

export const cfgDispositivo: ResourceConfig = {
  tabla: 'dispositivo',
  titulo: 'Dispositivos',
  singular: 'Dispositivo',
  idField: 'id_dispositivo',
  select: '*, punto:punto_control(nombre_punto)',
  permisos: { select: ['PCO_DISPOSITIVO_SELECT'], insert: ['PCO_DISPOSITIVO_INSERT'], update: ['PCO_DISPOSITIVO_UPDATE'] },
  buscarEn: ['codigo_mac', 'direccion_ip', 'tipo_tecnologia'],
  columnas: [
    { key: 'codigo_mac', label: 'MAC' },
    { key: 'direccion_ip', label: 'IP' },
    { key: 'tipo_tecnologia', label: 'Tecnología' },
    { key: 'punto', label: 'Punto', render: (r) => r.punto?.nombre_punto ?? '—' },
    { key: 'estado_dispositivo', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.codigo_mac,
  campoSubtituloDetalle: (r) => <Badge value={r.estado_dispositivo} />,
  detalle: [
    { label: 'IP', render: (r) => r.direccion_ip },
    { label: 'Tecnología', render: (r) => r.tipo_tecnologia },
    { label: 'Punto de control', render: (r) => r.punto?.nombre_punto ?? '—' },
  ],
  campos: [
    { name: 'codigo_mac', label: 'Código MAC', required: true },
    { name: 'direccion_ip', label: 'Dirección IP', required: true },
    { name: 'tipo_tecnologia', label: 'Tecnología', type: 'select', required: true, options: opcionesCatalogo(CAT.dispositivo_tecnologia) },
    { name: 'id_punto_control', label: 'Punto de control', type: 'select', required: true, options: optPuntosControl },
    { name: 'estado_dispositivo', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.dispositivo_estado), default: 'OPERATIVO' },
  ],
  campoEstado: 'estado_dispositivo',
}

export const cfgAsignacionGuardia: ResourceConfig = {
  tabla: 'guardia_punto_control',
  titulo: 'Asignaciones de guardia',
  singular: 'Asignación',
  idField: 'id_asignacion',
  select: '*, guardia:usuario_sistema!guardia_punto_control_id_usuario_fkey(nombre_usuario, correo_electronico), punto:punto_control(nombre_punto)',
  // PCO y CAC pueden asignar (matriz doc 02); el guardia NO (solo lee la propia, ver vista guardia).
  permisos: { select: ['PCO_ASIGNACION_SELECT', 'CAC_ASIGNACION_SELECT'], insert: ['PCO_ASIGNACION_INSERT', 'CAC_ASIGNACION_INSERT'], update: ['PCO_ASIGNACION_UPDATE', 'CAC_ASIGNACION_UPDATE'] },
  autoUsuarioRegistro: ['id_usuario_registro'],
  buscarEn: ['guardia.correo_electronico', 'punto.nombre_punto', 'turno'],
  columnas: [
    { key: 'guardia', label: 'Guardia', render: (r) => r.guardia?.correo_electronico ?? '—' },
    { key: 'punto', label: 'Punto', render: (r) => r.punto?.nombre_punto ?? '—' },
    { key: 'turno', label: 'Turno', render: (r) => d(r.turno) },
    { key: 'estado_asignacion', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.guardia?.correo_electronico ?? 'Asignación',
  campoSubtituloDetalle: (r) => <>Punto {r.punto?.nombre_punto ?? '—'} · <Badge value={r.estado_asignacion} /></>,
  detalle: [
    { label: 'Punto de control', render: (r) => r.punto?.nombre_punto ?? '—' },
    { label: 'Turno', render: (r) => d(r.turno) },
    { label: 'Vigencia', render: (r) => `${fmtFecha(r.fecha_inicio)} → ${r.fecha_fin ? fmtFecha(r.fecha_fin) : 'indefinida'}` },
  ],
  campos: [
    { name: 'id_usuario', label: 'Guardia', type: 'select', required: true, editable: false, options: opcionesTabla('usuario_sistema', 'id_usuario', (u) => u.correo_electronico) },
    { name: 'id_punto_control', label: 'Punto de control', type: 'select', required: true, options: optPuntosControl },
    { name: 'turno', label: 'Turno', placeholder: 'Ej. 06:00–14:00' },
    { name: 'fecha_inicio', label: 'Inicio', type: 'date', required: true },
    { name: 'fecha_fin', label: 'Fin (opcional)', type: 'date' },
    { name: 'estado_asignacion', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.asignacion_estado), default: 'ACTIVA' },
  ],
  campoEstado: 'estado_asignacion',
  baja: { campoEstado: 'estado_asignacion', valorBaja: 'FINALIZADA', etiqueta: 'Finalizar asignación' },
}

/* =========================================================================
   GPE — personal externo, memorandos, autorizaciones
   ========================================================================= */

export const cfgPersonaExterna: ResourceConfig = {
  tabla: 'persona',
  titulo: 'Personal externo',
  singular: 'Persona externa',
  idField: 'id_persona',
  select: '*, categoria:categoria_persona(nombre_categoria, codigo_categoria), empresa:empresa(nombre)',
  orderBy: { columna: 'apellidos' },
  filtroFijo: { tipo_persona: 'EXTERNA' },
  permisos: { select: ['GPE_PERSONA_SELECT'], insert: ['GPE_PERSONA_INSERT'], update: ['GPE_PERSONA_UPDATE'] },
  defaultsInsert: { tipo_persona: 'EXTERNA', estado: 'ACTIVO' },
  buscarEn: ['cedula', 'nombres', 'apellidos', 'correo'],
  columnas: [
    { key: 'cedula', label: 'Cédula' },
    { key: 'nombres', label: 'Nombres', render: (r) => `${r.apellidos} ${r.nombres}` },
    { key: 'categoria', label: 'Categoría', render: (r) => r.categoria?.codigo_categoria ?? '—' },
    { key: 'empresa', label: 'Empresa', render: (r) => r.empresa?.nombre ?? '—' },
    { key: 'estado', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => `${r.nombres} ${r.apellidos}`,
  campoSubtituloDetalle: (r) => <><Badge value={r.categoria?.codigo_categoria} /> <Badge value={r.estado} /></>,
  detalle: [
    { label: 'Cédula', render: (r) => r.cedula },
    { label: 'Correo', render: (r) => d(r.correo) },
    { label: 'Teléfono', render: (r) => d(r.telefono_contacto) },
    { label: 'Categoría', render: (r) => r.categoria?.nombre_categoria ?? '—' },
    { label: 'Empresa', render: (r) => r.empresa?.nombre ?? '—' },
    { label: 'Registro', render: (r) => fmtFecha(r.fecha_registro) },
  ],
  campos: [
    { name: 'cedula', label: 'Cédula', required: true, editable: false },
    { name: 'nombres', label: 'Nombres', required: true, editable: false },
    { name: 'apellidos', label: 'Apellidos', required: true, editable: false },
    { name: 'correo', label: 'Correo', type: 'email', required: true },
    { name: 'telefono_contacto', label: 'Teléfono' },
    { name: 'id_categoria', label: 'Categoría (externa)', type: 'select', required: true, options: optCategorias('EXTERNA') },
    { name: 'id_empresa', label: 'Empresa (opcional)', type: 'select', options: optEmpresas },
    { name: 'sexo', label: 'Sexo', type: 'select', options: opcionesCatalogo(CAT.persona_sexo) },
    { name: 'fecha_nacimiento', label: 'Fecha de nacimiento', type: 'date' },
    { name: 'direccion_domicilio', label: 'Dirección', colSpan: 2 },
  ],
  campoEstado: 'estado',
  // Brecha §6.1: baja de persona = INACTIVO (sin "temporal con duración"). Ver 99_DUDAS_FRONTEND.md.
  baja: { campoEstado: 'estado', valorBaja: 'INACTIVO', campoMotivo: 'detalle_estado', etiqueta: 'Dar de baja' },
}

export const cfgMemorando: ResourceConfig = {
  tabla: 'memorando',
  titulo: 'Memorandos',
  singular: 'Memorando',
  idField: 'id_memorando',
  select: '*, empresa:empresa(nombre)',
  orderBy: { columna: 'fecha_registro', ascendente: false },
  permisos: { select: ['GPE_MEMORANDO_SELECT'], insert: ['GPE_MEMORANDO_INSERT'], update: ['GPE_MEMORANDO_UPDATE'] },
  autoUsuarioRegistro: ['id_usuario_registro'],
  buscarEn: ['numero_memorando', 'dependencia_autorizada', 'empresa.nombre'],
  columnas: [
    { key: 'numero_memorando', label: 'Número' },
    { key: 'empresa', label: 'Empresa', render: (r) => r.empresa?.nombre ?? '—' },
    { key: 'dependencia_autorizada', label: 'Dependencia' },
    { key: 'vigencia', label: 'Vigencia', render: (r) => `${fmtFecha(r.fecha_inicio)} → ${fmtFecha(r.fecha_fin)}` },
    { key: 'estado_memorando', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.numero_memorando,
  campoSubtituloDetalle: (r) => <><Badge value={r.estado_memorando} /> · {r.empresa?.nombre}</>,
  detalle: [
    { label: 'Empresa', render: (r) => r.empresa?.nombre ?? '—' },
    { label: 'Dependencia autorizada', render: (r) => r.dependencia_autorizada },
    { label: 'Vigencia', render: (r) => `${fmtFecha(r.fecha_inicio)} → ${fmtFecha(r.fecha_fin)}` },
    { label: 'Registro', render: (r) => fmtFecha(r.fecha_registro) },
  ],
  campos: [
    { name: 'numero_memorando', label: 'Número de memorando', required: true, editable: false },
    { name: 'id_empresa', label: 'Empresa', type: 'select', required: true, options: optEmpresas },
    { name: 'dependencia_autorizada', label: 'Dependencia autorizada', required: true, colSpan: 2 },
    { name: 'fecha_inicio', label: 'Inicio de vigencia', type: 'date', required: true },
    { name: 'fecha_fin', label: 'Fin de vigencia', type: 'date', required: true, hint: 'fecha_fin inclusiva (§D24)' },
    { name: 'estado_memorando', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.memorando_estado), default: 'VIGENTE' },
  ],
  campoEstado: 'estado_memorando',
}

export const cfgPersonaMemorando: ResourceConfig = {
  tabla: 'persona_memorando',
  titulo: 'Personas por memorando',
  singular: 'Vínculo persona–memorando',
  idField: 'id_persona_memorando',
  select: '*, persona:persona(nombres, apellidos, cedula), memorando:memorando(numero_memorando)',
  permisos: { select: ['GPE_PERSONA_MEMORANDO_SELECT'], insert: ['GPE_PERSONA_MEMORANDO_INSERT'], update: ['GPE_PERSONA_MEMORANDO_UPDATE'] },
  buscarEn: ['persona.cedula', 'persona.apellidos', 'memorando.numero_memorando'],
  columnas: [
    { key: 'persona', label: 'Persona', render: (r) => (r.persona ? `${r.persona.apellidos} ${r.persona.nombres}` : '—') },
    { key: 'cedula', label: 'Cédula', render: (r) => d(r.persona?.cedula) },
    { key: 'memorando', label: 'Memorando', render: (r) => r.memorando?.numero_memorando ?? '—' },
    { key: 'estado_acceso', label: 'Acceso', badge: true },
  ],
  campoTituloDetalle: (r) => (r.persona ? `${r.persona.nombres} ${r.persona.apellidos}` : 'Vínculo'),
  detalle: [
    { label: 'Cédula', render: (r) => d(r.persona?.cedula) },
    { label: 'Memorando', render: (r) => r.memorando?.numero_memorando ?? '—' },
    { label: 'Estado de acceso', render: (r) => <Badge value={r.estado_acceso} /> },
  ],
  campos: [
    { name: 'id_persona', label: 'Persona externa', type: 'select', required: true, editable: false, options: opcionesTabla('persona', 'id_persona', (p) => `${p.apellidos} ${p.nombres} · ${p.cedula}`, { tipo_persona: 'EXTERNA' }) },
    { name: 'id_memorando', label: 'Memorando', type: 'select', required: true, editable: false, options: opcionesTabla('memorando', 'id_memorando', (m) => m.numero_memorando) },
    { name: 'estado_acceso', label: 'Estado de acceso', type: 'select', options: opcionesCatalogo(CAT.persona_memorando_estado), default: 'ACTIVO' },
  ],
  campoEstado: 'estado_acceso',
  baja: { campoEstado: 'estado_acceso', valorBaja: 'BLOQUEADO', etiqueta: 'Bloquear acceso' },
}

/* =========================================================================
   CAC — reglas de acceso
   ========================================================================= */

export const cfgReglaAcceso: ResourceConfig = {
  tabla: 'regla_acceso',
  titulo: 'Reglas de acceso',
  singular: 'Regla de acceso',
  idField: 'id_regla_acceso',
  select: '*, categoria:categoria_persona(nombre_categoria, codigo_categoria), punto:punto_control(nombre_punto)',
  orderBy: { columna: 'nombre_regla' },
  permisos: { select: ['CAC_REGLA_SELECT'], insert: ['CAC_REGLA_INSERT'], update: ['CAC_REGLA_UPDATE'] },
  buscarEn: ['nombre_regla', 'descripcion'],
  columnas: [
    { key: 'nombre_regla', label: 'Nombre' },
    { key: 'categoria', label: 'Categoría', render: (r) => r.categoria?.codigo_categoria ?? '—' },
    { key: 'punto', label: 'Punto', render: (r) => r.punto?.nombre_punto ?? 'Todos' },
    { key: 'horario', label: 'Horario', render: (r) => `${fmtHora(r.horario_inicio)}–${fmtHora(r.horario_fin)}` },
    { key: 'estado_regla', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => r.nombre_regla,
  campoSubtituloDetalle: (r) => <Badge value={r.estado_regla} />,
  detalle: [
    { label: 'Categoría', render: (r) => r.categoria?.nombre_categoria ?? '—' },
    { label: 'Punto de control', render: (r) => r.punto?.nombre_punto ?? 'Todos los puntos' },
    { label: 'Horario', render: (r) => `${fmtHora(r.horario_inicio)} – ${fmtHora(r.horario_fin)}` },
    { label: 'Requiere memorando', render: (r) => (r.requiere_memorando ? 'Sí' : 'No') },
    { label: 'Descripción', render: (r) => d(r.descripcion) },
  ],
  campos: [
    { name: 'nombre_regla', label: 'Nombre de la regla', required: true, colSpan: 2 },
    { name: 'id_categoria', label: 'Categoría', type: 'select', required: true, options: optCategorias() },
    { name: 'id_punto_control', label: 'Punto de control (opcional = todos)', type: 'select', options: optPuntosControl },
    { name: 'horario_inicio', label: 'Horario inicio', type: 'time', required: true },
    { name: 'horario_fin', label: 'Horario fin', type: 'time', required: true },
    { name: 'requiere_memorando', label: '¿Requiere memorando?', type: 'checkbox' },
    { name: 'estado_regla', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.regla_estado), default: 'ACTIVA' },
    { name: 'descripcion', label: 'Descripción', type: 'textarea', colSpan: 3 },
  ],
  campoEstado: 'estado_regla',
  baja: { campoEstado: 'estado_regla', valorBaja: 'INACTIVA', etiqueta: 'Inactivar regla' },
}

/** Autorizaciones de visita diaria (GPE). El guardia las crea desde su vista operativa. */
export const cfgAutorizacion: ResourceConfig = {
  tabla: 'autorizacion_visita_diaria',
  titulo: 'Autorizaciones de visita',
  singular: 'Autorización',
  idField: 'id_autorizacion',
  select: '*, persona:persona(nombres, apellidos, cedula)',
  orderBy: { columna: 'fecha_visita', ascendente: false },
  permisos: { select: ['GPE_AUTORIZACION_SELECT'], insert: ['GPE_AUTORIZACION_INSERT'], update: ['GPE_AUTORIZACION_UPDATE'] },
  autoUsuarioRegistro: ['id_usuario_registro'],
  buscarEn: ['persona.cedula', 'persona.apellidos', 'motivo'],
  columnas: [
    { key: 'persona', label: 'Visitante', render: (r) => (r.persona ? `${r.persona.apellidos} ${r.persona.nombres}` : '—') },
    { key: 'cedula', label: 'Cédula', render: (r) => d(r.persona?.cedula) },
    { key: 'fecha_visita', label: 'Fecha de visita', render: (r) => fmtFecha(r.fecha_visita) },
    { key: 'estado_autorizacion', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => (r.persona ? `${r.persona.nombres} ${r.persona.apellidos}` : 'Autorización'),
  campoSubtituloDetalle: (r) => <><Badge value={r.estado_autorizacion} /> · {fmtFecha(r.fecha_visita)}</>,
  detalle: [
    { label: 'Cédula', render: (r) => d(r.persona?.cedula) },
    { label: 'Fecha de visita', render: (r) => fmtFecha(r.fecha_visita) },
    { label: 'Motivo', render: (r) => d(r.motivo) },
    { label: 'Registrada', render: (r) => fmtFecha(r.fecha_registro) },
  ],
  campos: [
    { name: 'id_persona', label: 'Visitante (persona externa)', type: 'select', required: true, editable: false, options: opcionesTabla('persona', 'id_persona', (p) => `${p.apellidos} ${p.nombres} · ${p.cedula}`, { tipo_persona: 'EXTERNA' }), colSpan: 2 },
    { name: 'fecha_visita', label: 'Fecha de visita', type: 'date', required: true, default: hoyISO() },
    { name: 'motivo', label: 'Motivo', type: 'textarea', required: true, colSpan: 3 },
    { name: 'estado_autorizacion', label: 'Estado', type: 'select', options: opcionesCatalogo(CAT.autorizacion_estado), default: 'VIGENTE' },
  ],
  campoEstado: 'estado_autorizacion',
  baja: { campoEstado: 'estado_autorizacion', valorBaja: 'REVOCADA', etiqueta: 'Revocar autorización' },
}
