-- Saneamiento de los datos que ya existen, ANTES de aplicar los CHECK de
-- 20260716010200_constraints_validacion.sql. Sin este paso, los constraints
-- validados fallarian al aplicarse contra el proyecto remoto.
--
-- Todo lo de aqui es idempotente: se apoya en las funciones de validacion, asi
-- que una fila ya correcta no se toca.

-- ---------------------------------------------------------------------------
-- 1. Cedulas de prueba -> cedulas ficticias VALIDAS
-- ---------------------------------------------------------------------------
-- De las 19 personas del proyecto remoto solo 1 tenia una cedula que pasa el
-- algoritmo completo del Registro Civil (1756082184). Las otras 18 eran de
-- relleno: 9999999999 (provincia 99, inexistente), 1712345678, 1234567890,
-- 152711695 (9 digitos), y 1798765432, que parece valida pero tiene tercer
-- digito 9: eso identifica a una persona juridica, no a una natural.
--
-- Todas las cedulas nuevas son de Pichincha (17), tercer digito 5 (persona
-- natural) y traen el digito verificador correcto. Son FICTICIAS: no
-- corresponden a la cedula real de ninguna de estas personas, solo permiten
-- que el dato de prueba respete el formato del sistema.
--
-- Se emparejan por cedula anterior y no por nombre para no depender de tildes
-- ni de espacios. Las dos ya validas no aparecen: se dejan intactas.
do $$
declare
  v_mapa text[][] := array[
    -- cedula anterior , cedula ficticia valida , quien
    ['9999999999', '1750000000', 'Administrador del Sistema'],
    ['9999999998', '1750000018', 'Guardia Demo'],
    ['1712345000', '1750000026', 'Docente Demo'],
    ['1798765432', '1750000067', 'Visitante Demo'],
    ['1712345601', '1750000034', 'TuRostro Muestra2'],
    ['1712345604', '1750000042', 'Impostor Uno'],
    ['1712345603', '1750000059', 'Impostor Dos'],
    ['9999999990', '1750000109', 'Gary Defas'],
    ['9999999991', '1750000117', 'Lenin Amangandi'],
    ['9999999992', '1750000125', 'Joel Velastegui'],
    ['9999999993', '1750000133', 'Heidy Tenelema'],
    ['9999999994', '1750000141', 'Sebastian Chavez'],
    ['1712345678', '1750000208', 'Frank Jumbo'],
    ['1753142177', '1750000216', 'Victor Coyago'],
    ['152711695',  '1750000224', 'Camila Caicedo'],
    ['1753196852', '1750000232', 'Cecilia Jaramillo'],
    ['1752614802', '1750000240', 'Hernan Avellaneda'],
    ['1234567890', '1750000257', 'Alexander Guerra']
  ];
  i integer;
begin
  for i in 1 .. array_length(v_mapa, 1) loop
    -- Guardarrail: si la cedula nueva no pasara la validacion, se aborta la
    -- migracion entera en vez de dejar la BD a medio sanear.
    if not public.es_cedula_ecuatoriana(v_mapa[i][2]) then
      raise exception 'La cedula de reemplazo % (%) no es valida', v_mapa[i][2], v_mapa[i][3];
    end if;

    update public.persona
       set cedula = v_mapa[i][2]
     where cedula = v_mapa[i][1];
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Telefonos -> E.164 (+593)
-- ---------------------------------------------------------------------------
update public.persona
   set telefono_contacto = public.normalizar_telefono_ec(telefono_contacto)
 where telefono_contacto is not null
   and telefono_contacto is distinct from public.normalizar_telefono_ec(telefono_contacto);

update public.persona
   set telefono_respaldo = public.normalizar_telefono_ec(telefono_respaldo)
 where telefono_respaldo is not null
   and telefono_respaldo is distinct from public.normalizar_telefono_ec(telefono_respaldo);

-- ---------------------------------------------------------------------------
-- 2b. RUC: correccion del digito verificador
-- ---------------------------------------------------------------------------
-- De los 4 RUC del remoto, 2 pasan el algoritmo (CleanPro, sociedad privada; y
-- la Empresa Publica Metropolitana, sector publico) y 2 son de relleno. En
-- ambos casos basta corregir el digito verificador: se conserva la provincia,
-- el tipo de contribuyente y el establecimiento originales.
--   SecurCorp        0791798651001 -> 0791798655001 (privada, modulo 11: dv 5)
--   LimpiezaEcuador  1725384183001 -> 1725384182001 (natural, modulo 10: dv 2)
update public.empresa set ruc = '0791798655001' where ruc = '0791798651001';
update public.empresa set ruc = '1725384182001' where ruc = '1725384183001';

do $$
begin
  if exists (select 1 from public.empresa where ruc is not null and not public.es_ruc_ecuatoriano(ruc)) then
    raise exception 'Quedan RUC invalidos en empresa despues del saneamiento';
  end if;
