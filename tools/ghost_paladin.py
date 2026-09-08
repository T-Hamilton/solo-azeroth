#!/usr/bin/env python3
"""Ghost Paladin: recolour every paladin spell effect from gold to a ghostly white/blue fade, paladin-only.

Spell effects are client data: Spell.dbc -> SpellVisual -> SpellVisualKit -> SpellVisualEffectName -> .m2 model
(+ .skin) -> .blp textures, with the colour baked into the textures and into the particle / ribbon / vertex colour
tracks of the models. This tool clones that whole chain for the paladin spells under new ids and file names, recolours
the copies, and writes the result into client-patches/ghost-paladin/ for build_ascension_client_patch.py to fold into
patch-Z. Priests and everyone else keep their gold.

usage: ghost_paladin.py scan  <stock dbc dir> <client Data dir>     list what is involved, change nothing
       ghost_paladin.py build <stock dbc dir> <client Data dir> [--palette ghost|purple]
"""
import glob, io, os, re, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "client-patches", "ghost-paladin")

# ---------------------------------------------------------------- DBC ------------------------------------------------

class Dbc:
    def __init__(self, path):
        with open(path, "rb") as f:
            magic, self.n, self.fields, self.rs, ss = struct.unpack("<4sIIII", f.read(20))
            assert magic == b"WDBC", path
            data = f.read(self.n * self.rs)
            self.strings = bytearray(f.read(ss))
        assert self.rs == self.fields * 4, (path, self.rs, self.fields)
        self.rows = [list(struct.unpack("<%di" % self.fields, data[i * self.rs:(i + 1) * self.rs])) for i in range(self.n)]
        self.by_id = {r[0]: r for r in self.rows}

    def s(self, off):
        e = self.strings.find(b"\0", off)
        return self.strings[off:e].decode("utf-8", "replace")

    def add_string(self, text):
        off = len(self.strings)
        self.strings += text.encode("utf-8") + b"\0"
        return off

    def next_id(self):
        return max(self.by_id) + 1

    def append(self, row):
        self.rows.append(row)
        self.by_id[row[0]] = row
        return row

    def write(self, path):
        with open(path, "wb") as f:
            f.write(struct.pack("<4sIIII", b"WDBC", len(self.rows), self.fields, self.rs, len(self.strings)))
            for r in self.rows:
                f.write(struct.pack("<%di" % self.fields, *r))
            f.write(self.strings)


# field indices (3.3.5a)
SPELL_VISUAL = (131, 132)
SPELL_FAMILY = 208
SPELL_NAME = 136
SV_KITS = (1, 2, 3, 4, 5, 6, 14, 15, 22, 23, 24, 25)   # precast, cast, impact, state, statedone, channel, casterimpact, targetimpact, missiletargeting, instantarea, impactarea, persistentarea
SV_MISSILE_MODEL = 8
KIT_EFFECTS = tuple(range(3, 15))   # head, chest, base, lefthand, righthand, breath, leftweapon, rightweapon, special1-3, world
EFN_NAME, EFN_FILE = 1, 2


# ---------------------------------------------------------------- MPQ ------------------------------------------------

class Client:
    """Every MPQ of the client, later patches overriding earlier ones (stock load order)."""
    def __init__(self, data_dir):
        import mpyq
        self.archives = []
        names = [p for p in glob.glob(os.path.join(data_dir, "*.MPQ")) + glob.glob(os.path.join(data_dir, "*.mpq"))]
        names += glob.glob(os.path.join(data_dir, "enUS", "*.MPQ")) + glob.glob(os.path.join(data_dir, "enUS", "*.mpq"))
        def order(p):
            b = os.path.basename(p).lower()
            base = ["common.mpq", "common-2.mpq", "expansion.mpq", "lichking.mpq", "patch.mpq", "patch-2.mpq", "patch-3.mpq"]
            if b in base:
                return (0, base.index(b))
            if "enus" in p.lower() and not b.startswith("patch-"):
                return (1, b)
            return (2, b)   # patch-A..Z and the locale patches
        for p in sorted(names, key=order):
            try:
                a = mpyq.MPQArchive(p)
                files = a.files or []
            except Exception:
                continue
            index = {f.decode("latin1").lower().replace("/", "\\"): f for f in files}
            self.archives.append((p, a, index))

    def read(self, path):
        key = path.lower().replace("/", "\\")
        if key.endswith(".mdx") or key.endswith(".mdl"):
            key = key[:-4] + ".m2"   # the DBC names the old format; the files are M2
        for p, a, index in reversed(self.archives):   # last loaded wins
            f = index.get(key)
            if f is not None:
                try:
                    data = a.read_file(f)
                except Exception:
                    data = None
                if data:
                    return data
        return None


