# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Embed exact font notices in PDFs without an additional PDF dependency."""
from pathlib import Path
from reportlab.pdfbase import pdfdoc

def attach(canvas):
    root=Path(__file__).resolve().parents[1]
    names=[]
    for file in [root/'licenses/Bitstream-Vera.txt', root/'licenses/fonts/DejaVuSans.ttf.notices.txt']:
        stream=pdfdoc.PDFStream(pdfdoc.PDFDictionary({'Type':pdfdoc.PDFName('EmbeddedFile')}),content=file.read_bytes())
        ref=canvas._doc.Reference(stream)
        spec=pdfdoc.PDFDictionary({'Type':pdfdoc.PDFName('Filespec'),'F':pdfdoc.PDFString(file.name),
            'EF':pdfdoc.PDFDictionary({'F':ref})})
        names += [pdfdoc.PDFString(file.name),canvas._doc.Reference(spec)]
    canvas._doc.Catalog.Names=pdfdoc.PDFDictionary({'EmbeddedFiles':pdfdoc.PDFDictionary({'Names':pdfdoc.PDFArray(names)})})
