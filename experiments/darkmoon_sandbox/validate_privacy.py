"""Validate the native city graphics deliberately included in the game."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
folder=root/'assets/scenery/darkmoon_city'
manifest=json.loads((folder/'manifest.json').read_text())
assert set(manifest['files'])=={'tiles_8x8.png','pieces.png'}
for name,digest in manifest['files'].items():
 assert hashlib.sha256((folder/name).read_bytes()).hexdigest()==digest, f'City asset integrity failed: {name}'
assert manifest['files']['tiles_8x8.png']=='a9abb47ff5433abdcdc82632b6e6e748bb4389f1919e2e452e3f92e493a1226a'
assert manifest['valid_cells']==3825 and manifest['tile_size']==[8,8]
print('Bundled native city assets verified: source atlas and assembled modules')
