-- ADM · El correo de una persona con cuenta es UNO SOLO.
--
-- Caso real que lo motiva: se registró a Lady Celina Velásquez con
-- lady.celina@epn.edu.ec, se corrigió en GPI a lady.velasquez@epn.edu.ec, y la cuenta
-- siguió entrando con el correo viejo. Tres almacenes sin nada que los uniera:
--
--   persona.correo                    ← lo edita GPI
--   usuario_sistema.correo_electronico ← lo edita ADM
--   auth.users.email                   ← es el que de verdad autentica
--
-- A partir de aquí los tres se mueven juntos, se toque el que se toque (el equipo pidió
-- que ADM también pueda cambiarlo). No hay "el que manda": hay UN correo guardado en tres
-- sitios que el sistema mantiene idénticos.
--
-- Se hace en SQL y no en una Edge Function a propósito: así la propagación ocurre dentro
-- de la MISMA transacción que el cambio. Si falla la validación, no se guarda nada y GPI
-- ve el error; con una función externa habría una ventana en la que persona ya estaría
-- cambiada y la credencial no — que es exactamente el fallo que estamos arreglando.

-- ---------------------------------------------------------------------------
-- 1. Escritura en el esquema auth (fuera del alcance de RLS).
-- ---------------------------------------------------------------------------
create or replace function public.sincronizar_correo_auth(p_id_usuario uuid, p_correo text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- GoTrue autentica por auth.users.email, pero conserva una copia en la identidad del
  -- proveedor 'email'. Actualizar solo una de las dos deja la cuenta en un estado
  -- incoherente que se manifiesta más tarde y cuesta mucho de diagnosticar.
  update auth.users
     set email = p_correo,
         -- Un cambio administrativo no deja un cambio de correo "a medias" pendiente de
         -- confirmar por el usuario.
         email_change = '',
         email_change_token_new = '',
         updated_at = now()
   where id = p_id_usuario
     and email is distinct from p_correo;

  update auth.identities
     set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(p_correo)),
         updated_at = now()
   where user_id = p_id_usuario
     and provider = 'email'
     and identity_data->>'email' is distinct from p_correo;
end;
$$;

comment on function public.sincronizar_correo_auth(uuid, text) is
  'Actualiza el correo de acceso en auth.users y en la identidad del proveedor email.';

revoke all on function public.sincronizar_correo_auth(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. usuario_sistema → auth + persona
-- ---------------------------------------------------------------------------
create or replace function public.propagar_correo_cuenta()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.correo_electronico is not distinct from old.correo_electronico then
    return new;
  end if;

  perform public.sincronizar_correo_auth(new.id_usuario, new.correo_electronico);

  -- Y de vuelta a la persona, para que GPI vea el mismo dato. El `is distinct from` del
  -- trigger de persona corta la recursión: al llegar allí los valores ya coinciden.
  update public.persona
     set correo = new.correo_electronico
   where id_persona = new.id_persona
     and correo is distinct from new.correo_electronico;

  return new;
end;
$$;

drop trigger if exists trg_propagar_correo_cuenta on public.usuario_sistema;
create trigger trg_propagar_correo_cuenta
  after update of correo_electronico on public.usuario_sistema
  for each row execute function public.propagar_correo_cuenta();

-- ---------------------------------------------------------------------------
-- 3. persona → usuario_sistema (que a su vez propaga a auth)
-- ---------------------------------------------------------------------------
create or replace function public.propagar_correo_persona()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id_usuario uuid;
  v_ocupado    text;
begin
  if new.correo is not distinct from old.correo then
    return new;
  end if;

  select id_usuario into v_id_usuario
    from public.usuario_sistema
   where id_persona = new.id_persona;

  -- Sin cuenta, el correo es solo un dato de contacto: no hay nada que sincronizar.
  if v_id_usuario is null then
    return new;
  end if;

  if new.correo is null or btrim(new.correo) = '' then
    raise exception 'No se puede dejar sin correo a % porque tiene una cuenta en el sistema: ese correo es su credencial de acceso.', new.nombres || ' ' || new.apellidos
      using errcode = 'check_violation',
            hint = 'Escribe el correo institucional correcto en vez de borrarlo.';
  end if;

  if not public.es_correo_institucional_epn(new.correo) then
    raise exception 'El correo % no es institucional, y esta persona lo usa para entrar al sistema.', new.correo
      using errcode = 'check_violation',
            hint = 'Debe ser una dirección @epn.edu.ec (o subdominio) o @cec.edu.ec.';
  end if;

  select nombre_usuario into v_ocupado
    from public.usuario_sistema
   where lower(correo_electronico) = lower(new.correo)
     and id_usuario <> v_id_usuario;

  if v_ocupado is not null then
    raise exception 'El correo % ya lo usa la cuenta "%".', new.correo, v_ocupado
      using errcode = 'unique_violation';
  end if;

  update public.usuario_sistema
     set correo_electronico = new.correo
   where id_usuario = v_id_usuario
     and correo_electronico is distinct from new.correo;

  return new;
end;
$$;

drop trigger if exists trg_propagar_correo_persona on public.persona;
create trigger trg_propagar_correo_persona
  after update of correo on public.persona
  for each row execute function public.propagar_correo_persona();

-- ---------------------------------------------------------------------------
-- 4. Reparar lo que ya está desincronizado.
--    Hoy solo Lady Celina, pero se hace en general por si aparece otro caso.
-- ---------------------------------------------------------------------------
do $$
declare
  v_fila record;
begin
  for v_fila in
    select u.id_usuario, u.nombre_usuario, p.correo as correo_persona, u.correo_electronico
      from public.usuario_sistema u
      join public.persona p on p.id_persona = u.id_persona
     where p.correo is not null
       and p.correo is distinct from u.correo_electronico
  loop
    raise notice 'Sincronizando % : % -> %', v_fila.nombre_usuario, v_fila.correo_electronico, v_fila.correo_persona;
    update public.usuario_sistema
       set correo_electronico = v_fila.correo_persona
     where id_usuario = v_fila.id_usuario;
  end loop;
end $$;
