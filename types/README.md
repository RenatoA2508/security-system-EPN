Este directorio recibe `database.types.ts`, generado por
`npm run gen:types` (`supabase gen types typescript --local`).

No se generó todavía: requiere una base local corriendo (`supabase start`,
que a su vez requiere Docker) o el proyecto remoto ya actualizado
(`supabase db push`). Ninguna de las dos condiciones estaba disponible en el
entorno donde se construyó este backend — ver
`docs/99_DUDAS_PARA_EL_EQUIPO.md` (E1).

Para generar los tipos:

```
supabase start          # requiere Docker
npm run gen:types        # escribe types/database.types.ts
```

o, tras aprobar `supabase db push` contra el proyecto remoto:

```
supabase gen types typescript --project-id <project_ref> > types/database.types.ts
```
