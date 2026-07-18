#!/usr/bin/env python3
"""Verifica el comportamiento de `sesion` con VARIOS dispositivos a la vez (req 29).

Simula dos dispositivos (PC y celular) autenticandose con la misma cuenta y
comprueba que cada uno gestiona SOLO su propia fila:

  1. cada dispositivo obtiene su propia fila, con su nombre de dispositivo,
     su preferencia de "recordar sesion" y su fecha/hora de apertura;
  2. las dos sesiones coexisten como ACTIVA;
  3. cerrar sesion en el PC NO cierra la del celular (regresion principal);
  4. la actividad de un dispositivo no refresca la del otro;
  5. el usuario SI puede cerrar deliberadamente otra sesion suya;
  6. otro usuario NO puede cerrar una sesion ajena.

Uso (no deja sesiones abiertas; las filas quedan como historico de auditoria):

    export SB_URL="https://<ref>.supabase.co"
    export SB_ANON="<anon key>"
    export SB_EMAIL="admin@epn.edu.ec"       # opcional
    export SB_PASSWORD="<clave>"             # obligatorio
    export SB_EMAIL_2="gary.defas@epn.edu.ec" # opcional, para la prueba 6
    python3 scripts/prueba_multisesion.py

Sale con codigo 1 si alguna comprobacion falla.
"""
import json
import os
import sys
import time
import urllib.request

URL = os.environ["SB_URL"].rstrip("/")
ANON = os.environ["SB_ANON"]
EMAIL = os.environ.get("SB_EMAIL", "admin@epn.edu.ec")
PASSWORD = os.environ["SB_PASSWORD"]
EMAIL_2 = os.environ.get("SB_EMAIL_2")

UA_PC = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
UA_CEL = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36"

fallos = []


def pedir(path, token=None, cuerpo=None, metodo="POST"):
    datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
    req = urllib.request.Request(f"{URL}{path}", data=datos, method=metodo)
    req.add_header("apikey", ANON)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req) as r:
        texto = r.read().decode()
        return json.loads(texto) if texto.strip() else None


def login(email=EMAIL):
    return pedir("/auth/v1/token?grant_type=password",
                 cuerpo={"email": email, "password": PASSWORD})["access_token"]


def comprobar(condicion, descripcion):
    print(("  OK    " if condicion else "  FALLA ") + descripcion)
    if not condicion:
        fallos.append(descripcion)


print("1) Dos dispositivos inician sesion con la misma cuenta")
tok_pc, tok_cel = login(), login()
s_pc = pedir("/rest/v1/rpc/registrar_sesion", tok_pc,
             {"p_recordar_sesion": True, "p_user_agent": UA_PC, "p_dispositivo": "Chrome en Windows"})
s_cel = pedir("/rest/v1/rpc/registrar_sesion", tok_cel,
              {"p_recordar_sesion": False, "p_user_agent": UA_CEL, "p_dispositivo": "Chrome en Android"})
id_pc, id_cel = s_pc["id_sesion"], s_cel["id_sesion"]
comprobar(id_pc != id_cel, "cada dispositivo obtiene su propia fila de sesion")
comprobar(s_pc["dispositivo_nombre"] == "Chrome en Windows", "se guarda el dispositivo del PC")
comprobar(s_cel["dispositivo_nombre"] == "Chrome en Android", "se guarda el dispositivo del celular")
comprobar(s_pc["recordar_sesion"] is True and s_cel["recordar_sesion"] is False,
          "recordar_sesion se guarda por dispositivo")
comprobar(s_pc["fecha_inicio"] and s_cel["fecha_inicio"], "se registra fecha y hora de apertura")

print("\n2) Ambas deben verse ACTIVAS a la vez")
est = {s["id_sesion"]: s["estado_sesion"] for s in
       pedir(f"/rest/v1/sesion?id_sesion=in.({id_pc},{id_cel})&select=id_sesion,estado_sesion", tok_pc, metodo="GET")}
