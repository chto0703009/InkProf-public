# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
"""ICC v2 -> v4.4 for InkProf RGB output profiles built by ArgyllCMS colprof.

colprof writes ICC v2 only. This converts its RGB printer profile
(class prtr, colour space RGB, PCS Lab, lut16 tables, D50) to ICC.1:2022-05
version 4.4.0.0. The input file is never modified.

What changes
  * Header: version 4.4.0.0, exact D50 illuminant, reserved bytes zeroed,
    Profile ID = MD5 with flags, rendering intent and ID zeroed (7.2.18).
  * desc, cprt, dmnd, dmdd: text types -> multiLocalizedUnicodeType (mluc).
    targ stays textType, which v4 allows for charTargetTag.
  * bkpt is removed (obsolete; v4 CMMs take the black point from the intent).
  * Perceptual and saturation tables (A2B0/B2A0, A2B2/B2A2) are remapped to
    the v4 perceptual reference medium black, L* 3.1373 (6.3.4.3). The black
    each v2 table assumes is measured, because colprof's pairs differ:
    A2B0 is a copy of A2B1 (paper black, about L* 4 on glossy RGB inkjet),
    while B2A0 assumes L* 0-1 with gamut mapping (-s) or the printer black
    without it. LittleCMS treats both intents of a v4 profile this way.
  * Relative/absolute colorimetric tables (A2B1/B2A1), gamt, wtpt, targ and
    Argyll's arts tag are copied byte for byte. lut16 keeps its legacy Lab
    encoding in v4, so nothing is lost there.

No chad tag is needed: InkProf profiles are always measured for D50.

Usage
  python3 icc_v2_to_v4.py in.icc out.icc [--b2a-grid fine|same]
                          [--report report.json] [--check]

Requires numpy.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import struct
import sys
from dataclasses import dataclass, field

import numpy as np

__version__ = "1.1.0"

D50 = np.array([0.9642, 1.0, 0.8249])
D50_HEADER = struct.pack(">3I", 0x0000F6D6, 0x00010000, 0x0000D32D)
PRMG_BLACK = np.array([0.003357, 0.003479, 0.002869])     # L* 3.1373
PRMG_BLACK_L = 3.1373
TEXT_TAGS = (b"desc", b"cprt", b"dmnd", b"dmdd")
PERCEPTUAL_LIKE = ((b"A2B0", b"B2A0"), (b"A2B2", b"B2A2"))


class ConversionError(Exception):
    pass


# --------------------------------------------------------------------------
# Colour maths (CIE Lab, D50) and the legacy lut16 Lab encoding
# --------------------------------------------------------------------------
def xyz_to_lab(xyz):
    t = np.asarray(xyz, float) / D50
    d = 6 / 29
    f = np.where(t > d ** 3, np.cbrt(np.maximum(t, 0)), t / (3 * d * d) + 4 / 29)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]),
                     200 * (f[..., 1] - f[..., 2])], -1)


def lab_to_xyz(lab):
    lab = np.asarray(lab, float)
    fy = (lab[..., 0] + 16) / 116
    f = np.stack([fy + lab[..., 1] / 500, fy, fy - lab[..., 2] / 200], -1)
    d = 6 / 29
    return np.where(f > d, f ** 3, 3 * d * d * (f - 4 / 29)) * D50


def decode_lab(u):
    """lut16 legacy Lab (L* 100 = 0xFF00), u on 0..1 of the u16 range."""
    v = np.asarray(u, float) * 65535
    return np.stack([v[..., 0] / 652.80, v[..., 1] / 256 - 128,
                     v[..., 2] / 256 - 128], -1)


def encode_lab(lab):
    lab = np.asarray(lab, float)
    v = np.stack([np.clip(lab[..., 0], 0, 100) * 652.80,
                  (lab[..., 1] + 128) * 256, (lab[..., 2] + 128) * 256], -1)
    return np.clip(v, 0, 65535) / 65535


def pcs_to_xyz(u):
    return lab_to_xyz(decode_lab(u))


def xyz_to_pcs(xyz):
    return encode_lab(xyz_to_lab(np.maximum(xyz, 0)))


def to_v4(xyz, black):
    """Linear map, white fixed, `black` -> v4 reference black (6.3.4.3)."""
    return (xyz - black) * (D50 - PRMG_BLACK) / (D50 - black) + PRMG_BLACK


def from_v4(xyz, black):
    return (xyz - PRMG_BLACK) * (D50 - black) / (D50 - PRMG_BLACK) + black


def neutral(Y):
    """Neutral black point with luminance Y (as black point compensation)."""
    return D50 * max(float(Y), 0.0)


def L_of(xyz):
    return float(xyz_to_lab(np.asarray(xyz, float))[0])


# --------------------------------------------------------------------------
# lut16 ('mft2')
# --------------------------------------------------------------------------
def s15(v):
    return int(round(float(v) * 65536))


@dataclass
class Lut16:
    n_in: int
    n_out: int
    grid: int
    matrix: bytes                  # 36 raw bytes, kept as written
    in_tab: np.ndarray             # (n_in, n) on 0..1
    clut: np.ndarray               # (grid**n_in, n_out) on 0..1
    out_tab: np.ndarray            # (n_out, n) on 0..1

    @classmethod
    def parse(cls, data: bytes) -> "Lut16":
        if len(data)<52:
            raise ConversionError('truncated lut16 header')
        if data[:4] != b"mft2":
            raise ConversionError(f"expected lut16 (mft2), found {data[:4]!r}")
        n_in, n_out, grid = data[8], data[9], data[10]
        ni, no = struct.unpack(">HH", data[48:52])
        if n_in!=3 or n_out!=3 or grid<2 or ni<2 or no<2:
            raise ConversionError('expected three-channel lut16 with usable grids and curves')
        identity=struct.pack('>9i',65536,0,0,0,65536,0,0,0,65536)
        if data[12:48]!=identity:
            raise ConversionError('nonidentity lut16 matrix is unsupported')
        nc = grid ** n_in * n_out
        if len(data)!=52+2*(n_in*ni+nc+n_out*no):
            raise ConversionError('lut16 payload size mismatch')
        a = np.frombuffer(data, ">u2", n_in * ni + nc + n_out * no, 52)
        a = a.astype(float) / 65535
        i = n_in * ni
        return cls(n_in, n_out, grid, data[12:48], a[:i].reshape(n_in, ni),
                   a[i:i + nc].reshape(-1, n_out), a[i + nc:].reshape(n_out, no))

    def to_bytes(self) -> bytes:
        def u16(x):
            return np.round(np.clip(x, 0, 1) * 65535).astype(">u2").tobytes()
        return (b"mft2" + b"\0" * 4 + bytes([self.n_in, self.n_out, self.grid, 0])
                + self.matrix + struct.pack(">HH", self.in_tab.shape[1],
                                            self.out_tab.shape[1])
                + u16(self.in_tab) + u16(self.clut) + u16(self.out_tab))

    def copy(self) -> "Lut16":
        return Lut16(self.n_in, self.n_out, self.grid, self.matrix,
                     self.in_tab.copy(), self.clut.copy(), self.out_tab.copy())

    @staticmethod
    def curve(tab, x):
        return np.interp(np.clip(x, 0, 1), np.linspace(0, 1, tab.shape[-1]), tab)

    @staticmethod
    def inverse_curve(tab, y):
        xs = np.linspace(0, 1, tab.shape[-1])
        t = np.asarray(tab, float)
        if t[-1] < t[0]:
            t, xs = t[::-1], xs[::-1]
        t = np.maximum.accumulate(t)
        if t[-1] - t[0] < 1e-12:
            return np.clip(y, 0, 1)
        t = t + np.linspace(0, 1e-9, t.size)
        return np.interp(np.clip(y, t[0], t[-1]), t, xs)

    def clut_eval(self, g):
        """Tetrahedral (simplex) interpolation; g: (N, n_in) on 0..1."""
        g = np.clip(np.asarray(g, float), 0, 1)
        n, G = self.n_in, self.grid
        p = g * (G - 1)
        i0 = np.minimum(np.floor(p).astype(np.int64), G - 2)
        f = p - i0
        strides = G ** np.arange(n - 1, -1, -1)
        idx = i0 @ strides
        order = np.argsort(-f, axis=1)
        fs = np.take_along_axis(f, order, 1)
        out = (1 - fs[:, :1]) * self.clut[idx]
        for k in range(n):
            idx = idx + strides[order[:, k]]
            w = fs[:, k] - (fs[:, k + 1] if k + 1 < n else 0.0)
            out += w[:, None] * self.clut[idx]
        return out

    def eval(self, x):
        x = np.atleast_2d(np.asarray(x, float))
        g = np.stack([self.curve(self.in_tab[c], x[:, c])
                      for c in range(self.n_in)], 1)
        o = self.clut_eval(g)
        return np.stack([self.curve(self.out_tab[c], o[:, c])
                         for c in range(self.n_out)], 1)

    def grid_nodes(self):
        ax = np.linspace(0, 1, self.grid)
        mesh = np.meshgrid(*[ax] * self.n_in, indexing="ij")
        return np.stack([m.ravel() for m in mesh], 1)


# --------------------------------------------------------------------------
# Profile container
# --------------------------------------------------------------------------
@dataclass
class Profile:
    header: bytearray
    tags: list = field(default_factory=list)      # [(sig, bytes)] in order

    @classmethod
    def parse(cls, data: bytes) -> "Profile":
        if len(data) < 132 or data[36:40] != b"acsp":
            raise ConversionError("not an ICC profile")
        if struct.unpack(">I", data[:4])[0] != len(data):
            raise ConversionError("ICC size field does not match the file")
        n = struct.unpack(">I", data[128:132])[0]
        if 132+12*n>len(data):
            raise ConversionError('truncated ICC tag directory')
        tags = []
        seen=set()
        for i in range(n):
            sig, off, size = struct.unpack(">4sII", data[132 + 12 * i:144 + 12 * i])
            if sig in seen or off<132+12*n or off%4 or size<8:
                raise ConversionError('invalid or duplicate ICC tag directory entry')
            seen.add(sig)
            if off + size > len(data):
                raise ConversionError(f"tag {sig!r} runs past the end of the file")
            tags.append((sig, bytes(data[off:off + size])))
        return cls(bytearray(data[:128]), tags)

    def get(self, sig):
        return next((d for s, d in self.tags if s == sig), None)

    def set(self, sig, data):
        for i, (s, _) in enumerate(self.tags):
            if s == sig:
                self.tags[i] = (sig, data)
                return
        self.tags.append((sig, data))

    def remove(self, sig):
        self.tags = [(s, d) for s, d in self.tags if s != sig]

    def assemble(self) -> bytes:
        offset = 128 + 4 + 12 * len(self.tags)
        placed, blocks, table = {}, [], b""
        for sig, data in self.tags:
            if data not in placed:           # identical data shares one block
                placed[data] = offset
                pad = (-len(data)) % 4
                blocks.append(data + b"\0" * pad)
                offset += len(data) + pad
            table += sig + struct.pack(">II", placed[data], len(data))
        out = bytearray(bytes(self.header) + struct.pack(">I", len(self.tags))
                        + table + b"".join(blocks))
        out[0:4] = struct.pack(">I", len(out))
        return bytes(out)


def profile_id(icc: bytes) -> bytes:
    z = bytearray(icc)
    z[44:48] = z[64:68] = b"\0" * 4
    z[84:100] = b"\0" * 16
    return hashlib.md5(bytes(z)).digest()


def text_of(data: bytes) -> str:
    kind = data[:4]
    if kind == b"text":
        raw = data[8:].split(b"\0", 1)[0]
    elif kind == b"desc":
        n = struct.unpack(">I", data[8:12])[0]
        raw = data[12:12 + n].split(b"\0", 1)[0]
        p = 12 + n
        if len(data) >= p + 8:
            count = struct.unpack(">I", data[p + 4:p + 8])[0]
            uni = data[p + 8:p + 8 + 2 * count].decode("utf-16-be", "replace")
            uni = uni.split("\0", 1)[0]
            if uni:
                return uni
    else:
        raise ConversionError(f"unexpected text type {kind!r}")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin-1")


def mluc(text: str) -> bytes:
    s = text.encode("utf-16-be")
    return (b"mluc" + b"\0" * 4 + struct.pack(">II", 1, 12) + b"enUS"
            + struct.pack(">II", len(s), 28) + s)


def read_xyz(data: bytes):
    return np.array(struct.unpack(">3i", data[8:20])) / 65536.0


# --------------------------------------------------------------------------
# Black points of the v2 tables
# --------------------------------------------------------------------------
def printer_black(_b2a1: Lut16 | None = None):
    """The printer's black is RGB 0,0,0 - the darkest colorant combination,
    which is also how LittleCMS defines the black point of an RGB profile.
    (colprof's B2A1 at L* 0 can land on a slightly lighter RGB.)"""
    return np.zeros((1, 3))


def a2b_black(a2b: Lut16, rgb_black):
    """PCS black an A2B table gives for the printer's darkest RGB."""
    return neutral(pcs_to_xyz(a2b.eval(rgb_black))[0, 1])


def b2a_black(b2a: Lut16, a2b1: Lut16, tol=0.25):
    """PCS black a B2A table assumes: the highest L* on the neutral axis that
    still prints as the darkest tone the table reaches."""
    L = np.linspace(0, 30, 301)
    lab = np.stack([L, 0 * L, 0 * L], 1)
    printed = decode_lab(a2b1.eval(b2a.eval(encode_lab(lab))))[:, 0]
    flat = printed <= printed[0] + tol
    last = int(np.argmin(flat)) - 1 if not flat.all() else len(L) - 1
    return neutral(lab_to_xyz([L[max(last, 0)], 0, 0])[1])


# --------------------------------------------------------------------------
# Remapping the tables
# --------------------------------------------------------------------------
def remap_a2b(lut: Lut16, black) -> Lut16:
    pcs = np.stack([Lut16.curve(lut.out_tab[c], lut.clut[:, c])
                    for c in range(3)], 1)
    new = xyz_to_pcs(to_v4(pcs_to_xyz(pcs), black))
    out = lut.copy()
    out.clut = np.stack([Lut16.inverse_curve(lut.out_tab[c], new[:, c])
                         for c in range(3)], 1)
    return out


def remap_b2a(lut: Lut16, black, fine=True) -> Lut16:
    """new(v4 PCS) == old(equivalent v2 PCS).

    The remap squeezes the deepest shadows, where colprof's gamut mapping is
    steep. With fine=True the grid is refined to 2(g-1)+1 nodes (33 -> 65),
    which keeps every original node and reduced sampled error to about 1.2 dE
    maximum in the prototype tests; this is not a universal error bound;
    fine=False keeps the original grid and file size (rare outliers of a few
    dE for out-of-gamut colours darker than the printer's black)."""
    out = lut.copy()
    if fine and lut.grid <= 128:
        out.grid = 2 * (lut.grid - 1) + 1
    nodes = out.grid_nodes()
    x = np.stack([Lut16.inverse_curve(out.in_tab[c], nodes[:, c])
                  for c in range(3)], 1)
    rgb = lut.eval(xyz_to_pcs(from_v4(pcs_to_xyz(x), black)))
    out.clut = np.stack([Lut16.inverse_curve(out.out_tab[c], rgb[:, c])
                         for c in range(3)], 1)
    return out


# --------------------------------------------------------------------------
# Conversion
# --------------------------------------------------------------------------
def convert(data: bytes, timestamp: _dt.datetime | None = None,
            fine_b2a: bool = True):
    """Return (v4 bytes, report dict)."""
    p = Profile.parse(data)
    h = p.header
    rep = {"converter": f"icc_v2_to_v4.py {__version__}",
           "inputSHA256": hashlib.sha256(data).hexdigest(),
           "inputVersion": f"{h[8]}.{h[9] >> 4}.{h[9] & 15}",
           "b2aGrid": "fine" if fine_b2a else "same", "steps": []}
    if h[8] != 2:
        raise ConversionError(f"input is ICC v{h[8]}, expected v2")
    if bytes(h[12:24]) != b"prtrRGB Lab ":
        raise ConversionError("InkProf converts RGB output profiles only "
                              "(class prtr, RGB, Lab PCS); got "
                              + bytes(h[12:24]).decode("latin-1"))
    for sig in (b"A2B0", b"A2B1", b"B2A0", b"B2A1", b"wtpt", b"desc", b"cprt"):
        if p.get(sig) is None:
            raise ConversionError(f"required tag {sig.decode()} is missing")
    if bytes(h[68:80])!=D50_HEADER:
        raise ConversionError('expected D50 PCS illuminant')
    src = {s: d for s, d in p.tags}                    # original bytes

    for sig in TEXT_TAGS:
        d = p.get(sig)
        if d is not None and d[:4] in (b"desc", b"text"):
            p.set(sig, mluc(text_of(d)))
            rep["steps"].append(f"{sig.decode()}: {d[:4].decode()} -> mluc")
    if p.get(b"bkpt") is not None:
        p.remove(b"bkpt")
        rep["steps"].append("bkpt: removed (obsolete in v4)")

    a2b1, b2a1 = Lut16.parse(src[b"A2B1"]), Lut16.parse(src[b"B2A1"])
    rgb_black = printer_black()
    rep["printerBlackRGB"] = [round(float(v), 4) for v in rgb_black[0]]
    rep["printerBlackLstar"] = round(float(decode_lab(a2b1.eval(rgb_black))[0, 0]), 3)
    blacks, done = {}, {}
    for a2b_sig, b2a_sig in PERCEPTUAL_LIKE:
        for sig, kind in ((a2b_sig, "A2B"), (b2a_sig, "B2A")):
            raw = src.get(sig)
            if raw is None:
                continue
            if raw in done:                # colprof shares tables: keep sharing
                p.set(sig, done[raw])
                rep["steps"].append(f"{sig.decode()}: same data as "
                                    f"{blacks[raw][0]}, remapped with it")
                continue
            lut = Lut16.parse(raw)
            if kind == "A2B":
                black = a2b_black(lut, rgb_black)
                new = remap_a2b(lut, black).to_bytes()
            else:
                black = b2a_black(lut, a2b1)
                new = remap_b2a(lut, black, fine_b2a).to_bytes()
            done[raw] = new
            blacks[raw] = (sig.decode(), L_of(black))
            p.set(sig, new)
            rep["steps"].append(f"{sig.decode()}: black L* {L_of(black):.2f} -> "
                                f"{PRMG_BLACK_L:.2f} (v4 reference medium)")
            rep.setdefault("v2BlackLstar", {})[sig.decode()] = round(L_of(black), 3)

    h[8:12] = bytes([4, 0x40, 0, 0])
    ts = timestamp or _dt.datetime.now(_dt.timezone.utc)
    h[24:36] = struct.pack(">6H", ts.year, ts.month, ts.day,
                           ts.hour, ts.minute, ts.second)
    h[68:80] = D50_HEADER
    h[84:128] = b"\0" * 44
    icc = bytearray(p.assemble())
    icc[84:100] = profile_id(bytes(icc))
    icc = bytes(icc)
    unchanged = [s.decode() for s in (b"A2B1", b"B2A1", b"gamt", b"wtpt", b"targ", b"arts")
                 if s in src and Profile.parse(icc).get(s) == src[s]]
    rep.update(outputVersion="4.4.0.0", outputSHA256=hashlib.sha256(icc).hexdigest(),
               profileID=icc[84:100].hex(), unchangedTags=unchanged,
               problems=check_v4(icc))
    return icc, rep


def check_v4(icc: bytes) -> list[str]:
    """Structural checks against ICC.1:2022 for an RGB output profile."""
    prob = []
    if struct.unpack(">I", icc[:4])[0] != len(icc) or len(icc) % 4:
        prob.append("size field or 4-byte padding wrong")
    if icc[8] != 4:
        prob.append("major version is not 4")
    if icc[68:80] != D50_HEADER:
        prob.append("header illuminant is not D50")
    if any(icc[100:128]):
        prob.append("reserved header bytes not zero")
    if icc[84:100] != profile_id(icc):
        prob.append("profile ID does not match MD5")
    n = struct.unpack(">I", icc[128:132])[0]
    sigs = set()
    for i in range(n):
        sig, off, size = struct.unpack(">4sII", icc[132 + 12 * i:144 + 12 * i])
        sigs.add(sig)
        if off % 4 or off + size > len(icc):
            prob.append(f"tag {sig.decode()} misaligned or out of range")
    need = {b"desc", b"cprt", b"wtpt", b"A2B0", b"A2B1", b"A2B2",
            b"B2A0", b"B2A1", b"B2A2", b"gamt"}
    prob += [f"required tag {s.decode()} missing" for s in sorted(need - sigs)]
    p = Profile.parse(icc)
    prob += [f"{s.decode()} is not mluc" for s in (b"desc", b"cprt")
             if p.get(s) is not None and p.get(s)[:4] != b"mluc"]
    if b"bkpt" in sigs:
        prob.append("bkpt present (obsolete in v4)")
    return prob


def main(argv=None):
    ap = argparse.ArgumentParser(description="ICC v2 -> v4.4 for InkProf RGB "
                                             "output profiles (colprof).")
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--b2a-grid", choices=["fine", "same"], default="fine",
                    help="fine (default): refine the perceptual B2A grid "
                         "33 -> 65, about +1.4 MB; same: keep file size")
    ap.add_argument("--report", help="write a JSON report here")
    ap.add_argument("--check", action="store_true", help="print the report")
    a = ap.parse_args(argv)
    from pathlib import Path
    paths=[Path(a.input).resolve(),Path(a.output).resolve()]
    if a.report:paths.append(Path(a.report).resolve())
    if len(set(paths))!=len(paths):
        print('error: input, output and report must be different files',file=sys.stderr)
        return 2
    try:
        with open(a.input, "rb") as f:
            icc, rep = convert(f.read(), fine_b2a=a.b2a_grid == "fine")
    except (ConversionError, OSError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    if rep["problems"]:
        print("error: " + "; ".join(rep["problems"]), file=sys.stderr)
        return 1
    with open(a.output, "wb") as f:
        f.write(icc)
    if a.report:
        with open(a.report, "w", encoding="utf-8") as f:
            json.dump(rep, f, indent=2, ensure_ascii=False)
    if a.check:
        print("\n".join(rep["steps"]))
        print(f"printer black L* {rep['printerBlackLstar']}; unchanged: "
              f"{', '.join(rep['unchangedTags'])}; profile ID {rep['profileID']}")
        print("v4 checks: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
