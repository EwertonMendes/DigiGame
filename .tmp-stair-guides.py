from PIL import Image, ImageDraw

def make(name, axis):
    scale=4
    def project(x,y,z):
        return ((x-y)*32*scale+512,(x+y)*16*scale-z*scale+310)
    im=Image.new('RGBA',(1024,768),(0,0,0,0))
    d=ImageDraw.Draw(im)
    def polygon(points,color):
        d.polygon(points,fill=color,outline='#132531',width=3)
    def at(w,t,z):
        if axis=='ne': return project(w,3.25-t,z)
        if axis=='nw': return project(3.25-t,w,z)
        if axis=='sw': return project(w,t,z)
        return project(t,w,z)
    # Tall near back wall makes the orientation unambiguous.
    polygon([at(0,0,48),at(3,0,48),at(3,0,0),at(0,0,0)],'#304653')
    for w in [0,3]:
        contour=[at(w,0,0),at(w,0,48)]
        for i in range(6):
            t=(i+1)*3.25/6
            contour.extend([at(w,t,48-i*8),at(w,t,48-(i+1)*8)])
        polygon(contour,'#1d3440' if w==3 else '#47616c')
    for i in range(6):
        t0=i*3.25/6; t1=(i+1)*3.25/6; z=48-i*8
        polygon([at(0,t1,z),at(3,t1,z),at(3,t1,z-8),at(0,t1,z-8)],'#314a58')
        polygon([at(0,t0,z),at(3,t0,z),at(3,t1,z),at(0,t1,z)],'#abb6b8')
    im.save('.tmp-guide-'+name+'.png')

make('ne','ne')
make('nw','nw')
make('sw','sw')
make('se','se')

def bridge(axis):
    im=Image.new('RGBA',(1024,768),(0,0,0,0)); d=ImageDraw.Draw(im)
    def p(w,t,z):
        x,y=(w,t) if axis=='y' else (t,w)
        return ((x-y)*96+540,(x+y)*48-z*3+190)
    q=[p(0,0,8),p(3,0,8),p(3,4,8),p(0,4,8)]
    bottom=[p(0,0,0),p(3,0,0),p(3,4,0),p(0,4,0)]
    for a,b in [(1,2),(2,3)]: d.polygon([q[a],q[b],bottom[b],bottom[a]],fill='#304653',outline='#132531',width=3)
    d.polygon(q,fill='#abb6b8',outline='#132531',width=3)
    im.save('.tmp-guide-bridge-'+axis+'.png')

bridge('x')
bridge('y')

def edge_guide(name, a, b, height, solid):
    im=Image.new('RGBA',(1024,768),(0,0,0,0)); d=ImageDraw.Draw(im)
    def offset(p,x,y): return (p[0]+x,p[1]+y)
    def face(points,c): d.polygon(points,fill=c,outline='#132531',width=3)
    top_a=offset(a,0,-height); top_b=offset(b,0,-height)
    if solid:
        face([a,b,top_b,top_a],'#304653')
        face([top_a,top_b,offset(top_b,18,-10),offset(top_a,18,-10)],'#abb6b8')
        face([offset(top_a,0,30),offset(top_b,0,30),offset(top_b,0,40),offset(top_a,0,40)],'#34bed0')
    else:
        for p in [a,b]:
            face([offset(p,-15,0),offset(p,15,0),offset(p,15,-height),offset(p,-15,-height)],'#304653')
        for y,c in [(-height+15,'#607782'),(-height*0.35,'#34bed0')]:
            face([offset(a,0,y),offset(b,0,y),offset(b,0,y+18),offset(a,0,y+18)],c)
    im.save('.tmp-guide-'+name+'.png')

edge_guide('rail-y',(180,630),(810,315),210,False)
edge_guide('parapet-x',(160,345),(810,670),155,True)