comprobar(est.get(id_pc) == "ACTIVA" and est.get(id_cel) == "ACTIVA", "las dos sesiones coexisten como ACTIVA")

print("\n3) El PC cierra SU sesion: el celular no debe verse afectado")
pedir("/rest/v1/rpc/cerrar_sesion", tok_pc, {"p_id_sesion": id_pc})
por_id = {s["id_sesion"]: s for s in pedir(
    f"/rest/v1/sesion?id_sesion=in.({id_pc},{id_cel})&select=id_sesion,estado_sesion,fecha_cierre,motivo_cierre",
    tok_cel, metodo="GET")}
comprobar(por_id[id_pc]["estado_sesion"] == "CERRADA", "la sesion del PC queda CERRADA")
comprobar(por_id[id_pc]["fecha_cierre"] is not None, "se registra fecha y hora de cierre")
comprobar(por_id[id_pc]["motivo_cierre"] == "LOGOUT", "se registra el motivo de cierre")
comprobar(por_id[id_cel]["estado_sesion"] == "ACTIVA",
          "la sesion del CELULAR sigue ACTIVA (regresion principal)")

print("\n4) La actividad del celular no debe tocar la fila del PC")
antes = pedir(f"/rest/v1/sesion?id_sesion=eq.{id_pc}&select=fecha_ultima_actividad", tok_cel, metodo="GET")[0]
time.sleep(1.2)
pedir("/rest/v1/rpc/tocar_sesion", tok_cel, {"p_id_sesion": id_cel})
act = {s["id_sesion"]: s["fecha_ultima_actividad"] for s in pedir(
    f"/rest/v1/sesion?id_sesion=in.({id_pc},{id_cel})&select=id_sesion,fecha_ultima_actividad", tok_cel, metodo="GET")}
comprobar(act[id_pc] == antes["fecha_ultima_actividad"],
          "la actividad del celular NO modifica la ultima actividad del PC")
comprobar(act[id_cel] != s_cel["fecha_ultima_actividad"],
          "si actualiza la ultima actividad del propio celular")

print("\n5) El usuario SI puede cerrar deliberadamente otra sesion suya (req 29)")
tok_pc2 = login()
s_pc2 = pedir("/rest/v1/rpc/registrar_sesion", tok_pc2, {"p_dispositivo": "Chrome en Windows"})
pedir("/rest/v1/rpc/cerrar_sesion", tok_pc2, {"p_id_sesion": id_cel})
comprobar(pedir(f"/rest/v1/sesion?id_sesion=eq.{id_cel}&select=estado_sesion", tok_pc2, metodo="GET")[0]
          ["estado_sesion"] == "CERRADA", "puede cerrar otra sesion PROPIA desde otro dispositivo")

print("\n6) Un usuario NO puede cerrar la sesion de OTRO usuario (seguridad)")
if EMAIL_2:
    tok_otro = login(EMAIL_2)
    victima = pedir("/rest/v1/rpc/registrar_sesion", tok_pc2, {"p_dispositivo": "Sesion objetivo"})
    pedir("/rest/v1/rpc/cerrar_sesion", tok_otro, {"p_id_sesion": victima["id_sesion"]})
    comprobar(pedir(f"/rest/v1/sesion?id_sesion=eq.{victima['id_sesion']}&select=estado_sesion",
                    tok_pc2, metodo="GET")[0]["estado_sesion"] == "ACTIVA",
              "otro usuario NO puede cerrar una sesion ajena")
    pedir("/rest/v1/rpc/cerrar_sesion", tok_pc2, {"p_id_sesion": victima["id_sesion"]})
else:
    print("  (omitida: define SB_EMAIL_2 para ejecutarla)")

print("\n7) Limpieza: se cierran las sesiones de prueba")
pedir("/rest/v1/rpc/cerrar_sesion", tok_pc2, {"p_id_sesion": s_pc2["id_sesion"]})

print("\n" + ("TODAS LAS COMPROBACIONES PASARON" if not fallos else f"FALLARON {len(fallos)}: {fallos}"))
sys.exit(1 if fallos else 0)
