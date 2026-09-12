from pathlib import Path
from PIL import Image, ImageDraw
import json, math
import numpy as np
from scipy import ndimage
from functools import lru_cache

root = Path('Halo/Halo Icons/Pets/halo-pets-v2')
out = Path('/tmp/pet-atlas-analysis')
out.mkdir(parents=True, exist_ok=True)
manifest = json.loads((root/'manifest.json').read_text())
cell_w = manifest['cellSize']['width']
cell_h = manifest['cellSize']['height']
cols = manifest['columns']
report=[]

def bbox_gap(a,b):
    dx=max(a[0]-b[2],b[0]-a[2],0)
    dy=max(a[1]-b[3],b[1]-a[3],0)
    return math.hypot(dx,dy)

def component_assignments(im, rows):
    arr=np.array(im)
    labels,count=ndimage.label(arr[:,:,3]>=8)
    objects=ndimage.find_objects(labels)
    comps=[]
    for lab, sl in enumerate(objects, start=1):
        if sl is None: continue
        yy,xx=sl
        sub=(labels[yy,xx]==lab)
        area=int(sub.sum())
        if area < 8: continue
        ys,xs=np.nonzero(sub); gx=xs+xx.start; gy=ys+yy.start
        comps.append({
            'lab':lab,'area':area,'cx':float(gx.mean()),'cy':float(gy.mean()),
            'bbox':(int(gx.min()),int(gy.min()),int(gx.max()+1),int(gy.max()+1))
        })

    assignments={(r,c):[] for r in range(rows) for c in range(cols)}
    assigned_main=set()

    # Each atlas column contains one primary animal pose per animation row. Match large connected
    # components to those row slots monotonically. This keeps a sprite with the row it was authored
    # for even when its body crosses a 200px boundary and its centroid drifts toward the next row.
    for c in range(cols):
        center_x=(c+.5)*cell_w
        candidates=[x for x in comps if x['area']>=350 and abs(x['cx']-center_x)<cell_w*.72]
        candidates.sort(key=lambda x:x['cy'])
        n=len(candidates)
        @lru_cache(None)
        def dp(r,j):
            if r>=rows: return 38.0*(n-j), ()
            if j>=n: return 92.0*(rows-r), (('skiprow',r),)* (rows-r)
            row_y=(r+.5)*cell_h
            comp=candidates[j]
            vertical=abs(comp['cy']-row_y)
            horizontal=abs(comp['cx']-center_x)
            area_bonus=min(comp['area'],14000)/500.0
            match_cost=vertical*.72+horizontal*.12-area_bonus
            cm,pm=dp(r+1,j+1); match=(match_cost+cm,(('match',r,j),)+pm)
            cr,pr=dp(r+1,j); skiprow=(92.0+cr,(('skiprow',r),)+pr)
            cc,pc=dp(r,j+1); skipcomp=(38.0+cc,(('skipcomp',j),)+pc)
            return min(match,skiprow,skipcomp,key=lambda z:z[0])
        _,path=dp(0,0)
        for step in path:
            if step[0]=='match':
                _,r,j=step; comp=candidates[j]
                # Reject absurd matches; an empty authored frame is better than stealing a neighbour.
                if abs(comp['cy']-(r+.5)*cell_h) <= cell_h*.78:
                    assignments[(r,c)].append((comp['lab'],comp['area'],comp['bbox']))
                    assigned_main.add(comp['lab'])

    # Attach detached props (ball, bowl, mug, laptop pieces) to the nearest primary pose. Because
    # neighbour bleed is connected to its original animal, it is already part of that main component.
    mains=[]
    for (r,c),items in assignments.items():
        for lab,area,bbox in items:
            comp=next(x for x in comps if x['lab']==lab)
            mains.append((r,c,comp))
    for comp in comps:
        if comp['lab'] in assigned_main or comp['area']<20: continue
        nearest=None
        for r,c,main in mains:
            if abs(comp['cx']-main['cx'])>cell_w*.75: continue
            gap=bbox_gap(comp['bbox'],main['bbox'])
            dist=math.hypot(comp['cx']-main['cx'],comp['cy']-main['cy'])
            score=gap+dist*.12
            if gap<=52 or dist<=115:
                if nearest is None or score<nearest[0]: nearest=(score,r,c)
        if nearest:
            _,r,c=nearest
            assignments[(r,c)].append((comp['lab'],comp['area'],comp['bbox']))

    return arr,labels,assignments,comps

def assigned_bbox(items):
    items=[x for x in items if x[1]>=20]
    if not items: return None
    return (min(x[2][0] for x in items),min(x[2][1] for x in items),
            max(x[2][2] for x in items),max(x[2][3] for x in items))

