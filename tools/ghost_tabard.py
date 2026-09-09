#!/usr/bin/env python3
"""Ghost tabard: a ghostly-blue recolour of the Contest Winner's Tabard, as a NEW item.

The Contest Winner's Tabard (item 19160, purple with the WoW logo) draws its design from two body-overlay textures,
Tabard_A_01ContestPVP_Chest_TU / _TL (male + female variants). To add a blue version WITHOUT changing the purple
original, we hijack a spare/deprecated tabard item the Ascension client already knows - "Unused Tabard of Chow"
(item 3557, ItemDisplayInfo 1680, which references the Tabard_A_01Lordaeron_Chest_TU / _TL textures, used by nothing
else and not even shipped in this client). We recolour the Contest textures to the ghost blue and write them out under
the Lordaeron names, so only item 3557 changes. The server side (rename 3557 -> the ghost tabard) is
mod-solo-ghost-tabard.sql.

Textures are written straight into client-patches/build-patchZ (gitignored), which build_ascension_client_patch.py
folds into patch-Z. Re-run this, then rebuild patch-Z.

usage: ghost_tabard.py [<client Data dir>]   (default C:\\Games\\solo-azeroth-client\\Data)
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import ghost_paladin as gp

PALETTE = "ghost"   # the signature ghostly blue (70,130,255); same as the paladin spell effects
BUILD = os.path.join(ROOT, "client-patches", "build-patchZ")

# (folder, source base, dest base) - the client appends _M / _F per gender
PARTS = [
    ("TorsoUpperTexture", "Tabard_A_01ContestPVP_Chest_TU", "Tabard_A_01Lordaeron_Chest_TU"),
    ("TorsoLowerTexture", "Tabard_A_01ContestPVP_Chest_TL", "Tabard_A_01Lordaeron_Chest_TL"),
]
GENDERS = ["M", "F"]


def main():
    data_dir = sys.argv[1] if len(sys.argv) > 1 else r"C:\Games\solo-azeroth-client\Data"
    client = gp.Client(data_dir)
    rgb = gp.make_mapper(PALETTE)
    written, missing = 0, 0
    for folder, src_base, dst_base in PARTS:
        for g in GENDERS:
            src = f"Item\\TextureComponents\\{folder}\\{src_base}_{g}.blp"
            data = client.read(src)
            if not data:
                print("  MISSING source:", src)
                missing += 1
                continue
            rec = gp.recolor_blp_inplace(data, rgb)
            if not rec:
                print("  could not recolour (unhandled BLP layout):", src)
                missing += 1
                continue
            dst = os.path.join(BUILD, "Item", "TextureComponents", folder, f"{dst_base}_{g}.blp")
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as f:
                f.write(rec)
            written += 1
            print("  wrote", os.path.relpath(dst, ROOT))
    print(f"ghost tabard: {written} textures written, {missing} missing. Now rebuild patch-Z.")
    if missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