# ---------------------------------------------------------------- M2 -------------------------------------------------

def m2_textures(m2):
    """Hard-coded texture filenames of a WotLK (v264) M2: list of (lenOfs, filename)."""
    n, ofs = struct.unpack_from("<II", m2, 80)
    out = []
    for i in range(n):
        ttype, flags, ln, fofs = struct.unpack_from("<IIII", m2, ofs + i * 16)
        if ttype == 0 and ln > 1:
            name = m2[fofs:fofs + ln].split(b"\0")[0].decode("latin1")
            out.append((ofs + i * 16, ln, fofs, name))
    return out


def m2_path(dbc_name):
    """DBC file name (.mdx) -> the M2 file the client actually loads."""
    base = dbc_name[:-4] if dbc_name.lower().endswith((".mdx", ".mdl")) else dbc_name
    return base + ".m2" if not base.lower().endswith(".m2") else base


def skin_names(m2path):
    base = m2path[:-3] if m2path.lower().endswith(".m2") else m2path
    return ["%s0%d.skin" % (base, i) for i in range(4)]


# ---------------------------------------------------------------- walk -----------------------------------------------

def walk(dbc_dir):
    spell = Dbc(os.path.join(dbc_dir, "Spell.dbc"))
    sv = Dbc(os.path.join(dbc_dir, "SpellVisual.dbc"))
    kit = Dbc(os.path.join(dbc_dir, "SpellVisualKit.dbc"))
    efn = Dbc(os.path.join(dbc_dir, "SpellVisualEffectName.dbc"))

    pal_spells = [r for r in spell.rows if r[SPELL_FAMILY] == 10]
    visuals = sorted({r[i] for r in pal_spells for i in SPELL_VISUAL if r[i] > 0 and r[i] in sv.by_id})
    kits, efns = set(), set()
    for v in visuals:
        row = sv.by_id[v]
        for i in SV_KITS:
            if row[i] > 0 and row[i] in kit.by_id:
                kits.add(row[i])
        if row[SV_MISSILE_MODEL] > 0 and row[SV_MISSILE_MODEL] in efn.by_id:
            efns.add(row[SV_MISSILE_MODEL])
    for k in kits:
        for i in KIT_EFFECTS:
            e = kit.by_id[k][i]
            if e > 0 and e in efn.by_id:
                efns.add(e)
    models = sorted({efn.s(efn.by_id[e][EFN_FILE]) for e in efns if efn.s(efn.by_id[e][EFN_FILE])})
    return spell, sv, kit, efn, pal_spells, visuals, sorted(kits), sorted(efns), models


# ---------------------------------------------------------------- colour ---------------------------------------------

PALETTES = {
    # luminance 0 -> 1: black -> mid -> bright, with the mid and bright stops carrying the same luminance as the input
    # (so additive glows keep their falloff: black stays black, a bright yellow core becomes a bright blue-white core).
    "ghost":  [(0, 0, 0), (70, 130, 255), (236, 248, 255)],
    "purple": [(0, 0, 0), (150, 70, 235), (240, 226, 255)],
}


