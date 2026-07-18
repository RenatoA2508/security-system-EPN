-- ADM · Tildes en los textos que ve el usuario.
--
-- Pedido del equipo (Requerimientos_ADM): "corregir títulos y descripciones que aún no
-- tienen tildes, por ejemplo contraseña, sesión, máximo y auditoría."
--
-- La interfaz ya estaba revisada (lib/catalogos.ts traduce los códigos de catálogo), pero
-- las descripciones SEMBRADAS en la base no: los 106 permisos y los 7 roles se cargaron
-- sin tildes. Se notaba poco mientras la columna visible era el código técnico; ahora que
-- la pantalla de Permisos muestra la descripción como columna principal, se lee en cada
-- fila.
--
-- Se corrige con una lista de sustituciones y no a mano fila por fila: 113 textos escritos
-- uno a uno es donde se cuelan las erratas, y la función queda disponible para el próximo
-- lote de datos sembrados.
--
-- OJO con los plurales: "asignación" pierde la tilde en "asignaciones", igual que
-- "validación"/"validaciones". Por eso solo se sustituyen los singulares de esas palabras.
-- "categoría" sí la conserva en "categorías".

create or replace function public.acentuar_texto(texto text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  pares text[][] := array[
    -- Singulares que llevan tilde. Los plurales en -ciones NO la llevan, así que no
    -- aparecen aquí a propósito.
    ['asignacion', 'asignación'], ['validacion', 'validación'], ['autorizacion', 'autorización'],
    ['revocacion', 'revocación'], ['administracion', 'administración'], ['descripcion', 'descripción'],
    ['informacion', 'información'], ['operacion', 'operación'], ['atencion', 'atención'],
    ['supervision', 'supervisión'], ['direccion', 'dirección'], ['identificacion', 'identificación'],
    ['configuracion', 'configuración'], ['verificacion', 'verificación'],
    -- Sustantivos y adjetivos.
    ['vehiculos', 'vehículos'], ['vehiculo', 'vehículo'],
    ['biometricos', 'biométricos'], ['biometrico', 'biométrico'],
    ['biometricas', 'biométricas'], ['biometrica', 'biométrica'], ['biometria', 'biometría'],
    ['parametros', 'parámetros'], ['parametro', 'parámetro'],
    ['catalogos', 'catálogos'], ['catalogo', 'catálogo'],
    ['categorias', 'categorías'], ['categoria', 'categoría'],
    ['estadisticas', 'estadísticas'], ['estadistica', 'estadística'],
    ['auditoria', 'auditoría'], ['logica', 'lógica'], ['logico', 'lógico'],
    ['fisica', 'física'], ['fisico', 'físico'], ['geografica', 'geográfica'],
    ['automatica', 'automática'], ['automatico', 'automático'],
    ['electronico', 'electrónico'], ['electronica', 'electrónica'],
    ['telefono', 'teléfono'], ['numero', 'número'], ['codigo', 'código'],
    ['maximo', 'máximo'], ['minimo', 'mínimo'], ['ultimo', 'último'], ['ultima', 'última'],
    ['unico', 'único'], ['unica', 'única'], ['publico', 'público'], ['publica', 'pública'],
    ['historico', 'histórico'], ['historica', 'histórica'],
    ['sesion', 'sesión'], ['contrasena', 'contraseña'],
    ['ningun', 'ningún'], ['dia', 'día'], ['dias', 'días']
  ];
  i int;
  resultado text := texto;
begin
  if texto is null then
    return null;
  end if;
  for i in 1 .. array_length(pares, 1) loop
    -- \m y \M son los límites de palabra de Postgres: evitan que "dia" toque "diaria"
    -- o que "unico" toque "unicornio".
    resultado := regexp_replace(resultado, '\m' || pares[i][1] || '\M', pares[i][2], 'g');
    resultado := regexp_replace(
      resultado,
      '\m' || upper(left(pares[i][1], 1)) || substr(pares[i][1], 2) || '\M',
      upper(left(pares[i][2], 1)) || substr(pares[i][2], 2),
      'g'
    );
  end loop;
  return resultado;
end;
$$;

comment on function public.acentuar_texto(text) is
  'Repone las tildes de los textos sembrados sin ellas. Los plurales en -ciones no llevan tilde y por eso no están en la lista.';

update public.permiso
   set descripcion = public.acentuar_texto(descripcion)
 where descripcion is distinct from public.acentuar_texto(descripcion);

update public.rol
   set descripcion = public.acentuar_texto(descripcion)
 where descripcion is distinct from public.acentuar_texto(descripcion);

update public.categoria_persona
   set nombre_categoria = public.acentuar_texto(nombre_categoria)
 where nombre_categoria is distinct from public.acentuar_texto(nombre_categoria);
