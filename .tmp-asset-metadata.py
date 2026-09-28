from PIL import Image
from pathlib import Path
import json

anchors={
    'stair_sw':[[780,131],[1290,390],[625,1055],[157,805]],
    'stair_se':[[720,130],[193,403],[772,1003],[1308,739]],
    'stair_ne':[[127,381],[651,642],[1317,738],[793,477]],
    'stair_nw':[[1338,435],[1044,584],[715,1027],[175,760]],
    'bridge_x':[[438,258],[164,396],[1005,884],[1292,741]],
    'bridge_y':[[936,253],[1307,447],[527,847],[152,662]],
    'rail_x':[[598,480],[1176,776],[1176,441],[598,145]],
    'rail_y':[[281,934],[1166,521],[1166,191],[281,604]],
    'parapet_x':[[265,504],[1150,960],[1150,700],[265,244]],
    'parapet_y':[[341,850],[1470,485],[1470,265],[341,630]],
    'post':[[431,1020],[817,1020],[817,235],[431,235]],
}
root=Path('assets/world/central_city/terrace')
assets={}
for name,points in anchors.items():
    im=Image.open(root/(name+'.png'))
    box=im.getchannel('A').point(lambda a:255 if a>240 else 0).getbbox()
    x0,y0,x1,y1=box
    x0=max(0,x0-4); y0=max(0,y0-4); x1=min(im.width,x1+4); y1=min(im.height,y1+4)
    assets[name]={
        'path':'res://assets/world/central_city/terrace/'+name+'.png',
        'image_size':list(im.size),'bounds':[x0,y0,x1-x0,y1-y0],'anchors':points,
    }
    if name.startswith('stair_'): assets[name]['cross_grid']=[0,1] if name.endswith(('se','nw')) else [1,0]
    if name.startswith('bridge_'): assets[name]['cross_grid']=[0,1] if name.endswith('x') else [1,0]
(root/'manifest.json').write_text(json.dumps({'version':1,'source':'Original DigiGame artwork generated with built-in ImageGen','assets':assets},indent=2)+'\n',encoding='utf-8')