def make_mapper(palette):
    lo, mid, hi = PALETTES[palette]

    def grad(l):
        if l < 0.5:
            t = l / 0.5
            return tuple(lo[i] + (mid[i] - lo[i]) * t for i in range(3))
        t = (l - 0.5) / 0.5
        return tuple(mid[i] + (hi[i] - mid[i]) * t for i in range(3))

    def rgb(r, g, b):
        mx, mn = max(r, g, b), min(r, g, b)
        sat = 0.0 if mx == 0 else (mx - mn) / float(mx)
        # ease in with saturation: white / grey cores and smoke are left alone, faint tints are nudged, colour is
        # remapped fully. A hard cutoff here left a grey disc in the middle of every glow.
        w = min(1.0, max(0.0, (sat - 0.06) / 0.25))
        if w <= 0.0:
            return (r, g, b)
        lum = (0.30 * r + 0.59 * g + 0.11 * b) / 255.0
        tr, tg, tb = grad(lum)
        return tuple(int(round(min(255.0, max(0.0, o * (1.0 - w) + t * w))))
                     for o, t in ((r, tr), (g, tg), (b, tb)))

    return rgb


def recolor_blp_inplace(data, rgb):
    """Recolour a BLP without re-encoding it: the palette of a palettised texture, or the two colour endpoints of
    every DXT block. Alpha, mip chain and compression bytes are untouched, so the shape of every effect stays
    byte-identical. Returns the new bytes, or None for a layout this does not handle."""
    buf = bytearray(data)
    magic = bytes(buf[:4])

    def map565(v):
        r = ((v >> 11) & 31) * 255 // 31
        g = ((v >> 5) & 63) * 255 // 63
        b = (v & 31) * 255 // 31
        nr, ng, nb = rgb(r, g, b)
        return ((nr * 31 + 127) // 255 << 11) | ((ng * 63 + 127) // 255 << 5) | ((nb * 31 + 127) // 255)

    def remap_palette(ofs):
        for i in range(256):
            b, g, r, a = buf[ofs + i * 4:ofs + i * 4 + 4]
            nr, ng, nb = rgb(r, g, b)
            buf[ofs + i * 4:ofs + i * 4 + 4] = bytes((nb, ng, nr, a))

    def remap_dxt(ofs, size, block_size):
        color_ofs = block_size - 8   # DXT3/5 carry an 8-byte alpha block first
        for pos in range(ofs, ofs + size - block_size + 1, block_size):
            c = pos + color_ofs
            c0, c1 = struct.unpack_from("<HH", buf, c)
            n0, n1 = map565(c0), map565(c1)
            if block_size == 8:
                # DXT1 encodes its mode in the endpoint order: c0 > c1 = four colours, c0 <= c1 = three + transparent.
                # Keep the mode: swap the endpoints back and flip the index bits (0<->1, 2<->3) if the order changed.
                four = c0 > c1
                if four and n0 <= n1:
                    if n0 < n1:
                        # swapping the endpoints swaps the two interpolants as well, so flipping every index's low
                        # bit (0<->1, 2<->3) reproduces the block exactly
                        n0, n1 = n1, n0
                        idx = struct.unpack_from("<I", buf, c + 4)[0] ^ 0x55555555
                        struct.pack_into("<I", buf, c + 4, idx)
                    else:
                        # equal after mapping: nudge one unit apart to stay in four-colour mode
                        if n1 > 0:
                            n1 -= 1
                        else:
                            n0 += 1
                elif not four and n0 > n1:
                    # three-colour + transparent mode: index 3 is "transparent", so the indices cannot be flipped;
                    # pull the endpoints together instead (a one-block loss of shading, transparency kept)
                    n0 = n1
            struct.pack_into("<HH", buf, c, n0, n1)

    if magic == b"BLP2":
        compression, alpha_depth, alpha_type, has_mips = buf[8], buf[9], buf[10], buf[11]
        offsets = struct.unpack_from("<16I", buf, 20)
        sizes = struct.unpack_from("<16I", buf, 84)
        if compression == 1:
            remap_palette(148)
        elif compression == 2:
            block = 8 if alpha_depth <= 1 else 16
            for o, s in zip(offsets, sizes):
                if o and s:
                    remap_dxt(o, s, block)
        elif compression == 3:
            for o, s in zip(offsets, sizes):
                for p in range(o, o + s - 3, 4):
                    b, g, r, a = buf[p:p + 4]
                    nr, ng, nb = rgb(r, g, b)
                    buf[p:p + 4] = bytes((nb, ng, nr, a))
        else:
            return None
        return bytes(buf)

    if magic == b"BLP1":
        compression = struct.unpack_from("<I", buf, 4)[0]
        if compression != 1:
            return None   # JPEG-encoded BLP1: leave it
        remap_palette(28 + 64 + 64)
        return bytes(buf)

    return None


def recolor_image(im, rgb):
    im = im.convert("RGBA")
    px = im.load()
    cache = {}
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            key = (r, g, b)
            out = cache.get(key)
            if out is None:
                out = cache[key] = rgb(r, g, b)
            px[x, y] = (out[0], out[1], out[2], a)
    return im


def write_blp2(im, path):
    """Uncompressed BLP2 (BGRA, 8-bit alpha) with a full mip chain. Read by the 3.3.5 client without fuss."""
    im = im.convert("RGBA")
    w, h = im.size
    mips = []
    cur = im
    while True:
        mips.append(cur)
        if cur.size == (1, 1) or len(mips) == 16:
            break
        cur = cur.resize((max(1, cur.size[0] // 2), max(1, cur.size[1] // 2)), Image.LANCZOS)
    header_size = 4 + 4 + 4 + 4 + 4 + 64 + 64 + 1024
    offsets, sizes, blobs = [], [], []
    pos = header_size
    for m in mips:
        raw = bytearray()
        for r, g, b, a in m.getdata():
            raw += bytes((b, g, r, a))
        offsets.append(pos)
        sizes.append(len(raw))
        blobs.append(bytes(raw))
        pos += len(raw)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"BLP2")
        f.write(struct.pack("<I", 1))            # type 1 = BLP2 content
        f.write(bytes((3, 8, 0, 1)))             # compression 3 = uncompressed, alpha depth 8, alpha type 0, has mips
        f.write(struct.pack("<II", w, h))
        f.write(struct.pack("<16I", *offsets))
        f.write(struct.pack("<16I", *sizes))
        f.write(b"\0" * 1024)                    # palette slot (unused for uncompressed)
        for b in blobs:
            f.write(b)


# ---------------------------------------------------------------- M2 patching ----------------------------------------

def patch_floats_rgb(buf, ofs, count, rgb):
    """count C3Vector float colours (0..255 scale) at ofs, in place."""
    for j in range(count):
        r, g, b = struct.unpack_from("<fff", buf, ofs + j * 12)
        nr, ng, nb = rgb(max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
        struct.pack_into("<fff", buf, ofs + j * 12, float(nr), float(ng), float(nb))


def patch_nested_track_rgb(buf, track_ofs, rgb):
    """M2Track<C3Vector> (WotLK): interpolation, gseq, timestamps M2Array<M2Array>, values M2Array<M2Array<C3Vector>>."""
    n_anim, ofs_anim = struct.unpack_from("<II", buf, track_ofs + 12)
    for a in range(n_anim):
        cnt, ofs = struct.unpack_from("<II", buf, ofs_anim + a * 8)
        if cnt and ofs + cnt * 12 <= len(buf):
            patch_floats_rgb(buf, ofs, cnt, rgb)


def patch_m2_colors(buf, rgb):
    """Particle emitter colour keys, ribbon colour tracks and the model's vertex-colour tracks."""
    changed = 0
    n_par, ofs_par = struct.unpack_from("<II", buf, 296)
    for i in range(n_par):
        base = ofs_par + i * 0x1DC
        nk, ok = struct.unpack_from("<II", buf, base + 268)   # FBlock colorTrack: timestamps(8) then keys(8)
        if nk and ok + nk * 12 <= len(buf):
            patch_floats_rgb(buf, ok, nk, rgb)
            changed += 1
    n_rib, ofs_rib = struct.unpack_from("<II", buf, 288)
    for i in range(n_rib):
        patch_nested_track_rgb(buf, ofs_rib + i * 0xB0 + 36, rgb)
        changed += 1
    n_col, ofs_col = struct.unpack_from("<II", buf, 72)
    for i in range(n_col):
        patch_nested_track_rgb(buf, ofs_col + i * 40, rgb)   # M2Color: colour track (20) + alpha track (20)
        changed += 1
    return changed


def ghost_texture_name(name):
    """Same length as the original (the M2 stores fixed-length strings): first letter of the file name -> '~'."""
    d, f = name.rsplit("\\", 1) if "\\" in name else ("", name)
    return (d + "\\" if d else "") + "~" + f[1:]


def ghost_model_name(dbc_name):
    p = m2_path(dbc_name)
    d, f = p.rsplit("\\", 1) if "\\" in p else ("", p)
    return (d + "\\" if d else "") + "gh_" + f


# ---------------------------------------------------------------- build ----------------------------------------------

def build(dbc_dir, data_dir, palette):
    from PIL import Image as _I
    global Image
    Image = _I
    rgb = make_mapper(palette)
    spell, sv, kit, efn, pal_spells, visuals, kits, efns, models = walk(dbc_dir)
    client = Client(data_dir)
    print("paladin spells %d, visuals %d, kits %d, effect names %d, models %d, palette %s" %
          (len(pal_spells), len(visuals), len(kits), len(efns), len(models), palette))

    if os.path.isdir(OUT):
        import shutil
        shutil.rmtree(OUT)
    os.makedirs(os.path.join(OUT, "DBFilesClient"))

    def out_path(rel):
        return os.path.join(OUT, *rel.split("\\"))

    # 1. textures: recolour once each, under a same-length name
    done_tex = {}   # lower original name -> new name (or None when it could not be decoded)
    def ghost_tex(name):
        key = name.lower()
        if key in done_tex:
            return done_tex[key]
        data = client.read(name)
        new = None
        if data:
            recoloured = recolor_blp_inplace(data, rgb)
            if recoloured:
                new = ghost_texture_name(name)
                os.makedirs(os.path.dirname(out_path(new)), exist_ok=True)
                open(out_path(new), "wb").write(recoloured)
            else:
                print("  texture left as is (unhandled BLP layout):", name)
        done_tex[key] = new
        return new

    # 2. models: clone under gh_ names, retarget textures, recolour colour tracks, copy skins
    done_model = {}   # dbc file name -> new dbc file name
    stats = {"models": 0, "textures": 0, "skins": 0}
    for m in models:
        data = client.read(m)
        if not data:
            print("  model missing:", m)
            continue
        buf = bytearray(data)
        for tofs, ln, fofs, name in m2_textures(buf):
            new = ghost_tex(name)
            if new:
                assert len(new) == len(name)
                buf[fofs:fofs + len(name)] = new.encode("latin1")
                stats["textures"] += 1
        patch_m2_colors(buf, rgb)
        new_m2 = ghost_model_name(m)
        os.makedirs(os.path.dirname(out_path(new_m2)), exist_ok=True)
        open(out_path(new_m2), "wb").write(bytes(buf))
        for old_skin, new_skin in zip(skin_names(m2_path(m)), skin_names(new_m2)):
            sk = client.read(old_skin)
            if sk:
                open(out_path(new_skin), "wb").write(sk)
                stats["skins"] += 1
        done_model[m] = new_m2[:-3] + ".mdx"   # keep the DBC's naming convention
        stats["models"] += 1

    # 3. DBC chain: clone effect names, kits and visuals under new ids; point the paladin spells at them
    new_efn = {}
    def clone_efn(e):
        if e in new_efn:
            return new_efn[e]
        row = list(efn.by_id[e])
        name = efn.s(row[EFN_FILE])
        if name not in done_model:
            new_efn[e] = e
            return e
        row[0] = efn.next_id()
        row[EFN_NAME] = efn.add_string(efn.s(row[EFN_NAME]) + "_ghost")
        row[EFN_FILE] = efn.add_string(done_model[name])
        efn.append(row)
        new_efn[e] = row[0]
        return row[0]

    new_kit = {}
    def clone_kit(k):
        if k in new_kit:
            return new_kit[k]
        row = list(kit.by_id[k])
        touched = False
        for i in KIT_EFFECTS:
            if row[i] > 0 and row[i] in efn.by_id:
                ne = clone_efn(row[i])
                touched |= ne != row[i]
                row[i] = ne
        if not touched:
            new_kit[k] = k
            return k
        row[0] = kit.next_id()
        kit.append(row)
        new_kit[k] = row[0]
        return row[0]

    new_sv = {}
    for v in visuals:
        row = list(sv.by_id[v])
        touched = False
        for i in SV_KITS:
            if row[i] > 0 and row[i] in kit.by_id:
                nk = clone_kit(row[i])
                touched |= nk != row[i]
                row[i] = nk
        if row[SV_MISSILE_MODEL] > 0 and row[SV_MISSILE_MODEL] in efn.by_id:
            ne = clone_efn(row[SV_MISSILE_MODEL])
            touched |= ne != row[SV_MISSILE_MODEL]
            row[SV_MISSILE_MODEL] = ne
        if touched:
            row[0] = sv.next_id()
            sv.append(row)
            new_sv[v] = row[0]

    retargeted = 0
    for r in pal_spells:
        for i in SPELL_VISUAL:
            if r[i] in new_sv:
                r[i] = new_sv[r[i]]
                retargeted += 1

    for d, name in ((spell, "Spell.dbc"), (sv, "SpellVisual.dbc"), (kit, "SpellVisualKit.dbc"), (efn, "SpellVisualEffectName.dbc")):
        d.write(os.path.join(OUT, "DBFilesClient", name))

    print("models %d (skins %d), texture references retargeted %d, distinct textures recoloured %d, undecodable %d" %
          (stats["models"], stats["skins"], stats["textures"], sum(1 for v in done_tex.values() if v), sum(1 for v in done_tex.values() if not v)))
    print("effect names cloned %d, kits cloned %d, visuals cloned %d, spell visual fields retargeted %d" %
          (sum(1 for k, v in new_efn.items() if k != v), sum(1 for k, v in new_kit.items() if k != v), len(new_sv), retargeted))
    print("written to", OUT)


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    mode, dbc_dir, data_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    palette = "ghost"
    if "--palette" in sys.argv:
        palette = sys.argv[sys.argv.index("--palette") + 1]
    if mode == "build":
        build(dbc_dir, data_dir, palette)
        return
    spell, sv, kit, efn, pal_spells, visuals, kits, efns, models = walk(dbc_dir)
    print("paladin spells: %d, visuals: %d, kits: %d, effect names: %d, models: %d" %
          (len(pal_spells), len(visuals), len(kits), len(efns), len(models)))
    client = Client(data_dir)
    print("archives:", len(client.archives))
    textures, missing = {}, []
    for m in models:
        data = client.read(m)
        if not data:
            missing.append(m)
            continue
        for _, _, _, name in m2_textures(data):
            textures.setdefault(name, []).append(m)
    print("models found: %d, missing: %d, distinct textures: %d" % (len(models) - len(missing), len(missing), len(textures)))
    for m in models:
        print("  model", m)
    for t in sorted(textures):
        print("  texture", t, "used by", len(textures[t]))
    for m in missing:
        print("  MISSING", m)


if __name__ == "__main__":
    main()
