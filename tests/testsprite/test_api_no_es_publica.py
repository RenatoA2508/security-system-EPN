"""La API REST no expone nada sin autenticar.

Requerimientos_ADM añadió una vista nueva, `v_auditoria`, que cruza bitácora con
persona, usuario_sistema y sesion: es el objeto con más datos personales por fila de
todo el esquema. Una vista mal publicada habría sido una fuga silenciosa — ya pasó
una vez en este proyecto (migración 20260717021430, una vista que perdió
`security_invoker` al recrearse y quedó leyendo con permisos de su propietario).

Esta prueba comprueba la frontera más externa: sin credencial ninguna, PostgREST
tiene que rechazar la petición. No necesita ningún secreto, así que no caduca y se
puede volver a ejecutar dentro de seis meses.

La comprobación de que un ADM autenticado SÍ ve los datos correctos vive en las
pruebas de frontend del proyecto y en scripts/pruebas_adm_nuevas.sql.
"""

import requests

BASE = "https://hwfayejcwpmercvmmyvw.supabase.co/rest/v1"

# Todo lo que toca esta ronda de cambios, más las tablas que la vista cruza.
TABLAS_PROTEGIDAS = [
    "v_auditoria",
    "bitacora_sistema",
    "usuario_sistema",
    "usuario_rol",
    "sesion",
    "persona",
    "registro_biometrico",
    "parametro_sistema",
    "categoria_persona",
    "permiso",
    "rol",
]

TIMEOUT = 30


def test_ninguna_tabla_responde_sin_credencial():
    """Sin apikey ni Authorization, la respuesta nunca puede traer filas."""
    fallos = []
    for tabla in TABLAS_PROTEGIDAS:
        r = requests.get(f"{BASE}/{tabla}", params={"select": "*", "limit": 1}, timeout=TIMEOUT)
        if r.status_code == 200:
            fallos.append(f"{tabla}: HTTP 200 sin credencial (cuerpo: {r.text[:200]})")
        elif r.status_code not in (401, 403):
            fallos.append(f"{tabla}: HTTP {r.status_code}, se esperaba 401 o 403")
    assert not fallos, "Tablas alcanzables sin autenticar:\n" + "\n".join(fallos)


def test_la_vista_de_auditoria_no_filtra_datos_en_el_error():
    """Ni siquiera el mensaje de error puede llevar datos de la vista.

    Un error que devolviera la definición de la vista o una fila de ejemplo sería tan
    grave como devolver la tabla entera.
    """
    r = requests.get(f"{BASE}/v_auditoria", params={"select": "*", "limit": 1}, timeout=TIMEOUT)

    assert r.status_code in (401, 403), f"HTTP {r.status_code}, se esperaba 401 o 403"
    cuerpo = r.text.lower()
    for filtrado in ("gary.defas", "admin@epn.edu.ec", "1750000", "ejecutor_usuario", "usuario_accedido"):
        assert filtrado not in cuerpo, f"El error menciona {filtrado!r}: {r.text[:300]}"


def test_las_funciones_internas_no_son_invocables_sin_credencial():
    """Las RPC de sesión y permisos tampoco se pueden llamar desde fuera."""
    fallos = []
    for funcion in ("cerrar_sesion_admin", "desbloquear_intentos_login", "permisos_efectivos"):
        r = requests.post(f"{BASE}/rpc/{funcion}", json={}, timeout=TIMEOUT)
        if r.status_code == 200:
            fallos.append(f"{funcion}: HTTP 200 sin credencial")
    assert not fallos, "RPC ejecutables sin autenticar:\n" + "\n".join(fallos)
