# Evaluación del módulo ADM en el Sistema de Seguridad EPN integrado

> **Sistema evaluado:** https://security-system-epn.vercel.app  
> **Fecha de evaluación:** 14 de julio de 2026  
> **Módulo:** Administración del Sistema (ADM)  
> **Tipo de evaluación:** inspección funcional y técnica de solo lectura  
> **Perfiles evaluados:** Administrador del Sistema y Director Administrativo

---

## 1. Objetivo

Evaluar qué tan cercana se encuentra la implementación del módulo ADM dentro del Sistema de Seguridad EPN integrado respecto al alcance, los casos de uso, los roles, los permisos y las decisiones documentadas previamente para el proyecto.

La evaluación toma como referencia principal los siguientes documentos:

- `ADM_Notion_Actualizado.md`.
- `ADM_Login_Roles_Permisos.md`.
- El mockup funcional preparado previamente para ADM.

La revisión se limita a las funciones y contenidos visibles desde la interfaz. No constituye una auditoría del código fuente, de las políticas de la base de datos ni de los endpoints del backend.

---

## 2. Restricciones de la evaluación

Durante la revisión:

- No se registraron datos.
- No se modificaron registros existentes.
- No se eliminaron registros.
- No se enviaron formularios administrativos.
- No se ejecutaron exportaciones.
- No se cambió ninguna contraseña.
- No se probaron operaciones CRUD.
- No se intentó ingresar manualmente a rutas no autorizadas.

Las únicas acciones realizadas fueron:

- Iniciar sesión con los dos perfiles proporcionados.
- Cerrar la primera sesión para evaluar el segundo perfil.
- Navegar por las pantallas disponibles.
- Consultar tablas, catálogos, menús, campos y botones visibles.

### Efectos automáticos observados

Aunque no se ejecutó ninguna operación CRUD, el sistema generó automáticamente registros de sesión y numerosos eventos `UPDATE` sobre `usuario_sistema` durante los accesos o la navegación.

Este comportamiento parece corresponder a la actualización de la última actividad, último acceso o información equivalente. Es un efecto automático del sistema y no una modificación administrativa ejecutada durante la evaluación.

---

## 3. Resultado general

El módulo integrado presenta aproximadamente un **60–65 % de alineación funcional visible** con lo definido para ADM.

La integración de entidades, catálogos, roles y permisos está bastante avanzada. Sin embargo, todavía faltan varios casos de uso esenciales del mockup y existen diferencias importantes en la separación de privilegios de los perfiles evaluados.

| Área | Alineación estimada | Evaluación |
|---|---:|---|
| Login y sesión | 70 % | Existe autenticación centralizada, identificación del perfil y aviso de cambio obligatorio. |
| Roles y permisos | 60 % | Existen siete roles y cien permisos, pero la granularidad difiere de la acordada. |
| Gestión de usuarios | 30 % | La interfaz visible funciona principalmente como consulta. |
| Parámetros | 65 % | Existe un catálogo real, pero faltan parámetros aprobados. |
| Bitácora y reportes | 50 % | Existe auditoría integrada, pero faltan filtros y exportación visibles. |
| Datos maestros | 80 % | Personas, categorías, empresas, vehículos y asociaciones están integrados. |
| Director Administrativo | 70 % | Se respeta visualmente el modo de solo lectura, pero el alcance visible es demasiado amplio. |

> Los porcentajes son una estimación de la cobertura funcional visible. No evalúan el cumplimiento interno del backend ni la seguridad de las llamadas directas a la API.

---

## 4. Elementos correctamente implementados

### 4.1 Autenticación e identificación del usuario

- El inicio de sesión es centralizado.
- Ambos perfiles fueron reconocidos correctamente.
- El sistema diferencia entre `ADMINISTRADOR SISTEMA` y `DIRECTOR ADMINISTRATIVO`.
- Se muestra el estado de conexión del usuario.
- Existe una sección de cuenta personal.
- Existe un aviso de cambio obligatorio de contraseña inicial.
- Existe una opción visible para cerrar la sesión.

