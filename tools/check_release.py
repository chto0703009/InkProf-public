# Copyright (c) 2026 Christer Törnkvist.
# SPDX-License-Identifier: GPL-3.0-or-later
# InkProf is free software under GNU GPL version 3 or later.
# Distributed WITHOUT ANY WARRANTY; see LICENSE and THIRD_PARTY_NOTICES.md.
"""Check the current source release's version, notice coverage and resources."""
import hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=root,text=True).splitlines()
version=(root/'VERSION').read_text().strip()
assert version==json.loads((root/'resources/release.json').read_text())['version']
count=0
for name in files:
 p=root/name
 if p.suffix in ('.m','.py','.js') and not name.startswith(('licenses/','schemas/')):
  text=p.read_text();assert 'SPDX-License-Identifier: GPL-3.0-or-later' in text[:1200],name
  assert 'Copyright' in text[:1200] and 'WITHOUT ANY WARRANTY' in text[:1200],name
  count+=1
 assert not name.startswith(('.venv/','local-config/','projects/','measurements/')),name
 assert p.name!='.DS_Store',name
schema=json.loads((root/'schemas/cxf3/provenance.json').read_text())
assert hashlib.sha256((root/'schemas/cxf3/CxF3_Core.xsd').read_bytes()).hexdigest()==schema['sha256']
assert (root/'schemas/cxf3'/schema['license']).is_file()
for item in json.loads((root/'licenses/inventory.json').read_text())['additionalNotices']:
 assert hashlib.sha256((root/item['savedPath']).read_bytes()).hexdigest()==item['sha256'],item['savedPath']
for name in ['LICENSE','LICENSE_SCOPE.md','THIRD_PARTY_NOTICES.md','RELEASE_SCOPE.md','CHANGELOG.md','VALIDATION.txt']:
 assert (root/name).is_file(),name
print(f'{version}: {count} source files have notices; version, schema and additional resource hashes match.')
print('Scope: current tracked source tree. This check is not a legal clearance or a physical colour-quality test.')
