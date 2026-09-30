"""Verify recorded distribution notices against installed Python packages."""
import hashlib,json
from pathlib import Path
from importlib.metadata import distribution
root=Path(__file__).resolve().parents[1]
record=json.loads((root/'licenses/inventory.json').read_text())
for item in record['pythonPackages']:
 d=distribution(item['name'])
 assert d.version==item['version'],f'Update license inventory for {item["name"]} {d.version}'
 for notice in item['notices']:
  source=d.locate_file(notice['packagePath']).read_bytes();saved=(root/notice['savedPath']).read_bytes()
  assert source==saved and hashlib.sha256(saved).hexdigest()==notice['sha256'],f'Notice mismatch: {item["name"]}'
for notice in record['additionalNotices']:
 assert hashlib.sha256((root/notice['savedPath']).read_bytes()).hexdigest()==notice['sha256']
print('Recorded versions and notice hashes verified. This is not a legal clearance or exhaustive dependency audit.')
