import type { ReactNode } from 'react'
import {
  Building2, Car, Cctv, ClipboardList, Contact, Cpu, FileText, Fingerprint, KeyRound,
  LayoutGrid, ListChecks, Lock, MapPin, Monitor, ScrollText, Settings, Shield, ShieldAlert,
  Users, UserCheck, UserCog, UserPlus, Link2, ClipboardCheck, History,
} from 'lucide-react'
import { ResourceScreen } from '../components/ResourceScreen'
import type { ResourceConfig } from './types'
import { BiometriaScreen } from '../pages/modules/BiometriaScreen'
import { AlertasScreen } from '../pages/modules/AlertasScreen'
import { MonitoreoView } from '../pages/modules/MonitoreoView'
import {
  cfgEmpresa, cfgCategoria, cfgParametro, cfgRol, cfgPermiso, cfgUsuario, cfgUsuarioRol,
  cfgVehiculo, cfgPersonaVehiculo, cfgZona, cfgPuntoControl, cfgDispositivo, cfgAsignacionGuardia,
  cfgPersonaExterna, cfgMemorando, cfgPersonaMemorando, cfgReglaAcceso, cfgAutorizacion,
} from './configs'
import { cfgPersonaADM, cfgBitacora, cfgSesion, cfgEventoAcceso, cfgBiometriaADM } from './configs-lectura'
import { cfgPersonaInterna, cfgPersonaInternaDetalle } from './configs-gpi'

export interface SubmoduloDef {
  key: string
  titulo: string
  descripcion: string
  icono: ReactNode
  /** Permisos (any-of) requeridos para ver la tarjeta; si no los tiene, se oculta. */
  permisoVer?: string[]
  render: () => ReactNode
}

export interface ModuloDef {
  codigo: 'ADM' | 'GPI' | 'GPE' | 'PCO' | 'CAC' | 'MON'
  titulo: string
  descripcion: string
  icono: ReactNode
  submodulos: SubmoduloDef[]
}

const rs = (config: ResourceConfig) => () => <ResourceScreen config={config} />
const sub = (key: string, titulo: string, descripcion: string, icono: ReactNode, config: ResourceConfig): SubmoduloDef => ({
  key, titulo, descripcion, icono, permisoVer: config.permisos.select, render: rs(config),
})