def clean_sheet(im, rows, assignments, labels, arr):
    output=Image.new('RGBA',(cols*cell_w,rows*cell_h),(0,0,0,0))
    previews=Image.new('RGBA',(cols*cell_w,rows*cell_h),(42,42,42,255))
    pd=ImageDraw.Draw(previews)
    for r in range(rows):
        frame_items=[]; relative_boxes=[]
        for c in range(cols):
            items=[x for x in assignments[(r,c)] if x[1]>=20]
            bbox=assigned_bbox(items); frame_items.append((items,bbox))
            if bbox:
                relative_boxes.append((bbox[0]-c*cell_w,bbox[1]-r*cell_h,
                                       bbox[2]-c*cell_w,bbox[3]-r*cell_h))
        if not relative_boxes: continue
        ux0=min(b[0] for b in relative_boxes); uy0=min(b[1] for b in relative_boxes)
        ux1=max(b[2] for b in relative_boxes); uy1=max(b[3] for b in relative_boxes)
        union_w=max(1,ux1-ux0); union_h=max(1,uy1-uy0)
        pad=8; scale=min(1.0,(cell_w-2*pad)/union_w,(cell_h-2*pad)/union_h)
        target_w=max(1,int(round(union_w*scale))); target_h=max(1,int(round(union_h*scale)))
        base_x=(cell_w-target_w)//2; base_y=(cell_h-target_h)//2
        report.append(f'    clean row {r}: union=({ux0},{uy0},{ux1},{uy1}) size={union_w}x{union_h} scale={scale:.3f}')
        for c,(items,bbox) in enumerate(frame_items):
            if not items: continue
            canvas=np.zeros((union_h,union_w,4),dtype=np.uint8)
            for lab,area,(x0,y0,x1,y1) in items:
                component=(labels[y0:y1,x0:x1]==lab)
                if not component.any(): continue
                src=arr[y0:y1,x0:x1]
                dx=x0-c*cell_w-ux0; dy=y0-r*cell_h-uy0
                h,w=component.shape; dst=canvas[dy:dy+h,dx:dx+w]
                dst[component]=src[component]
            frame=Image.fromarray(canvas,'RGBA')
            if scale<0.999: frame=frame.resize((target_w,target_h),Image.Resampling.LANCZOS)
            cell=Image.new('RGBA',(cell_w,cell_h),(0,0,0,0)); cell.alpha_composite(frame,(base_x,base_y))
            output.alpha_composite(cell,(c*cell_w,r*cell_h))
            bg=Image.new('RGBA',(cell_w,cell_h),(62,62,62,255)); bg.alpha_composite(cell)
            previews.alpha_composite(bg,(c*cell_w,r*cell_h))
            pd.rectangle((c*cell_w,r*cell_h,(c+1)*cell_w-1,(r+1)*cell_h-1),outline=(255,70,70,255),width=2)
            pd.text((c*cell_w+5,r*cell_h+5),f'{r}:{c}',fill=(255,255,0,255))
    return output,previews

for species in ['cat','dog','fox']:
    for atlas_name, defs in manifest['atlases'].items():
        p=root/species/f'{atlas_name}.png'; im=Image.open(p).convert('RGBA'); rows=len(defs)
        report.append(f'[{species}/{atlas_name}] size={im.size} expected=({cols*cell_w},{rows*cell_h})')
        sheet=Image.new('RGBA',(cols*cell_w,rows*cell_h),(42,42,42,255)); dr=ImageDraw.Draw(sheet)
        for r,definition in enumerate(defs):
            row_boxes=[]
            for c in range(cols):
                cell=im.crop((c*cell_w,r*cell_h,(c+1)*cell_w,(r+1)*cell_h))
                bbox=cell.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox(); row_boxes.append(bbox)
                x=c*cell_w; y=r*cell_h; bg=Image.new('RGBA',(cell_w,cell_h),(62,62,62,255)); bg.alpha_composite(cell); sheet.alpha_composite(bg,(x,y))
                dr.rectangle((x,y,x+cell_w-1,y+cell_h-1),outline=(255,70,70,255),width=2)
                dr.text((x+5,y+5),f'{r}:{c}',fill=(255,255,0,255))
            report.append(f"  row {r:02d} {definition['id']}: {row_boxes}")
        sheet.save(out/f'{species}-{atlas_name}.png')
        arr,labels,assignments,comps=component_assignments(im,rows)
        report.append(f'  connected components >=8px: {len(comps)}')
        clean,preview=clean_sheet(im,rows,assignments,labels,arr)
        clean.save(out/f'clean-{species}-{atlas_name}.png'); preview.save(out/f'preview-clean-{species}-{atlas_name}.png')

(out/'report.txt').write_text('\n'.join(report)); print('\n'.join(report))