end $$;

-- Nombres de empresa con espacio inicial (" SecurCorp Cia. Ltda.").
update public.empresa
   set nombre = public.normalizar_espacios(nombre)
 where nombre is distinct from public.normalizar_espacios(nombre);

-- ---------------------------------------------------------------------------
-- 3. Correos -> minusculas
-- ---------------------------------------------------------------------------
-- El remoto tiene "Victor.coyago@epn.edu.ec". El correo es case-insensitive en
-- la practica y ademas usuario_sistema.correo_electronico es UNIQUE: sin
-- normalizar, "A@epn.edu.ec" y "a@epn.edu.ec" serian dos cuentas distintas.
update public.persona set correo = lower(correo)
 where correo is not null and correo <> lower(correo);

update public.persona set correo_respaldo = lower(correo_respaldo)
 where correo_respaldo is not null and correo_respaldo <> lower(correo_respaldo);

update public.usuario_sistema set correo_electronico = lower(correo_electronico)
 where correo_electronico <> lower(correo_electronico);

-- ---------------------------------------------------------------------------
-- 4. Nombres -> sin espacios sobrantes
-- ---------------------------------------------------------------------------
-- Ej. "Victor Hugo " (con espacio final) en el proyecto remoto.
update public.persona
   set nombres = public.normalizar_espacios(nombres),
       apellidos = public.normalizar_espacios(apellidos)
 where nombres is distinct from public.normalizar_espacios(nombres)
    or apellidos is distinct from public.normalizar_espacios(apellidos);

-- Un apellido no lleva digitos. La unica fila afectada del remoto es el fixture
-- de pruebas de biometria "TuRostro Muestra2", que no se referencia por nombre
-- desde ningun script: se le quita el digito y conserva su significado.
update public.persona
   set apellidos = 'Muestra Dos'
 where nombres = 'TuRostro' and apellidos = 'Muestra2';

do $$
declare
  v_malos integer;
begin
  select count(*) into v_malos from public.persona
   where not public.es_nombre_persona(nombres) or not public.es_nombre_persona(apellidos);
  if v_malos > 0 then
    raise exception 'Quedan % filas de persona con nombres/apellidos que no pasan es_nombre_persona()', v_malos;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Placas -> forma canonica sin guion
-- ---------------------------------------------------------------------------
-- PDF-1234 -> PDF1234. Es la clave con la que comparara el OCR de placas.
update public.vehiculo
   set placa = public.normalizar_placa(placa)
 where placa is not null
   and placa is distinct from public.normalizar_placa(placa);

-- ---------------------------------------------------------------------------
-- 6. MAC -> forma canonica AA:BB:CC:DD:EE:FF
-- ---------------------------------------------------------------------------
-- Solo se reformatean las que tienen los 12 digitos hexadecimales completos
-- (sin importar como vinieran separadas). El remoto tiene una MAC corrupta,
-- '00:14:2B:44:14:1', a la que le falta un digito del ultimo octeto: no se
-- puede adivinar cual es, asi que se deja como esta y el CHECK de la migracion
-- siguiente va NOT VALID. Anotado en docs/99_DUDAS_PARA_EL_EQUIPO.md.
update public.dispositivo d
   set codigo_mac = (
     select array_to_string(
       array(select substr(upper(regexp_replace(d.codigo_mac, '[^0-9A-Fa-f]', '', 'g')), g, 2)
               from generate_series(1, 12, 2) as g),
       ':')
   )
 where d.codigo_mac is not null
   and length(regexp_replace(d.codigo_mac, '[^0-9A-Fa-f]', '', 'g')) = 12
   and d.codigo_mac is distinct from (
     select array_to_string(
       array(select substr(upper(regexp_replace(d.codigo_mac, '[^0-9A-Fa-f]', '', 'g')), g, 2)
               from generate_series(1, 12, 2) as g),
       ':')
   );

-- ---------------------------------------------------------------------------
-- 7. Aviso de lo que quede fuera de norma
-- ---------------------------------------------------------------------------
-- No se aborta: los CHECK de la migracion siguiente diran exactamente que fila
-- falla. Esto solo deja constancia en el log de la migracion.
do $$
declare
  v_cedulas integer;
  v_correos integer;
  v_placas integer;
begin
  select count(*) into v_cedulas from public.persona where not public.es_cedula_ecuatoriana(cedula);
  select count(*) into v_correos from public.persona where correo is not null and not public.es_correo(correo);
  select count(*) into v_placas  from public.vehiculo where placa is not null and not public.es_placa_ec(placa);

  if v_cedulas > 0 then raise warning 'Quedan % filas de persona con cedula invalida', v_cedulas; end if;
  if v_correos > 0 then raise warning 'Quedan % filas de persona con correo invalido', v_correos; end if;
  if v_placas  > 0 then raise warning 'Quedan % filas de vehiculo con placa invalida', v_placas; end if;
end $$;