### 4.2 Roles

El sistema contiene los siete roles esperados:

1. `ADMINISTRADOR_SISTEMA`.
2. `DIRECTOR_ADMINISTRATIVO`.
3. `GUARDIA_SEGURIDAD`.
4. `RESPONSABLE_CONTROL_ACCESOS`.
5. `RESPONSABLE_PERSONAL_EXTERNO`.
6. `RESPONSABLE_PERSONAL_INTERNO`.
7. `RESPONSABLE_PUNTOS_CONTROL`.

Esto confirma que los roles propuestos para PCO y CAC ya fueron incorporados en la integración.

### 4.3 Permisos

- Existe un catálogo de cien permisos.
- Se encuentra implementado `ADM_MODULO_ACCEDER`.
- Existen permisos para consultar, registrar y actualizar diferentes entidades.
- Existen permisos para roles, permisos, parámetros, usuarios, vehículos, asociaciones, categorías y empresas.
- Se encuentran permisos relacionados con la matriz rol–permiso.
- Existe `ADM_BITACORA_EXPORTAR` en el catálogo, aunque la función no se encuentra visible en la interfaz evaluada.

### 4.4 Datos maestros e integración

El módulo ADM ya presenta secciones para:

- Usuarios.
- Asignaciones de roles.
- Roles.
- Permisos.
- Categorías de persona.
- Empresas.
- Parámetros.
- Personas.
- Biometría.
- Vehículos.
- Asociaciones persona–vehículo.
- Bitácora.
- Sesiones.

Esto se encuentra alineado con la decisión de que ADM sea propietario de las entidades maestras compartidas.

### 4.5 Biometría

La sección de biometría indica expresamente que muestra metadatos sin conceder acceso al archivo biométrico. Esta decisión es adecuada desde el punto de vista de seguridad y privacidad.

### 4.6 Auditoría integrada

La bitácora muestra eventos provenientes de diferentes módulos, entre ellos:

- ADM.
- CAC.
- PCO.

También presenta fecha, módulo, entidad, acción, resultado y usuario. Esto demuestra que existe una fuente centralizada de auditoría entre los módulos integrados.

---

## 5. Evaluación del Administrador del Sistema

### 5.1 Elementos visibles

El Administrador puede visualizar las trece secciones del módulo ADM y dispone de botones de registro en varias de ellas:

- Asignaciones de rol.
- Roles.
- Permisos.
- Categorías.
- Empresas.
- Parámetros.
- Vehículos.
- Asociaciones persona–vehículo.

### 5.2 Diferencia en el panel principal

El panel principal muestra al Administrador los módulos:

- Administración.
- Monitoreo.

La matriz acordada establece que el Administrador del Sistema administra ADM y no obtiene automáticamente funciones operativas de otros módulos.

Por tanto, la presencia de Monitoreo constituye una diferencia de autorización. Debe confirmarse si representa una nueva decisión del proyecto o si el permiso fue asignado por error.

### 5.3 Gestión de usuarios incompleta

La pantalla de Usuarios muestra:

- Buscador general.
- Usuario.
- Correo.
- Persona asociada.
- Estado.

No se encontraron visibles las funciones principales establecidas en el mockup:

- Registrar usuario.
- Actualizar usuario.
- Restablecer contraseña.
- Bloquear usuario.
- Desbloquear usuario.
- Activar usuario.
- Dar de baja usuario.
- Asignar rol desde el usuario.
- Revocar rol desde el usuario.

La asignación de roles existe como una sección independiente, pero el conjunto completo de casos de uso `CU-ADM-005` a `CU-ADM-013` todavía no está representado en la interfaz integrada.

---

## 6. Evaluación del Director Administrativo

### 6.1 Comportamiento de solo lectura

El comportamiento visual de solo lectura está correctamente aplicado en las pantallas revisadas.

