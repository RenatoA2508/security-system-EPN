import type { ResourceConfig } from './types'
import { CAT } from '../lib/catalogos'
import { fmtFecha } from '../lib/format'
import { Badge } from '../components/ui'
import { opcionesCatalogo, optCategorias, opcionesTabla } from './opciones'

const d = (v: any) => (v == null || v === '' ? '—' : String(v))

/** Personal interno (persona con tipo_persona = INTERNA). Biometría se maneja en su propia pantalla. */
export const cfgPersonaInterna: ResourceConfig = {
  tabla: 'persona',
  titulo: 'Personal interno',
  singular: 'Persona interna',
  idField: 'id_persona',
  select: '*, categoria:categoria_persona(nombre_categoria, codigo_categoria), biometria:registro_biometrico(id_registro, vigente)',
  orderBy: { columna: 'apellidos' },
  filtroFijo: { tipo_persona: 'INTERNA' },
  permisos: { select: ['GPI_PERSONA_SELECT'], insert: ['GPI_PERSONA_INSERT'], update: ['GPI_PERSONA_UPDATE'] },
  defaultsInsert: { tipo_persona: 'INTERNA', estado: 'ACTIVO' },
  buscarEn: ['cedula', 'nombres', 'apellidos', 'correo', 'codigo_unico'],
  columnas: [
    { key: 'cedula', label: 'Cédula' },
    { key: 'nombres', label: 'Nombre', render: (r) => `${r.apellidos} ${r.nombres}` },
    { key: 'categoria', label: 'Categoría', render: (r) => r.categoria?.codigo_categoria ?? '—' },
    { key: 'biometria', label: 'Biometría', render: (r) => (r.biometria?.some?.((b: any) => b.vigente) ? <Badge value="ACTIVA" /> : <span className="text-xs text-slate-400">Sin enrolar</span>) },
    { key: 'estado', label: 'Estado', badge: true },
  ],
  campoTituloDetalle: (r) => `${r.nombres} ${r.apellidos}`,
  campoSubtituloDetalle: (r) => <><Badge value={r.categoria?.codigo_categoria} /> <Badge value={r.estado} /></>,
  detalle: [
    { label: 'Cédula', render: (r) => r.cedula },
    { label: 'Código único', render: (r) => d(r.codigo_unico) },
    { label: 'Correo', render: (r) => d(r.correo) },
    { label: 'Teléfono', render: (r) => d(r.telefono_contacto) },
    { label: 'Categoría', render: (r) => r.categoria?.nombre_categoria ?? '—' },
    { label: 'Biometría', render: (r) => (r.biometria?.some?.((b: any) => b.vigente) ? 'Enrolada' : 'Sin enrolar — usa la sección Biometría') },
    { label: 'Registro', render: (r) => fmtFecha(r.fecha_registro) },
  ],
  campos: [
    { name: 'cedula', label: 'Cédula', required: true, editable: false },
    { name: 'codigo_unico', label: 'Código único' },
    { name: 'nombres', label: 'Nombres', required: true, editable: false },
    { name: 'apellidos', label: 'Apellidos', required: true, editable: false },
    { name: 'correo', label: 'Correo', type: 'email', required: true },
    { name: 'telefono_contacto', label: 'Teléfono' },
    { name: 'id_categoria', label: 'Categoría (interna)', type: 'select', required: true, options: optCategorias('INTERNA') },
    { name: 'sexo', label: 'Sexo', type: 'select', options: opcionesCatalogo(CAT.persona_sexo) },
    { name: 'fecha_nacimiento', label: 'Fecha de nacimiento', type: 'date' },
    { name: 'direccion_domicilio', label: 'Dirección', colSpan: 2 },
  ],
  campoEstado: 'estado',
  // Brecha §6.1: sin baja temporal con duración; INACTIVO + motivo en detalle_estado. Ver 99_DUDAS_FRONTEND.md.
  baja: { campoEstado: 'estado', valorBaja: 'INACTIVO', campoMotivo: 'detalle_estado', etiqueta: 'Dar de baja' },
}

export const cfgPersonaInternaDetalle: ResourceConfig = {
  tabla: 'persona_interna_detalle',
  titulo: 'Datos internos (cargo / unidad)',
  singular: 'Detalle interno',
  idField: 'id_persona',
  select: '*, persona:persona(nombres, apellidos, cedula)',
  permisos: { select: ['GPI_PERSONA_DETALLE_SELECT'], insert: ['GPI_PERSONA_DETALLE_INSERT'], update: ['GPI_PERSONA_DETALLE_UPDATE'] },
  buscarEn: ['persona.cedula', 'persona.apellidos', 'cargo', 'unidad'],
  columnas: [
    { key: 'persona', label: 'Persona', render: (r) => (r.persona ? `${r.persona.apellidos} ${r.persona.nombres}` : '—') },
    { key: 'unidad', label: 'Unidad', render: (r) => d(r.unidad) },
    { key: 'cargo', label: 'Cargo', render: (r) => d(r.cargo) },
    { key: 'carrera', label: 'Carrera', render: (r) => d(r.carrera) },
  ],
  campoTituloDetalle: (r) => (r.persona ? `${r.persona.nombres} ${r.persona.apellidos}` : 'Detalle'),
  detalle: [
    { label: 'Cédula', render: (r) => d(r.persona?.cedula) },
    { label: 'Unidad', render: (r) => d(r.unidad) },
    { label: 'Cargo', render: (r) => d(r.cargo) },
    { label: 'Carrera', render: (r) => d(r.carrera) },
    { label: 'Curso', render: (r) => d(r.curso) },
    { label: 'Escalafón', render: (r) => d(r.categoria_escalafon) },
    { label: 'Contrato', render: (r) => d(r.contrato) },
    { label: 'Nombramiento', render: (r) => d(r.nombramiento) },
  ],
  campos: [
    { name: 'id_persona', label: 'Persona interna', type: 'select', required: true, editable: false, options: opcionesTabla('persona', 'id_persona', (p) => `${p.apellidos} ${p.nombres} · ${p.cedula}`, { tipo_persona: 'INTERNA' }) },
    { name: 'unidad', label: 'Unidad', type: 'select', options: opcionesCatalogo(CAT.unidad) },
    { name: 'cargo', label: 'Cargo' },
    { name: 'carrera', label: 'Carrera' },
    { name: 'curso', label: 'Curso' },
    { name: 'categoria_escalafon', label: 'Categoría / escalafón' },
    { name: 'contrato', label: 'Contrato' },
    { name: 'nombramiento', label: 'Nombramiento' },
  ],
}
