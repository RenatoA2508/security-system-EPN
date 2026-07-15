-- Feedback ADM (§7.5): cada login generaba un evento "UPDATE usuario_sistema" en bitácora,
-- indistinguible de una modificación administrativa real. La causa es que registrar_sesion()
-- toca fecha_ultimo_login en cada login, y el trigger genérico registrar_bitacora() loguea
-- cualquier UPDATE sin distinguir qué cambió.
--
-- Se reemplaza el trigger de usuario_sistema por una versión que compara la fila completa
-- ignorando fecha_ultimo_login/fecha_modificacion: si eso es lo único que cambió, no es una
-- modificación administrativa real y no se registra en bitácora.

create or replace function public.registrar_bitacora_usuario_sistema()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_solo_login boolean;
begin
  if TG_OP = 'UPDATE' then
    v_solo_login := (to_jsonb(old) - 'fecha_ultimo_login' - 'fecha_modificacion')
                  = (to_jsonb(new) - 'fecha_ultimo_login' - 'fecha_modificacion');
    if v_solo_login then
      return new;
    end if;
  end if;

  insert into public.bitacora_sistema (
    id_usuario, accion, modulo, entidad_afectada, id_entidad_afectada,
    resultado, valor_anterior, valor_nuevo
  ) values (
    auth.uid(),
    TG_OP,
    'ADM',
    TG_TABLE_NAME,
    (to_jsonb(new) ->> 'id_usuario'),
    'EXITO',
    case when TG_OP = 'UPDATE' then to_jsonb(old) else null end,
    to_jsonb(new)
  );

  return new;
end;
$$;

drop trigger if exists trg_bitacora_usuario_sistema on public.usuario_sistema;
create trigger trg_bitacora_usuario_sistema
  after insert or update on public.usuario_sistema
  for each row execute function public.registrar_bitacora_usuario_sistema();