Para este perfil no aparecen botones de registro en:

- Asignaciones de rol.
- Roles.
- Permisos.
- Categorías.
- Empresas.
- Parámetros.
- Vehículos.
- Asociaciones persona–vehículo.

Los campos de búsqueda permanecen habilitados, lo cual es coherente con un perfil de consulta.

### 6.2 Alcance visible demasiado amplio

El Director puede visualizar:

- Usuarios.
- Asignaciones de rol.
- Roles.
- Permisos.
- Categorías.
- Empresas.
- Parámetros.
- Personas.
- Biometría.
- Vehículos.
- Asociaciones.
- Bitácora.
- Sesiones.

Según la definición acordada, el Director Administrativo debería concentrarse en:

- Consulta de usuarios.
- Consulta de parámetros.
- Consulta de bitácora.
- Reportes.
- Consulta de vehículos, si se mantiene el permiso aprobado.

La exposición de roles, permisos, asignaciones, biometría y sesiones debe revisarse bajo el principio de mínimo privilegio, incluso cuando las pantallas sean de solo lectura.

### 6.3 Acceso visible a Monitoreo

El panel principal también muestra Monitoreo al Director Administrativo.

La matriz establecida indica que el Director no debe disponer de una interfaz funcional para otros módulos, salvo que se apruebe un tablero común de indicadores. La tarjeta actual parece ofrecer acceso al módulo operativo completo y no únicamente a indicadores resumidos.

---

## 7. Diferencias críticas

### 7.1 Separación de módulos

**Situación actual:** Administrador y Director visualizan Administración y Monitoreo.

**Resultado esperado:**

- Administrador del Sistema: ADM.
- Director Administrativo: consultas y reportes ADM.
- Monitoreo: únicamente para los roles expresamente autorizados.

**Recomendación:** revisar `allowed_modules`, la matriz rol–permiso y la presencia de `MON_MODULO_ACCEDER` en ambos perfiles.

### 7.2 Permisos demasiado genéricos

Los documentos definen permisos funcionales como:

```text
ADM_USUARIO_RESETEAR_PASSWORD
ADM_USUARIO_BLOQUEAR
ADM_USUARIO_DESBLOQUEAR
ADM_USUARIO_ACTIVAR
ADM_USUARIO_DAR_BAJA
ADM_USUARIO_ASIGNAR_ROL
ADM_USUARIO_REVOCAR_ROL
```

El sistema utiliza principalmente:

```text
ADM_USUARIO_INSERT
ADM_USUARIO_SELECT
ADM_USUARIO_UPDATE
```

Concentrar las operaciones sensibles en `UPDATE` dificulta:

- Aplicar mínimo privilegio.
- Autorizar una acción sin autorizar todas las modificaciones.
- Revocar una capacidad específica.
- Identificar claramente la acción en auditoría.
- Probar cada caso de uso de forma independiente.

Se recomienda crear permisos específicos para las operaciones administrativas sensibles.

### 7.3 Cambio obligatorio de contraseña

El sistema muestra el mensaje de cambio obligatorio, pero permite continuar navegando por los módulos sin completar el cambio.

Además, la pantalla de cuenta solicita únicamente:

- Nueva contraseña.
- Confirmación de contraseña.

El caso de uso general definido previamente contempla:

- Contraseña actual.
- Nueva contraseña.
- Confirmación.

Para una contraseña temporal puede ser válido no pedir la contraseña anterior, pero el sistema debería diferenciar claramente:

1. Cambio voluntario de contraseña propia.
2. Cambio obligatorio de contraseña temporal.

Cuando `requiere_cambio_password = true`, debería bloquearse el acceso al resto de las funciones hasta completar el cambio.

### 7.4 Bitácora y reportes

La vista actual contiene una búsqueda general y las columnas:

- Fecha.
- Módulo.
- Entidad.
- Acción.
- Resultado.
- Usuario.

No se encontraron visibles los filtros acordados:

