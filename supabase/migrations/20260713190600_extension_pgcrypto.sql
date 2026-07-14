-- pgcrypto: necesaria para crypt()/gen_salt() al sembrar la contraseña del
-- primer administrador en seed.sql (§D13).
create extension if not exists pgcrypto with schema extensions;
