-- Hallazgo del linter de seguridad tras la ronda de CAC.
--
-- Las funciones nuevas quedaron ejecutables por el rol `anon`, es decir, SIN iniciar sesion, a
-- traves de /rest/v1/rpc/. El `revoke all ... from public` de las migraciones anteriores no
-- basto: `anon` recibe EXECUTE por los privilegios por defecto del esquema, asi que hay que
-- revocarselo de forma explicita.
--
-- La peor de las cuatro es `identificar_placa`: cualquiera con la URL del proyecto y la clave
-- publicable podia ir probando placas y quedarse con las que devuelven fila. Eso es enumerar
-- que vehiculos entran a la EPN, sin cuenta y sin dejar rastro en ninguna tabla. La funcion es
-- SECURITY DEFINER, asi que ni siquiera la RLS de `vehiculo` la frena.
--
-- Se cierran al minimo que necesita cada una:
--   * identificar_placa / persona_asociada_a_vehiculo -> solo service_role. Las llama la Edge
--     Function `reconocer-placa`, que ya autentica al usuario antes de responder. El navegador
--     nunca las invoca directamente.
--   * corregir_placa_ocr / regla_aplica_en_punto -> authenticated. No leen datos de nadie
--     (la primera es una funcion pura; la segunda solo dice si una regla cubre un punto), pero
--     no hay razon para exponerlas sin sesion.
--
-- Es el mismo criterio que ya seguia `identificar_por_descriptor`, que estaba bien cerrada:
-- ni anon ni authenticated pueden ejecutarla, solo service_role.

revoke execute on function public.identificar_placa(text) from anon, authenticated;
revoke execute on function public.persona_asociada_a_vehiculo(uuid, uuid) from anon, authenticated;
revoke execute on function public.corregir_placa_ocr(text) from anon;
revoke execute on function public.regla_aplica_en_punto(uuid, uuid) from anon;

grant execute on function public.identificar_placa(text) to service_role;
grant execute on function public.persona_asociada_a_vehiculo(uuid, uuid) to service_role;

-- `rls_auto_enable()` es un ayudante interno que activa RLS sobre las tablas nuevas. Que sea
-- invocable por cualquiera desde internet no tiene ningun sentido; es anterior a esta ronda,
-- pero se cierra ahora que el linter lo ha sacado a la luz.
revoke execute on function public.rls_auto_enable() from anon, authenticated;
