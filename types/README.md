`database.types.ts` está generado desde el esquema real del proyecto remoto
de Supabase (25 tablas + 2 vistas).

Regenerar tras un cambio de esquema:

```
npm run gen:types:linked   # contra el proyecto remoto (linked)
# o, con un stack local corriendo (supabase start):
npm run gen:types          # contra la base local
```
