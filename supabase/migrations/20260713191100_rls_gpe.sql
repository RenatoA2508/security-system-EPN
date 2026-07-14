-- Politicas RLS: modulo GPE.
-- Fuente: docs/02_MATRIZ_PERMISOS_RLS.md "Modulo GPE".

-- ===== memorando =====
-- ADM/DIR via ADM_MODULO_ACCEDER (docs/99 E6). GUA tiene GPE_MEMORANDO_SELECT
-- concedido explicitamente en el seed; CAC (supervisor) via CAC_EVENTO_SELECT.
create policy memorando_select on public.memorando
  for select using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or public.tiene_permiso('GPE_MEMORANDO_SELECT')
    or public.tiene_permiso('CAC_EVENTO_SELECT')
  );
create policy memorando_insert_gpe on public.memorando
  for insert with check (public.tiene_permiso('GPE_MEMORANDO_INSERT'));
create policy memorando_update_gpe on public.memorando
  for update using (public.tiene_permiso('GPE_MEMORANDO_UPDATE'))
  with check (public.tiene_permiso('GPE_MEMORANDO_UPDATE'));

-- ===== persona_memorando =====
create policy persona_memorando_select on public.persona_memorando
  for select using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or public.tiene_permiso('GPE_PERSONA_MEMORANDO_SELECT')
    or public.tiene_permiso('CAC_EVENTO_SELECT')
  );
create policy persona_memorando_insert_gpe on public.persona_memorando
  for insert with check (public.tiene_permiso('GPE_PERSONA_MEMORANDO_INSERT'));
create policy persona_memorando_update_gpe on public.persona_memorando
  for update using (public.tiene_permiso('GPE_PERSONA_MEMORANDO_UPDATE'))
  with check (public.tiene_permiso('GPE_PERSONA_MEMORANDO_UPDATE'));

-- ===== autorizacion_visita_diaria =====
-- El guardia crea y revoca (§D3); CAC (supervisor) solo lee (docs/99 E8).
create policy autorizacion_visita_select on public.autorizacion_visita_diaria
  for select using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or public.tiene_permiso('GPE_AUTORIZACION_SELECT')
    or public.tiene_permiso('CAC_AUTORIZACION_SELECT')
  );
create policy autorizacion_visita_insert_gpe on public.autorizacion_visita_diaria
  for insert with check (public.tiene_permiso('GPE_AUTORIZACION_INSERT'));
create policy autorizacion_visita_insert_guardia on public.autorizacion_visita_diaria
  for insert with check (public.tiene_permiso('CAC_AUTORIZACION_INSERT'));
create policy autorizacion_visita_update_gpe on public.autorizacion_visita_diaria
  for update using (public.tiene_permiso('GPE_AUTORIZACION_UPDATE'))
  with check (public.tiene_permiso('GPE_AUTORIZACION_UPDATE'));
create policy autorizacion_visita_update_guardia on public.autorizacion_visita_diaria
  for update using (public.tiene_permiso('CAC_AUTORIZACION_UPDATE'))
  with check (public.tiene_permiso('CAC_AUTORIZACION_UPDATE'));
