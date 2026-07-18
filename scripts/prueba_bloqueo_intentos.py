#!/usr/bin/env python3
"""Verifica el bloqueo de cuenta por intentos fallidos (MAX_INTENTOS_LOGIN / TIEMPO_BLOQUEO_CUENTA_MIN).

Comprueba lo que fallaba antes: tras N intentos fallidos, la contrasena CORRECTA
tampoco debia dejar entrar. Y ademas que el bloqueo sea real, no cosmetico:
llamando a GoTrue directamente (sin pasar por la Edge Function) tambien se rechaza,
porque la politica escribe auth.users.banned_until.

Uso (deja la cuenta desbloqueada al terminar):

    export SB_URL="https://<ref>.supabase.co"
    export SB_ANON="<anon key>"
    export SB_EMAIL="gary.defas@epn.edu.ec"     # cuenta de prueba (NO uses la de admin)
    export SB_PASSWORD="<clave correcta>"
    export SB_ADMIN_EMAIL="admin@epn.edu.ec"    # cuenta con ADM_USUARIO_DESBLOQUEAR
    export SB_ADMIN_PASSWORD="<clave admin>"
    python3 scripts/prueba_bloqueo_intentos.py

Sale con codigo 1 si alguna comprobacion falla.
"""
import json
import os
import sys
import urllib.error
import urllib.request

URL = os.environ["SB_URL"].rstrip("/")
ANON = os.environ["SB_ANON"]
EMAIL = os.environ.get("SB_EMAIL", "gary.defas@epn.edu.ec")
BUENA = os.environ["SB_PASSWORD"]
ADMIN_EMAIL = os.environ.get("SB_ADMIN_EMAIL", "admin@epn.edu.ec")
ADMIN_PASSWORD = os.environ.get("SB_ADMIN_PASSWORD", BUENA)
MALA = "claveIncorrecta-" + os.urandom(4).hex()

fallos = []


def pedir(path, cuerpo=None, token=None, metodo="POST"):
    datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
    req = urllib.request.Request(f"{URL}{path}", data=datos, method=metodo)
    req.add_header("apikey", ANON)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token or ANON}")
    try:
        with urllib.request.urlopen(req) as r:
            texto = r.read().decode()
            return r.status, (json.loads(texto) if texto.strip() else {})
    except urllib.error.HTTPError as e:
        texto = e.read().decode()
        return e.code, (json.loads(texto) if texto.strip() else {})


def login_proxy(password):
    return pedir("/functions/v1/iniciar-sesion", {"email": EMAIL, "password": password})


def comprobar(cond, desc):
    print(("  OK    " if cond else "  FALLA ") + desc)
    if not cond:
        fallos.append(desc)


print("0) Estado inicial")
cod, r = login_proxy(BUENA)
comprobar(cod == 200 and r.get("access_token"), "la cuenta entra con la contrasena correcta")

print("\n1) Intentos fallidos hasta agotar el maximo")
for i in range(1, 8):
    cod, r = login_proxy(MALA)
    print(f"   intento {i}: HTTP {cod} {r.get('error_code')} restantes={r.get('intentos_restantes')}")
    if cod == 423:
        break
comprobar(cod == 423 and r.get("error_code") == "account_locked", "la cuenta acaba bloqueada")

print("\n2) Contrasena CORRECTA con la cuenta bloqueada")
cod, r = login_proxy(BUENA)
comprobar(cod == 423 and r.get("error_code") == "account_locked",
          "la contrasena correcta NO permite entrar mientras dura el bloqueo")

print("\n3) Sin pasar por la Edge Function: GoTrue directo")
cod, r = pedir("/auth/v1/token?grant_type=password", {"email": EMAIL, "password": BUENA})
comprobar(cod != 200 and "access_token" not in r,
          "GoTrue tambien rechaza: el bloqueo no se puede esquivar")

print("\n4) Desbloqueo manual por el administrador")
cod, r = pedir("/auth/v1/token?grant_type=password", {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD})
tok = r.get("access_token")
comprobar(bool(tok), "el bloqueo de una cuenta no afecta a las demas")

if tok:
    cod, filas = pedir(
        f"/rest/v1/usuario_sistema?correo_electronico=eq.{EMAIL}&select=id_usuario,intentos_fallidos,bloqueado_hasta",
        token=tok, metodo="GET")
    fila = filas[0]
    comprobar(fila["bloqueado_hasta"] is not None, "ADM ve el bloqueo y el contador")

    cod, _ = pedir("/rest/v1/rpc/desbloquear_intentos_login", {"p_id_usuario": fila["id_usuario"]}, token=tok)
    comprobar(cod in (200, 204), "el administrador desbloquea manualmente")

    cod, r = login_proxy(BUENA)
    comprobar(cod == 200 and r.get("access_token"), "tras el desbloqueo la cuenta vuelve a entrar")

print("\n" + ("TODAS LAS COMPROBACIONES PASARON" if not fallos else f"FALLARON {len(fallos)}: {fallos}"))
sys.exit(1 if fallos else 0)
