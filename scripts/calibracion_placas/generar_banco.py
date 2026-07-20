#!/usr/bin/env python3
"""
Genera un banco de placas ecuatorianas para calibrar el lector del sistema.

POR QUÉ SINTÉTICO Y NO FOTOS REALES
-----------------------------------
Para calibrar un OCR hace falta saber la respuesta correcta de cada imagen. Un puñado de fotos
de internet no trae esa etiqueta y, sobre todo, no permite controlar la dificultad: aquí se
puede generar la misma placa con diez grados de desenfoque y ver exactamente dónde se rompe la
lectura. La forma de la placa (tipografía, proporciones, "ECUADOR" arriba, provincia abajo) se
reproduce según el modelo vigente en Ecuador.

EL CASO QUE HAY QUE CUBRIR
--------------------------
La prueba no será una placa metálica delante de la cámara, sino **una foto de una placa mostrada
en la pantalla de un celular**. Eso no es una versión más fácil del problema, es otra:

  - la pantalla emite luz en vez de reflejarla, así que el contraste se aplana;
  - aparece MOIRÉ, el patrón de interferencia entre la rejilla de píxeles del móvil y la del
    sensor de la webcam, que llena la imagen de rayas finas;
  - hay reflejos especulares del propio brillo de la pantalla;
  - la placa ocupa pocos píxeles, porque en el móvil se ve pequeña.

Cada una de esas degradaciones se simula por separado y combinada, para poder decir qué umbral
aguanta qué condiciones.

Uso:  python3 generar_banco.py <carpeta-destino> [placas-por-condicion]
"""

import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

# Las 24 letras de provincia que asigna la ANT (D y F no se usan como inicial).
LETRAS_PROVINCIA = "ABUCXHOEWGILRMVNQSPKTZYJ"
PROVINCIAS = {
    "A": "AZUAY", "B": "BOLIVAR", "U": "CANAR", "C": "CARCHI", "X": "COTOPAXI",
    "H": "CHIMBORAZO", "O": "EL ORO", "E": "ESMERALDAS", "W": "GALAPAGOS",
    "G": "GUAYAS", "I": "IMBABURA", "L": "LOJA", "R": "LOS RIOS", "M": "MANABI",
    "V": "MORONA SANTIAGO", "N": "NAPO", "Q": "ORELLANA", "S": "PASTAZA",
    "P": "PICHINCHA", "K": "SUCUMBIOS", "T": "TUNGURAHUA", "Z": "ZAMORA CHINCHIPE",
    "Y": "SANTA ELENA", "J": "SANTO DOMINGO",
}

ANCHO, ALTO = 800, 300  # proporción ~2.67:1, la de una placa ecuatoriana real


def buscar_fuente(negrita=True):
    """Una sans-serif ancha; la placa ecuatoriana usa una tipografía de ese estilo."""
    candidatas = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    if not negrita:
        candidatas = [c.replace("-Bold", "") for c in candidatas]
    for ruta in candidatas:
        if Path(ruta).exists():
            return ruta
    raise SystemExit("No se encontró ninguna fuente TrueType utilizable")


FUENTE = buscar_fuente()


def placa_aleatoria(rng):
    """Placa de particular: 3 letras (la 1ª de provincia) + 3 o 4 dígitos."""
    provincia = rng.choice(LETRAS_PROVINCIA)
    resto = "".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ") for _ in range(2))
    digitos = "".join(rng.choice("0123456789") for _ in range(rng.choice([3, 4])))
    return provincia + resto + digitos


