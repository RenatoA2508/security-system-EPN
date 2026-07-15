-- Decisión de negocio confirmada por el usuario (docs/Req_Front/GPI_Nuevos_Requerimientos.pdf):
-- el personal de empresas de seguridad/limpieza contratadas se trata como INTERNO (biometría,
-- gestionado desde GPI), no como externo. Reemplaza la resolución conservadora anterior (F2 en
-- docs/99_DUDAS_FRONTEND.md, que lo dejaba EXTERNA siguiendo el dato semilla existente).
--
-- No hay personas con esta categoría todavía (verificado), así que no hace falta migrar filas
-- de persona.tipo_persona. Se agrega también su regla_acceso demo, igual que la de DOCENTE,
-- para que el flujo de reconocimiento facial funcione de inmediato para esta categoría.

update public.categoria_persona
set ambito = 'INTERNA'
where codigo_categoria = 'EMPRESA_SERVICIO';

insert into public.regla_acceso (nombre_regla, id_categoria, id_punto_control, horario_inicio, horario_fin, requiere_memorando, estado_regla, descripcion)
select
  'Demo EMPRESA_SERVICIO garita principal',
  c.id_categoria,
  '00000000-0000-0000-0000-000000000006',
  '00:00:00', '23:59:59',
  false, 'ACTIVA',
  'Personal de empresas de seguridad/limpieza contratadas, tratado como interno (biometría).'
from public.categoria_persona c
where c.codigo_categoria = 'EMPRESA_SERVICIO'
  and not exists (
    select 1 from public.regla_acceso r where r.id_categoria = c.id_categoria
  );
