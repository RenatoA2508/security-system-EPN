-- BUG (PCO §"Cambiar heidy.tenelema por Heidy Tenelema").
--
-- No era un dato mal escrito: era RLS otra vez. El encabezado muestra el nombre de la `persona`
-- vinculada y, si no puede leerla, cae al nombre de la cuenta (AuthProvider.tsx:98 →
-- `p.persona ? ... : p.nombre_usuario`). Ninguna política dejaba a un usuario leer su propia
-- ficha de persona: solo ADM/GPI/GPE/CAC veían el directorio. Por eso la cuenta de PCO se
-- anunciaba como "Heidy.tenelema" y la de GPI o GPE harían lo mismo.
--
-- Renombrar la cuenta habría tapado el síntoma en una fila y lo habría dejado igual en las demás.
create or replace function public.persona_del_usuario_actual()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select us.id_persona from public.usuario_sistema us where us.id_usuario = auth.uid();
$$;

comment on function public.persona_del_usuario_actual() is
  'Persona vinculada a la cuenta autenticada. Aísla la consulta a usuario_sistema fuera de la política de persona.';

create policy persona_select_propia
  on public.persona for select
  using (id_persona = public.persona_del_usuario_actual());
