-- Hallazgo del Security Advisor de Supabase (revisión final de la sesión): las funciones de
-- trigger creadas en esta sesión quedaron expuestas como endpoints RPC invocables directamente
-- (PostgREST expone por defecto cualquier función del esquema public). No es su propósito —
-- solo deben dispararse automáticamente vía trigger, nunca por llamada directa del cliente.
-- Revocar EXECUTE no afecta el disparo del trigger (los triggers no dependen de que anon/
-- authenticated tengan permiso de ejecución directa sobre la función).

revoke execute on function public.registrar_bitacora_usuario_sistema() from anon, authenticated;
revoke execute on function public.validar_asignacion_dispositivo() from anon, authenticated;

-- guardias_disponibles() ya se autoprotege internamente (solo devuelve filas si el llamador
-- tiene permiso), pero no hay razón para que un cliente anónimo pueda invocarla siquiera.
revoke execute on function public.guardias_disponibles() from anon;
