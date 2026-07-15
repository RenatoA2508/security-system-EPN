import type { ReactNode } from 'react'

export interface Opcion {
  value: string
  label: string
}

export type FieldType = 'text' | 'number' | 'date' | 'time' | 'email' | 'select' | 'textarea' | 'checkbox'

export interface FieldConfig {
  name: string
  label: string
  type?: FieldType
  required?: boolean
  /** Opciones estáticas o cargadas de forma asíncrona (FKs, catálogos). */
  options?: Opcion[] | (() => Promise<Opcion[]>)
  /** Si es false, el campo NO se puede editar en el formulario de edición (Patrón C). */
  editable?: boolean
  /** Solo se envía en INSERT, no en UPDATE. */
  insertOnly?: boolean
  hint?: string
  placeholder?: string
  colSpan?: 1 | 2 | 3
  /** Valor por defecto al registrar. */
  default?: string | number | boolean
}

export interface ColumnConfig<Row = any> {
  key: string
  label: string
  render?: (row: Row) => ReactNode
  /** Marca la columna como badge de estado. */
  badge?: boolean
}

export interface DetailRow<Row = any> {
  label: string
  render: (row: Row) => ReactNode
}

export interface BajaConfig {
  /** Columna de estado a cambiar. */
  campoEstado: string
  /** Valor que representa "dado de baja" / inactivo. */
  valorBaja: string
  /** Columna donde se guarda el motivo (opcional; si no existe, el motivo va a bitácora implícita). */
  campoMotivo?: string
  /** Opciones de "tipo de baja" si aplica. */
  tipos?: Opcion[]
  etiqueta?: string
}

export interface ResourceConfig<Row = any> {
  tabla: string
  titulo: string
  singular: string
  icono?: ReactNode
  descripcion?: string
  idField: string
  /** select de PostgREST (incluye joins para mostrar nombres). */
  select?: string
  orderBy?: { columna: string; ascendente?: boolean }
  /** Permisos efectivos que la matriz (doc 02) exige por acción. */
  permisos: { select: string[]; insert?: string[]; update?: string[] }
  columnas: ColumnConfig<Row>[]
  /** Campos de texto sobre los que busca la barra de búsqueda (ilike). */
  buscarEn?: string[]
  detalle: DetailRow<Row>[]
  campoTituloDetalle: (row: Row) => string
  campoSubtituloDetalle?: (row: Row) => ReactNode
  campos: FieldConfig[]
  /** Filtro fijo aplicado a todas las consultas (ej. tipo_persona=INTERNA). */
  filtroFijo?: Record<string, string>
  campoEstado?: string
  baja?: BajaConfig
  /** Valores por defecto extra al insertar (además de los `default` por campo). */
  defaultsInsert?: Record<string, unknown>
  /** Columnas que se rellenan automáticamente con el id del usuario autenticado al INSERTAR. */
  autoUsuarioRegistro?: string[]
}
