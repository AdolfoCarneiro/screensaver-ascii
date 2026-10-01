#!/usr/bin/env python3
"""Baixa sprites de FireRed/LeafGreen (PokeAPI) dos 151 de Kanto e monta o cache do screensaver.

Precisa de internet e do Pillow só na hora de gerar; o screensaver lê só o pokemon.json.
"""
import io
import json
import os
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

BASE = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-iii/firered-leafgreen/"
API = "https://pokeapi.co/api/v2/"
DESTINO = os.path.expanduser("~/.local/share/screensaver-ascii/pokemon.json")
TIPOS = ["normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison", "ground", "flying",
         "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy"]
NOMES_ESPECIAIS = {"nidoran-f": "NIDORAN♀", "nidoran-m": "NIDORAN♂", "mr-mime": "MR. MIME", "farfetchd": "FARFETCH'D"}


def baixar(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "screensaver-ascii"}), timeout=30) as r:
        return r.read()


def sprite(caminho):
    im = Image.open(io.BytesIO(baixar(BASE + caminho))).convert("RGBA")
    w, h = im.size
    pal, dados = [], []
    for y in range(h):
        linha = []
        for x in range(w):
            r, g, b, a = im.getpixel((x, y))
            if a < 128:
                linha.append(".")
                continue
            c = (r << 16) | (g << 8) | b
            if c not in pal:
                pal.append(c)
            linha.append("0123456789abcdefghijklmnopqrstuvwxyz"[pal.index(c)])
        dados.append("".join(linha))
    return {"w": w, "h": h, "pal": pal, "px": dados}


def main():
    nomes = [p["name"] for p in json.loads(baixar(API + "pokemon?limit=151"))["results"]]
    tipos = {}
    for t in TIPOS:
        for p in json.loads(baixar(API + "type/" + t))["pokemon"]:
            num = int(p["pokemon"]["url"].rstrip("/").split("/")[-1])
            if num <= 151:
                tipos.setdefault(num, []).append((p["slot"], "normal" if t == "fairy" else t))
    trabalhos = [(n, k, c) for n in range(1, 152)
                 for k, c in (("f", f"{n}.png"), ("b", f"back/{n}.png"), ("fs", f"shiny/{n}.png"), ("bs", f"back/shiny/{n}.png"))]
    with ThreadPoolExecutor(8) as ex:
        res = list(ex.map(lambda tr: (tr[0], tr[1], sprite(tr[2])), trabalhos))
    saida = {}
    for n in range(1, 152):
        nome = nomes[n - 1]
        tps = [t.upper() for _s, t in sorted(tipos.get(n, [(1, "normal")]))]
        tps = list(dict.fromkeys(tps))
        saida[n] = {"nome": NOMES_ESPECIAIS.get(nome, nome.upper()), "tipos": tps}
    for n, k, s in res:
        saida[n][k] = s
    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    with open(DESTINO, "w") as f:
        json.dump(saida, f, separators=(",", ":"))
    print("ok:", len(saida), "Pokémon ->", DESTINO, os.path.getsize(DESTINO) // 1024, "KB")


if __name__ == "__main__":
    main()