- Fecha inicial y final.
- Usuario.
- Acción.
- Resultado.
- Entidad.
- Dirección IP.
- Módulo.

Tampoco se encontró visible la exportación en PDF o XLSX, aunque el permiso `ADM_BITACORA_EXPORTAR` existe en el catálogo.

### 7.5 Ruido de auditoría

Durante la navegación de solo lectura se observaron numerosos eventos:

```text
Módulo: ADM
Entidad: usuario_sistema
Acción: UPDATE
Resultado: EXITO
```

Estos eventos aparecieron asociados a los perfiles evaluados sin que se hubiera enviado ningún formulario de modificación.

Si corresponden a último acceso o última actividad, deberían clasificarse como eventos de autenticación o sesión, por ejemplo:

```text
LOGIN
LOGOUT
SESION_CREADA
SESION_ACTUALIZADA
ACTIVIDAD_SESION
```

Registrar cada navegación como `UPDATE usuario_sistema` genera ruido y dificulta identificar modificaciones administrativas reales.

### 7.6 Parámetros faltantes

Se encontraron ocho parámetros:

1. `MAX_INTENTOS_LOGIN`.
2. `PERMANENCIA_ABANDONO_H`.
3. `PERMANENCIA_MAX_EXTERNO_H`.
4. `PERMANENCIA_MAX_INTERNO_H`.
5. `PERMANENCIA_MAX_VISITA_H`.
6. `TIEMPO_BLOQUEO_CUENTA_MIN`.
7. `TIEMPO_SESION_MIN`.
8. `UMBRAL_BIOMETRIA`.

Faltan al menos:

- `LONGITUD_MINIMA_PASSWORD`.
- `MAX_VEHICULOS_POR_PERSONA`.

`MAX_VEHICULOS_POR_PERSONA` corresponde a una decisión aprobada del proyecto y debería incorporarse antes de cerrar la integración.

El valor de `MAX_INTENTOS_LOGIN` se encuentra configurado en cinco y debería confirmarse como valor definitivo con el equipo.

### 7.7 Integridad de Persona

En la consulta global se encontró la cédula `1712345678` asociada a dos personas diferentes.

Esto contradice la regla de que Persona sea una entidad maestra única y compartida. Debe revisarse:

- La restricción única de cédula en la base de datos.
- La normalización del identificador.
- La validación previa a registrar una persona.
- El tratamiento de datos de demostración.

No se realizó ninguna modificación sobre estos registros.

### 7.8 Matriz rol–permiso

Existen permisos relacionados con `rol_permiso` y la bitácora contiene evidencia de registros de esta entidad. Sin embargo, no existe una sección claramente identificada para consultar o configurar la matriz rol–permiso.

La implementación es, por tanto, parcial:

- Existe la estructura de datos.
- Existe evidencia de asociaciones.
- No existe una interfaz claramente visible para administrarlas.

---

## 8. Diferencias respecto al mockup

| Función del mockup | Estado visible en el sistema integrado |
|---|---|
| Autenticar usuario | Implementada. |
| Cerrar sesión | Implementada. |
| Consultar usuario | Parcial: buscador general, sin filtros avanzados. |
| Cambiar contraseña propia | Parcial: formulario diferente al documentado. |
| Registrar usuario | No visible. |
| Actualizar usuario | No visible. |
| Restablecer contraseña | No visible. |
| Asignar rol | Existe una sección y botón independiente. |
| Revocar rol | No se confirmó una opción visible específica. |
| Bloquear usuario | No visible. |
| Desbloquear usuario | No visible. |
| Activar usuario | No visible. |
| Dar de baja usuario | No visible. |
| Consultar parámetro | Implementada parcialmente mediante búsqueda general. |
| Registrar parámetro | Botón visible para Administrador. |
| Actualizar parámetro | No se ejecutó; existe permiso de actualización. |
| Consultar bitácora | Implementada parcialmente. |
| Filtros avanzados de bitácora | No visibles. |
| Exportar bitácora PDF/XLSX | Permiso existente, función no visible. |
| Configurar matriz rol–permiso | Estructura existente, pantalla no identificada. |
| Gestionar vehículo maestro | Parcialmente visible. |
| Gestionar PersonaVehículo | Parcialmente visible. |

