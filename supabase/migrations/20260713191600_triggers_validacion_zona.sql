-- Validacion de jerarquia de zona (§3.4 del PDF, nota de consolidacion):
-- un CAMPUS no puede tener id_zona_padre; un EDIFICIO/PARQUEADERO debe tener
-- un padre de tipo CAMPUS. Diferido desde el bloque 1.

create or replace function public.validar_jerarquia_zona()
returns trigger
language plpgsql
as $$
declare
  v_tipo_padre text;
begin
  if new.tipo_zona = 'CAMPUS' then
    if new.id_zona_padre is not null then
      raise exception 'Una zona CAMPUS no puede tener id_zona_padre (id_zona=%)', new.id_zona;
    end if;
  else
    if new.id_zona_padre is null then
      raise exception 'Una zona % debe tener un id_zona_padre de tipo CAMPUS (id_zona=%)', new.tipo_zona, new.id_zona;
    end if;

    select z.tipo_zona into v_tipo_padre from public.zona z where z.id_zona = new.id_zona_padre;

    if v_tipo_padre is distinct from 'CAMPUS' then
      raise exception 'El padre de una zona % debe ser de tipo CAMPUS (id_zona=%, id_zona_padre=%)',
        new.tipo_zona, new.id_zona, new.id_zona_padre;
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_validar_jerarquia_zona
before insert or update on public.zona
for each row execute function public.validar_jerarquia_zona();
