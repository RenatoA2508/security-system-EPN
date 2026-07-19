-- §D58: una politica mas estrecha que la de la tabla padre no da error, deja el embed vacio.
-- regla_acceso_select admite ADM_MODULO_ACCEDER, CAC_REGLA_SELECT y CAC_VALIDACION_EJECUTAR;
-- la politica que acabo de crear para las garitas solo admitia CAC_REGLA_SELECT. El guardia,
-- que valida accesos con CAC_VALIDACION_EJECUTAR pero no administra reglas, habria visto la
-- regla con "Todas las garitas" — indistinguible de una regla sin restriccion de garita, y
-- justo al reves de lo que dice RF-CA-007.
drop policy regla_punto_select on public.regla_acceso_punto_control;

create policy regla_punto_select on public.regla_acceso_punto_control
  for select to authenticated
  using (
    public.tiene_permiso('ADM_MODULO_ACCEDER')
    or public.tiene_permiso('CAC_REGLA_SELECT')
    or public.tiene_permiso('CAC_VALIDACION_EJECUTAR')
  );

-- Anadir una garita a una regla existente es un INSERT en esta tabla, pero para el usuario es
-- una edicion de la regla. Exigir CAC_REGLA_INSERT dejaria a quien solo tiene UPDATE editando
-- horarios pero no garitas, sin ninguna razon que lo justifique.
drop policy regla_punto_insert on public.regla_acceso_punto_control;

create policy regla_punto_insert on public.regla_acceso_punto_control
  for insert to authenticated
  with check (
    public.tiene_permiso('CAC_REGLA_INSERT')
    or public.tiene_permiso('CAC_REGLA_UPDATE')
  );
