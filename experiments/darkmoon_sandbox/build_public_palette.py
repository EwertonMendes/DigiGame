"""Build original fallback brush art; proprietary cells remain in the local atlas."""
from pathlib import Path
import json

ROOT = Path(__file__).parent
BRUSHES = json.loads((ROOT/'brushes.json').read_text())
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512" viewBox="0 0 1024 512">']

def path(points, color, stroke=None, width=1):
    data = 'M'+' L'.join(f'{x},{y}' for x,y in points)+' Z'
    extra = f' stroke="{stroke}" stroke-width="{width}"' if stroke else ''
    parts.append(f'<path d="{data}" fill="{color}"{extra}/>')

def rect(x,y,w,h,color):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>')

for name, brush in BRUSHES.items():
    x,y,w,h=brush['rect']
    parts.append(f'<g transform="translate({x} {y})">')
    if name in ('floor','paver'):
        rect(0,0,w,h,'#a584f7')
    elif name=='court':
        rect(0,0,w,h,'#b5e7ff')
    elif name=='terminal':
        path([(0,16),(32,32),(32,56),(0,40)],'#a237aa','#62245f')
        path([(32,32),(64,16),(64,40),(32,56)],'#782579','#552151')
        path([(0,16),(32,0),(64,16),(32,32)],'#eca9eb','#fff0fa')
        path([(7,16),(32,4),(57,16),(32,28)],'#d467d2')
        rect(27,5,10,9,'#f3efff')
        for offset in (5,12,19):
            path([(offset,26+offset//2),(offset+4,28+offset//2),(offset+4,39+offset//2),(offset,37+offset//2)],'#4d164c')
        path([(42,35),(53,29),(53,41),(42,47)],'#c95ac9','#e3b4e8')
    elif name=='light':
        path([(8,12),(16,16),(16,56),(8,52)],'#ad45af','#65216a')
        path([(16,16),(24,12),(24,52),(16,56)],'#7c2680','#65216a')
        path([(4,8),(16,2),(28,8),(16,14)],'#e690de','#f9d8ec')
        path([(11,8),(16,5),(21,8),(16,11)],'#a4efad')
        path([(8,44),(16,48),(24,44),(24,48),(16,52),(8,48)],'#c77dd0')
    elif name=='billboard':
        path([(4,34),(68,2),(68,62),(4,94)],'#273e76','#75e9f0',2)
        path([(9,37),(62,10),(62,57),(9,84)],'#448dd0','#adf3ef')
        for line in range(3):
            path([(14,47+line*9),(54,27+line*9),(54,29+line*9),(14,49+line*9)],'#b4eef0')
    elif name=='facade':
        path([(0,0),(96,48),(96,104),(0,56)],'#98248a')
        path([(96,48),(208,-8),(208,48),(96,104)],'#6b126b')
        for a,b,c,d in [(0,0,96,48),(96,48,208,-8)]:
            path([(a,b),(c,d),(c,d+4),(a,b+4)],'#e6d489')
            path([(a,b+48),(c,d+48),(c,d+56),(a,b+56)],'#8bbdcc')
        path([(22,28),(72,53),(72,86),(22,61)],'#251c3b','#e0cd82',2)
        path([(121,44),(174,17),(174,44),(121,71)],'#c783ad','#e7cf87',2)
        for index in range(6):
            path([(103+index*15,60-index*7),(110+index*15,56-index*7),
                  (110+index*15,70-index*7),(103+index*15,74-index*7)],'#77276f')
    elif name=='bench':
        path([(0,44),(88,0),(112,12),(24,56)],'#a8ccd8','#668093')
        path([(0,44),(24,56),(24,76),(0,64)],'#7ca0b5')
        path([(24,56),(112,12),(112,32),(24,76)],'#507c99')
        for cx,cy in [(20,35),(55,19),(92,8)]:
            path([(cx-6,cy),(cx,cy+3),(cx+6,cy),(cx,cy-3)],'#c9e5db')
            rect(cx-4,cy-6,8,7,'#398b77')
            path([(cx-9,cy-6),(cx,cy-11),(cx+9,cy-6),(cx,cy-1)],'#83d9b9')
    elif name=='pool':
        rect(0,0,w,h,'#417fb7')
        for index in range(12):
            rect((index*31)%w,(index*17)%h,12,1,'#81d5e7')
        for cx,cy in [(144,48),(176,48),(112,72),(208,72),(160,104)]:
            path([(cx-16,cy),(cx,cy+8),(cx,cy+34),(cx-16,cy+26)],'#993285')
            path([(cx,cy+8),(cx+16,cy),(cx+16,cy+26),(cx,cy+34)],'#602568')
            path([(cx-16,cy),(cx,cy-8),(cx+16,cy),(cx,cy+8)],'#ec89d2','#f5d4ed')
        path([(144,65),(176,65),(183,110),(136,110)],'#6cc5eb')
    elif name=='plaza':
        rect(0,0,w,h,'#a584f7')
        path([(0,48),(96,0),(192,48),(96,96)],'#8777b0')
        path([(16,48),(96,8),(176,48),(96,88)],'#e4e7f5')
        path([(64,48),(96,32),(128,48),(96,64)],'#adceeb')
    elif name=='steps':
        rect(0,0,w,h,'#a584f7')
        for index in range(4):
            path([(2,7+index*2),(28,1+index*2),(28,2+index*2),(2,8+index*2)],'#67347f')
    parts.append('</g>')
parts.append('</svg>')
(ROOT/'palette.svg').write_text('\n'.join(parts)+'\n')
print('Original fallback atlas rebuilt')
