"""Identify the renamed delivery ICC separately from the checked source ICC."""
import html
import json
import sys
from pathlib import Path
from urllib.parse import quote


def details(delivery):
    return [f"Fil: {Path(delivery['file']).name}", 'Internt profilnamn: '+delivery['internalName'],
            'Leveransfilens SHA-256: '+delivery['sha256'],
            'Kontrollerad originalprofil, SHA-256: '+delivery['sourceSHA256'],
            'Endast profilens namninformation och nödvändiga filstruktur-/identitetsfält har ändrats. Alla övriga ICC-taggar, inklusive färgberäkningarnas tabeller, är byte-identiska.']


def create(folder):
    folder = Path(folder)
    r = json.loads((folder/'final-report.json').read_text(encoding='utf-8'))
    delivery = json.loads((folder/'icc-delivery.json').read_text(encoding='utf-8'))
    if delivery['sourceSHA256'] != r['profile']['sha256']:
        raise ValueError('Delivery and report refer to different source profiles')
    r['deliveryProfile'] = delivery
    (folder/'final-report.json').write_text(json.dumps(r,indent=2,ensure_ascii=False),encoding='utf-8')
    if r['documentType'] == 'inkprof.numerical-report':
        from numerical_report import create as render
    else:
        section = '<h2>Levererad ICC-profil</h2>'+''.join('<p>'+html.escape(x)+'</p>' for x in details(delivery))
        section += "<p><a href='"+quote(delivery['file'])+"'>Hämta namngiven ICC-profil</a></p>"
        page = (folder/'final-report.html').read_text(encoding='utf-8')
        page = page.replace('<h2>Sparad ICC-profil</h2>',section+'<h2>Kontrollerad ICC-kandidat (projektoriginal)</h2>',1)
        (folder/'final-report.html').write_text(page,encoding='utf-8')
        text = (folder/'final-report.txt').read_text(encoding='utf-8')
        text = text.replace('SPARAD ICC\n','LEVERERAD ICC-PROFIL\n'+'\n'.join(details(delivery))+'\n\nKONTROLLERAD ICC-KANDIDAT (PROJEKTORIGINAL)\n',1)
        (folder/'final-report.txt').write_text(text,encoding='utf-8')
        from workflow_final_pdf import create as render
    render(folder)


if __name__ == '__main__':
    create(sys.argv[1])
