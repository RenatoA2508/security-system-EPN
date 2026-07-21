-- Borrar un enrolamiento biométrico que salió mal (feedback GPI): la fila de
-- registro_biometrico se DESACTIVA (vigente=false, respetando "sin DELETE físico"; el
-- matching ya filtra vigente=true, así que deja de servir para el acceso) y la FOTO se
-- borra de Storage.
--
-- El bucket `registro-biometrico` tenía políticas de INSERT/SELECT/UPDATE pero NINGUNA de
-- DELETE, así que `storage.remove()` fallaba en silencio y la foto quedaba huérfana. Se añade
-- la política de DELETE con el mismo permiso que ya gobierna la modificación del enrolamiento
-- (GPI_BIOMETRIA_UPDATE), coherente con la desactivación de la fila.

drop policy if exists registro_biometrico_bucket_delete_gpi on storage.objects;
create policy registro_biometrico_bucket_delete_gpi on storage.objects
  for delete to authenticated
  using (bucket_id = 'registro-biometrico' and public.tiene_permiso('GPI_BIOMETRIA_UPDATE'));