export const MODULOS: ModuloDef[] = [
  {
    codigo: 'GPI',
    titulo: 'Personal Interno',
    descripcion: 'Docentes, estudiantes, empleados, biometría y vehículos internos.',
    icono: <UserCog className="h-7 w-7" />,
    submodulos: [
      sub('personas', 'Personal interno', 'Registro y consulta de personas internas.', <Users className="h-6 w-6" />, cfgPersonaInterna),
      sub('detalle', 'Datos internos', 'Cargo, unidad, carrera, escalafón.', <Contact className="h-6 w-6" />, cfgPersonaInternaDetalle),
      { key: 'biometria', titulo: 'Biometría', descripcion: 'Enrolamiento facial 1:N del personal interno.', icono: <Fingerprint className="h-6 w-6" />, permisoVer: ['GPI_BIOMETRIA_SELECT'], render: () => <BiometriaScreen /> },
      sub('vehiculos', 'Vehículos', 'Alta de vehículos.', <Car className="h-6 w-6" />, cfgVehiculo('GPI')),
      sub('asociaciones', 'Asociaciones', 'Vínculos persona–vehículo.', <Link2 className="h-6 w-6" />, cfgPersonaVehiculo('GPI')),
    ],
  },
  {
    codigo: 'GPE',
    titulo: 'Personal Externo',
    descripcion: 'Visitantes, proveedores, memorandos y autorizaciones.',
    icono: <UserCheck className="h-7 w-7" />,
    submodulos: [
      sub('personas', 'Personal externo', 'Registro y consulta de personas externas.', <UserPlus className="h-6 w-6" />, cfgPersonaExterna),
      sub('memorandos', 'Memorandos', 'Memorandos de acceso por empresa.', <FileText className="h-6 w-6" />, cfgMemorando),
      sub('persona-memorando', 'Personas por memorando', 'Vínculo persona–memorando.', <ClipboardList className="h-6 w-6" />, cfgPersonaMemorando),
      sub('autorizaciones', 'Autorizaciones de visita', 'Visitas diarias sin memorando.', <ClipboardCheck className="h-6 w-6" />, cfgAutorizacion),
      sub('vehiculos', 'Vehículos', 'Alta de vehículos externos.', <Car className="h-6 w-6" />, cfgVehiculo('GPE')),
      sub('asociaciones', 'Asociaciones', 'Vínculos persona–vehículo.', <Link2 className="h-6 w-6" />, cfgPersonaVehiculo('GPE')),
    ],
  },
  {
    codigo: 'PCO',
    titulo: 'Puntos de Control',
    descripcion: 'Zonas, puntos de control, dispositivos y asignación de guardias.',
    icono: <MapPin className="h-7 w-7" />,
    submodulos: [
      sub('zonas', 'Zonas', 'Campus, edificios y parqueaderos.', <LayoutGrid className="h-6 w-6" />, cfgZona),
      sub('puntos', 'Puntos de control', 'Garitas y accesos.', <Shield className="h-6 w-6" />, cfgPuntoControl),
      sub('dispositivos', 'Dispositivos', 'Cámaras, torniquetes y lectores.', <Cpu className="h-6 w-6" />, cfgDispositivo),
      sub('asignaciones', 'Asignaciones de guardia', 'Guardia ↔ punto de control.', <UserCog className="h-6 w-6" />, cfgAsignacionGuardia),
    ],
  },
  {
    codigo: 'CAC',
    titulo: 'Control de Accesos',
    descripcion: 'Reglas de acceso, eventos y alertas de seguridad.',
    icono: <Lock className="h-7 w-7" />,
    submodulos: [
      sub('reglas', 'Reglas de acceso', 'Categoría × punto × horario.', <ListChecks className="h-6 w-6" />, cfgReglaAcceso),
      sub('eventos', 'Eventos de acceso', 'Histórico de ingresos y salidas.', <History className="h-6 w-6" />, cfgEventoAcceso()),
      { key: 'alertas', titulo: 'Alertas de seguridad', descripcion: 'Atención de alertas automáticas.', icono: <ShieldAlert className="h-6 w-6" />, permisoVer: ['CAC_ALERTA_SELECT'], render: () => <AlertasScreen /> },
      sub('asignaciones', 'Asignaciones de guardia', 'Organización operativa diaria.', <UserCog className="h-6 w-6" />, cfgAsignacionGuardia),
    ],
  },
  {
    codigo: 'ADM',
    titulo: 'Administración',
    descripcion: 'Usuarios, roles, permisos, catálogos maestros y auditoría.',
    icono: <Settings className="h-7 w-7" />,
    submodulos: [
      sub('usuarios', 'Usuarios', 'Cuentas del sistema.', <Users className="h-6 w-6" />, cfgUsuario),
      sub('usuario-rol', 'Asignaciones de rol', 'Roles por usuario.', <UserCog className="h-6 w-6" />, cfgUsuarioRol),
      sub('roles', 'Roles', 'Roles del sistema.', <KeyRound className="h-6 w-6" />, cfgRol),
      sub('permisos', 'Permisos', 'Catálogo de permisos.', <Lock className="h-6 w-6" />, cfgPermiso),
      sub('categorias', 'Categorías', 'Categorías de persona.', <ListChecks className="h-6 w-6" />, cfgCategoria),
      sub('empresas', 'Empresas', 'Empresas de servicio y proveedores.', <Building2 className="h-6 w-6" />, cfgEmpresa),
      sub('parametros', 'Parámetros', 'Parámetros del sistema.', <Settings className="h-6 w-6" />, cfgParametro),
      sub('personas', 'Personas', 'Vista global de todas las personas.', <Contact className="h-6 w-6" />, cfgPersonaADM),
      sub('biometria', 'Biometría', 'Metadatos de registros biométricos (sin acceso al archivo).', <Fingerprint className="h-6 w-6" />, cfgBiometriaADM),
      sub('vehiculos', 'Vehículos', 'Ciclo de vida de vehículos.', <Car className="h-6 w-6" />, cfgVehiculo('ADM')),
      sub('asociaciones', 'Asociaciones', 'Vínculos persona–vehículo.', <Link2 className="h-6 w-6" />, cfgPersonaVehiculo('ADM')),
      sub('bitacora', 'Bitácora', 'Auditoría del sistema.', <ScrollText className="h-6 w-6" />, cfgBitacora),
      sub('sesiones', 'Sesiones', 'Registro de sesiones.', <History className="h-6 w-6" />, cfgSesion),
    ],
  },
  {
    codigo: 'MON',
    titulo: 'Monitoreo',
    descripcion: 'Panel operativo: vehículos dentro, vigencias, eventos y alertas.',
    icono: <Monitor className="h-7 w-7" />,
    submodulos: [
      { key: 'panel', titulo: 'Panel de monitoreo', descripcion: 'Vista consolidada en tiempo casi real.', icono: <Cctv className="h-6 w-6" />, permisoVer: ['CAC_EVENTO_SELECT', 'ADM_PERSONA_SELECT'], render: () => <MonitoreoView /> },
    ],
  },
]

export function moduloPorCodigo(codigo: string): ModuloDef | undefined {
  return MODULOS.find((m) => m.codigo === codigo)
}
