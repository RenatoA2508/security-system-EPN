-- ADM · El administrador puede dar de alta personal interno.
--
-- Pedido del equipo: "no tiene sentido tener que entrar con las credenciales de GPI para
-- ingresar un usuario y luego tener que volver a entrar al admin para poder asignarle un
-- rol". Hoy ADM solo puede crear la CUENTA de una persona que ya exista, así que el alta
-- de un responsable nuevo obliga a dos sesiones y dos personas.
--
-- La persona sigue siendo entidad maestra ÚNICA (CLAUDE.md): esto no crea una copia ni una
-- tabla paralela, solo da a ADM la misma puerta que ya tiene GPI, acotada a INTERNA — el
-- personal externo es de GPE y no puede tener cuenta.
--
-- El permiso es nuevo y granular (ADM_PERSONA_INSERT) en vez de reutilizar
-- GPI_PERSONA_INSERT: así la matriz sigue diciendo la verdad sobre quién puede qué, y se
-- puede retirar sin tocar a GPI. Actualiza docs/02_MATRIZ_PERMISOS_RLS.md.

insert into public.permiso (codigo_permiso, descripcion, estado_permiso)
values ('ADM_PERSONA_INSERT', 'Crear personas internas (alta de cuenta desde Administración)', 'ACTIVO')
on conflict (codigo_permiso) do nothing;

-- Solo el Administrador del Sistema. El Director Administrativo es de consulta y no
-- modifica ningún dato (su descripción de rol lo dice explícitamente).
insert into public.rol_permiso (id_rol, id_permiso)
select r.id_rol, p.id_permiso
  from public.rol r, public.permiso p
 where r.nombre_rol = 'ADMINISTRADOR_SISTEMA'
   and p.codigo_permiso = 'ADM_PERSONA_INSERT'
on conflict do nothing;

drop policy if exists persona_insert_adm on public.persona;
create policy persona_insert_adm on public.persona
  for insert
  with check (public.tiene_permiso('ADM_PERSONA_INSERT') and tipo_persona = 'INTERNA');

comment on policy persona_insert_adm on public.persona is
  'ADM da de alta personal interno para poder crear su cuenta sin depender de GPI. Externas quedan fuera: no pueden tener cuenta.';
