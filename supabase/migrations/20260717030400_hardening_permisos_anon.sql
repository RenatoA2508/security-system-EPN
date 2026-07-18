-- Cierra la exposicion a `anon` detectada por los advisors de Supabase tras el
-- despliegue de la ronda de validaciones (lint 0028 anon_security_definer_function_executable).
--
-- Hallazgo: tres funciones SECURITY DEFINER quedaron ejecutables por el rol
-- `anon` (es decir, por cualquiera SIN iniciar sesion) a traves de
-- /rest/v1/rpc/<funcion>. Dos de ellas son funciones de TRIGGER, que nadie debe
-- poder invocar como RPC; se colaron porque se crearon DESPUES de
-- 20260715124700_endurecer_permisos_funciones_trigger.sql, que hizo el barrido.
--
--   registrar_bitacora_usuario_sistema()  -> trigger de bitacora (20260713191700)
--   validar_asignacion_dispositivo()      -> trigger de dispositivo (20260715051511)
--   guardias_disponibles()                -> RPC legitima, pero solo para
--                                            usuarios autenticados (PCO/CAC)
--
-- No se toca `rls_auto_enable()`: es una funcion de la plataforma Supabase, ya
-- aceptada como warning residual en docs/99_DUDAS_PARA_EL_EQUIPO.md.

-- Funciones de trigger: nadie las llama por RPC, en ningun rol.
revoke execute on function public.registrar_bitacora_usuario_sistema() from public, anon, authenticated;
revoke execute on function public.validar_asignacion_dispositivo() from public, anon, authenticated;

-- RPC legitima del frontend, pero exige sesion iniciada.
revoke execute on function public.guardias_disponibles() from public, anon;
grant execute on function public.guardias_disponibles() to authenticated;