---

## 9. Priorización recomendada

### Prioridad crítica

1. Corregir los módulos visibles para Administrador y Director.
2. Validar en backend que los perfiles no puedan acceder a módulos no autorizados.
3. Bloquear la navegación mientras el usuario tenga pendiente el cambio obligatorio de contraseña.
4. Revisar por qué la navegación genera eventos `UPDATE usuario_sistema`.
5. Garantizar la unicidad de la cédula de Persona.

### Prioridad alta

6. Implementar los casos completos de gestión de usuarios.
7. Crear permisos específicos para bloquear, desbloquear, activar, dar de baja, restablecer contraseña, asignar rol y revocar rol.
8. Añadir filtros avanzados a la bitácora.
9. Habilitar la exportación PDF/XLSX para los perfiles autorizados.
10. Reducir el alcance de consulta del Director bajo el principio de mínimo privilegio.

### Prioridad media

11. Incorporar `MAX_VEHICULOS_POR_PERSONA`.
12. Incorporar `LONGITUD_MINIMA_PASSWORD`.
13. Exponer una interfaz clara para la matriz rol–permiso.
14. Distinguir el cambio voluntario de contraseña del cambio obligatorio inicial.
15. Confirmar el valor definitivo de `MAX_INTENTOS_LOGIN`.

### Prioridad baja

16. Corregir tildes y consistencia de textos, por ejemplo “Máximo”, “sesión” y “autenticación”.
17. Mejorar los mensajes cuando una tabla no contiene registros.
18. Documentar formalmente las nuevas secciones incorporadas durante la integración.

---

## 10. Criterios recomendados para una nueva validación

La siguiente revisión debería comprobar:

- [ ] El Administrador solo visualiza ADM, salvo permiso temporal aprobado.
- [ ] El Director no visualiza Monitoreo.
- [ ] El Director solo consulta las entidades formalmente autorizadas.
- [ ] El Administrador puede ejecutar todos los casos de gestión de usuarios.
- [ ] Cada operación sensible posee un permiso independiente.
- [ ] El cambio obligatorio impide navegar hasta actualizar la contraseña.
- [ ] La bitácora diferencia autenticación, sesión y modificación de datos.
- [ ] Los filtros de auditoría funcionan por fecha, usuario, acción, resultado, entidad, módulo e IP.
- [ ] La exportación genera PDF y XLSX.
- [ ] `MAX_VEHICULOS_POR_PERSONA` está registrado y activo.
- [ ] `LONGITUD_MINIMA_PASSWORD` está registrado y activo.
- [ ] No existen personas diferentes con la misma cédula.
- [ ] La matriz rol–permiso puede consultarse y administrarse de forma controlada.
- [ ] Las rutas y endpoints rechazan accesos no autorizados con HTTP 403.
- [ ] El frontend y el backend aplican la misma autorización.

---

## 11. Conclusión

El sistema integrado cuenta con una base estructural sólida para ADM. Las entidades maestras, los roles, los permisos, las sesiones y la auditoría ya forman parte de una solución compartida entre módulos, lo que representa un avance significativo respecto al mockup aislado.

Sin embargo, la implementación todavía no refleja completamente la experiencia funcional definida para ADM. Las principales brechas se encuentran en la gestión de usuarios, la granularidad de permisos, el alcance excesivo del Director Administrativo, el acceso visible a Monitoreo, el cambio obligatorio de contraseña y las capacidades de filtrado y exportación de la bitácora.

Por tanto, el módulo puede considerarse **estructuralmente avanzado, pero funcionalmente parcial**. Antes de aprobarlo como implementación definitiva de ADM, deberían resolverse las diferencias críticas y altas descritas en este documento.

