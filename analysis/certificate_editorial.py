# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Presentation-only editorial corrections; saved evidence remains unchanged."""
REPLACEMENTS = {
 'InkProf Quality Profiling RGB printer':'InkProf – Quality profiling for RGB printers',
 'InkProf - Measurement certificate':'InkProf – Measurement certificate',
 'Delta E00':'ΔE00','dE00':'ΔE00','5 Delta E':'5 ΔE','+/-':'±',
 'grays':'greys','Regularization':'Regularisation','regularization method':'regularisation method',
 'Fogra MediaWedge':'Fogra Media Wedge','InkProf custom RGB':'InkProf’s own RGB',
 'Final assessment':'User’s assessment',
 'Profile is in the limit of printer, ink and paper limitations.':'The profile reaches the limits of the printer, ink and paper.',
 'It is not accredited certification or proof of ISO conformity; unmet requirements remain unmet.':'It is not an accredited certification or proof of ISO conformity. Requirements that are not met are reported as not met.',
 'is not independent validation.':'is not an independent verification.',
 'Printer, ink and paper limit reproducible colours.':'The printer, ink and paper limit which colours can be reproduced.',
 'avgdev is assumed measurement/device noise in percent (preprocessing colprof -r).':'avgdev: assumed measurement and device noise, in percent (passed to colprof -r during preprocessing).',
 'Model change is not print accuracy or proof that visible banding is absent.':'Model change is neither a measure of print accuracy nor proof that no visible banding occurs.',
 'Photographic gradient diagnostic: no readable saved report matching this ICC. Gradient smoothness has not been certified.':'Photographic gradient diagnostic: no saved report matches this ICC, so gradient smoothness is not certified.',
 'A weak fluorescence signal may remain uncertain.':'A weak fluorescence signal may not be determined reliably.',
 'The diagnostic colour cards below show only errors above 5; they do not show the distribution of the whole result.':'The colour summary shows up to 100 largest deviations above 1, smallest first. The supplement includes every colour and separately flags deviations above 5.',
 'Swatches show desired, predicted and measured D50 Lab converted to sRGB':'Summary pairs show desired and measured D50 Lab converted to sRGB; supplement tables also show profile predictions. Colours are converted to sRGB',
 'Driver media selection':'Media type in driver',
 'High Quality (600x600 dpi, 12-bit)':'High quality (600 × 600 dpi, 12-bit)',
 'FWA/OBA - settings and results':'FWA/OBA – settings and results',
 'Appendix B - Legal terms':'Appendix B – Responsibilities and licences',
 'Bilaga A - Referenser':'Bilaga A – Referenser',
}


def english(text):
    for before,after in REPLACEMENTS.items():text=text.replace(before,after)
    if text.startswith('Delta E00 > 5.000') or text.startswith('ΔE00 > 5.000'):
        text='The supplement flags patches with ΔE00 > 5.000 between measured and desired D50 Lab for review. The reference is the maximum limit for all Fogra Media Wedge patches under ISO 12647-7:2016; this does not imply ISO approval of the InkProf target. The certificate summary instead shows up to 100 deviations above 1. Repeats and paper-white references are excluded from this summary.'
    return text


def swedish_evidence(report):
    def n(value):return f'{value:.2f}'.replace('.',',')
    paragraphs=[]
    for entry in report.get('patchOutliers',{}).get('distribution',[]):
        paragraphs.append(f'ΔE00 {entry["range"].replace("Above ","> ")}: {entry["count"]} färger ({n(entry["percent"])} %).')
    paragraphs.append('Målet är avsiktligt krävande och är inte ett representativt urval av vanliga fotografier.')
    regular=report.get('regularization',{})
    if regular:
        params=regular.get('parameters',{})
        if params:paragraphs.append('Regularisering: '+str(params.get('method','Ej angivet'))+'. Antagen mät- och enhetsvariation (avgdev): '+n(params.get('avgdev',0))+' %.')
        v=regular.get('result',{}).get('summary',{})
        if v:paragraphs.append(f'Modelländring jämfört med råmätningar: medel {n(v["mean"])}, median {n(v["median"])}, P95 {n(v["p95"])}, max {n(v["max"])} ΔE00.')
        paragraphs.append('Råmätningarna bevaras. Modelländring är varken ett mått på utskriftsnoggrannhet eller bevis för att synlig bandning saknas.')
        paragraphs.append('En sparad gradientrapport hör till denna ICC-profil; fullständiga numeriska resultat finns i supplementet. De utgör inte perceptuell certifiering.' if regular.get('photographicGradients') else 'Ingen sparad gradientrapport hör till denna ICC-profil; gradientjämnheten är därför inte certifierad.')
    fwa=report.get('fwa',{})
    if fwa:
        paragraphs.append('FWA/OBA-kompensation i profilen: '+('Ja' if fwa.get('applied') else 'Nej')+'.')
        for key,label in [('trainingResult','Profilanpassning (ingen oberoende verifiering)'),('verificationResult','Verifieringsutskrift')]:
            v=fwa.get(key,{})
            if v:paragraphs.append(f'{label}: medel {n(v["mean"])}, P95 {n(v["p95"])}, max {n(v["max"])} ΔE00 ({v["count"]} färgprov).')
        paragraphs.append('FWA-effekten jämfört med en likvärdig profil utan kompensation har inte bedömts genom en kontrollerad jämförelse. Resultaten visar därför inte i sig om kompensationen förbättrade återgivningen.')
    return paragraphs