def dibujar_placa(texto):
    """La placa limpia, de frente y bien iluminada. El punto de partida."""
    img = Image.new("RGB", (ANCHO, ALTO), "white")
    d = ImageDraw.Draw(img)

    # Borde exterior negro, como el troquelado de la placa real.
    d.rounded_rectangle([6, 6, ANCHO - 7, ALTO - 7], radius=26, outline="black", width=7)

    # Franja superior: el país. En la placa real va sobre fondo azul con la bandera.
    d.rounded_rectangle([13, 13, ANCHO - 14, 74], radius=18, fill=(20, 40, 120))
    f_pais = ImageFont.truetype(FUENTE, 40)
    d.text((ANCHO // 2, 44), "ECUADOR", font=f_pais, fill="white", anchor="mm")

    # El número, que es lo único que el OCR tiene que leer.
    con_guion = f"{texto[:3]}-{texto[3:]}"
    f_placa = ImageFont.truetype(FUENTE, 132)
    d.text((ANCHO // 2, 170), con_guion, font=f_placa, fill="black", anchor="mm")

    # Provincia abajo, en pequeño: ruido legítimo que el extractor debe saber descartar.
    f_prov = ImageFont.truetype(FUENTE, 30)
    d.text((ANCHO // 2, 258), PROVINCIAS.get(texto[0], "ECUADOR"), font=f_prov, fill="black", anchor="mm")

    return img


# ---------------------------------------------------------------------------
# Degradaciones
# ---------------------------------------------------------------------------

def perspectiva(img, fuerza, rng):
    """La cámara nunca está perfectamente perpendicular a la placa."""
    w, h = img.size
    dx, dy = w * fuerza, h * fuerza
    origen = [(0, 0), (w, 0), (w, h), (0, h)]
    destino = [
        (rng.uniform(0, dx), rng.uniform(0, dy)),
        (w - rng.uniform(0, dx), rng.uniform(0, dy)),
        (w - rng.uniform(0, dx), h - rng.uniform(0, dy)),
        (rng.uniform(0, dx), h - rng.uniform(0, dy)),
    ]
    coeffs = _coeficientes_perspectiva(destino, origen)
    return img.transform((w, h), Image.PERSPECTIVE, coeffs, Image.BICUBIC, fillcolor="gray")


def _coeficientes_perspectiva(pa, pb):
    matriz = []
    for p1, p2 in zip(pa, pb):
        matriz.append([p1[0], p1[1], 1, 0, 0, 0, -p2[0] * p1[0], -p2[0] * p1[1]])
        matriz.append([0, 0, 0, p1[0], p1[1], 1, -p2[1] * p1[0], -p2[1] * p1[1]])
    import numpy as np
    A = np.matrix(matriz, dtype=float)
    B = np.array(pb).reshape(8)
    return np.array(np.dot(np.linalg.inv(A.T * A) * A.T, B)).reshape(8)


def moire(img, intensidad, rng):
    """
    Patrón de interferencia entre la rejilla de píxeles de la pantalla y la del sensor.

    Es LA degradación característica de fotografiar una pantalla, y la que más daño hace a un
    OCR: mete bordes falsos de alta frecuencia por toda la imagen, justo donde el algoritmo
    busca los cantos de los caracteres.
    """
    w, h = img.size
    capa = Image.new("L", (w, h))
    px = capa.load()
    periodo = rng.uniform(2.5, 4.5)
    angulo = rng.uniform(-0.35, 0.35)
    for y in range(h):
        for x in range(w):
            v = math.sin((x * math.cos(angulo) + y * math.sin(angulo)) * (2 * math.pi / periodo))
            px[x, y] = int(128 + 127 * v)
    capa = capa.filter(ImageFilter.GaussianBlur(0.4))
    return Image.blend(img, Image.merge("RGB", (capa, capa, capa)), intensidad)


def brillo_pantalla(img, rng):
    """Reflejo especular: la mancha de luz que deja el brillo de la pantalla."""
    w, h = img.size
    capa = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(capa)
    cx, cy = rng.uniform(0.2, 0.8) * w, rng.uniform(0.1, 0.9) * h
    rx, ry = w * rng.uniform(0.25, 0.5), h * rng.uniform(0.3, 0.7)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=rng.randint(90, 170))
    capa = capa.filter(ImageFilter.GaussianBlur(w * 0.09))
    return Image.composite(Image.new("RGB", (w, h), "white"), img, capa)


def ruido(img, sigma, rng):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            n = int(rng.gauss(0, sigma))
            px[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n)),
            )
    return img


def escalar_ida_y_vuelta(img, factor):
    """La placa se ve pequeña en el móvil: se pierden píxeles y no vuelven."""
    w, h = img.size
    pequena = img.resize((max(40, int(w * factor)), max(15, int(h * factor))), Image.LANCZOS)
    return pequena.resize((w, h), Image.BICUBIC)


# ---------------------------------------------------------------------------
# Condiciones
# ---------------------------------------------------------------------------

def limpia(img, rng):
    return img


def leve(img, rng):
    img = perspectiva(img, 0.02, rng)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    return ruido(img, 4, rng)


def pantalla_movil(img, rng):
    """El caso de la demo: una foto de la placa en la pantalla de un celular."""
    img = escalar_ida_y_vuelta(img, rng.uniform(0.28, 0.45))
    img = perspectiva(img, 0.03, rng)
    img = moire(img, rng.uniform(0.10, 0.20), rng)
    img = brillo_pantalla(img, rng)
    img = ImageEnhance.Contrast(img).enhance(rng.uniform(0.62, 0.82))
    img = img.filter(ImageFilter.GaussianBlur(rng.uniform(0.7, 1.4)))
    return ruido(img, 6, rng)


def pantalla_movil_dificil(img, rng):
    """Lo mismo, pero con la pantalla más lejos, más torcida y con más reflejo."""
    img = escalar_ida_y_vuelta(img, rng.uniform(0.16, 0.26))
    img = perspectiva(img, 0.06, rng)
    img = moire(img, rng.uniform(0.20, 0.32), rng)
    img = brillo_pantalla(img, rng)
    img = brillo_pantalla(img, rng)
    img = ImageEnhance.Contrast(img).enhance(rng.uniform(0.45, 0.65))
    img = img.filter(ImageFilter.GaussianBlur(rng.uniform(1.2, 2.2)))
    return ruido(img, 10, rng)


def placa_real_dificil(img, rng):
    """Una placa metálica de verdad en malas condiciones, para no perder de vista ese caso."""
    img = perspectiva(img, 0.07, rng)
    img = ImageEnhance.Brightness(img).enhance(rng.uniform(0.45, 0.7))
    img = ImageEnhance.Contrast(img).enhance(rng.uniform(0.6, 0.85))
    img = img.filter(ImageFilter.GaussianBlur(rng.uniform(1.0, 1.8)))
    return ruido(img, 9, rng)


CONDICIONES = {
    "limpia": limpia,
    "leve": leve,
    "pantalla_movil": pantalla_movil,
    "pantalla_movil_dificil": pantalla_movil_dificil,
    "placa_real_dificil": placa_real_dificil,
}


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Uso: python3 generar_banco.py <carpeta-destino> [placas-por-condicion]")

    destino = Path(sys.argv[1])
    por_condicion = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    destino.mkdir(parents=True, exist_ok=True)

    rng = random.Random(20260719)  # semilla fija: el banco es reproducible
    indice = []

    for condicion, degradar in CONDICIONES.items():
        for i in range(por_condicion):
            texto = placa_aleatoria(rng)
            img = dibujar_placa(texto)
            img = degradar(img, rng)
            nombre = f"{condicion}_{i:03d}.png"
            img.save(destino / nombre)
            indice.append({"archivo": nombre, "placa": texto, "condicion": condicion})
        print(f"  {condicion}: {por_condicion} imágenes")

    (destino / "indice.json").write_text(json.dumps(indice, indent=2))
    print(f"\n  {len(indice)} imágenes en {destino}")


if __name__ == "__main__":
    main()
