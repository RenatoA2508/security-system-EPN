-- Corrige un error de la migración anterior. Revoqué EXECUTE a `authenticated` sobre las tres
-- funciones auxiliares de RLS siguiendo el patrón de las funciones de trigger, pero no son lo
-- mismo: una función de trigger la ejecuta el motor por dentro, mientras que una función usada
-- en el USING de una política se evalúa con los privilegios del rol que hace la consulta. Sin
-- EXECUTE, toda la política revienta con "permission denied for function".
--
-- Efecto observado antes de corregirlo: PCO recibía 403 al leer su propio perfil y las
-- asignaciones. Se restablece el grant a `authenticated` y se mantiene revocado para `anon`,
-- que es lo que pedía el advisor: sin sesión no se debe poder sondear qué cuentas son guardias.
grant execute on function public.persona_del_usuario_actual() to authenticated;
grant execute on function public.es_usuario_guardia(uuid)     to authenticated;
grant execute on function public.es_persona_de_guardia(uuid)  to authenticated;

revoke execute on function public.persona_del_usuario_actual() from anon, public;
revoke execute on function public.es_usuario_guardia(uuid)     from anon, public;
revoke execute on function public.es_persona_de_guardia(uuid)  from anon, public;
