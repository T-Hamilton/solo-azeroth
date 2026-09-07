#!/usr/bin/env python3
"""Build client-patches/patch-Z.MPQ for an Ascension-copy client: stock GlueXML + stock class DBCs.

usage: build_ascension_client_patch.py <dbc dir> <GlueXML dir> [<GlueXML dir> ...]
  <dbc dir>      a folder with stock ChrClasses.dbc and CharBaseInfo.dbc (e.g. server/runtime/data/dbc after extraction)
  <GlueXML dir>  extracted Interface/GlueXML folders from the stock enUS MPQs, oldest first (later ones override)
"""
import os, shutil, subprocess, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
build = os.path.join(root, "client-patches", "build-patchZ")
if len(sys.argv) < 3:
    sys.exit(__doc__)
shutil.rmtree(build, ignore_errors=True)
glue = os.path.join(build, "Interface", "GlueXML"); dbc = os.path.join(build, "DBFilesClient")
os.makedirs(glue); os.makedirs(dbc)
for d in sys.argv[2:]:
    for f in os.listdir(d):
        shutil.copy(os.path.join(d, f), glue)
for f in ("ChrClasses.dbc", "CharBaseInfo.dbc"):
    shutil.copy(os.path.join(sys.argv[1], f), dbc)
out = os.path.join(root, "client-patches", "patch-Z.MPQ")
subprocess.check_call([sys.executable, os.path.join(root, "tools", "mpq_writer.py"), out, build])
subprocess.check_call([sys.executable, os.path.join(root, "tools", "mpq_verify.py"), out, build])
print("built", out)
