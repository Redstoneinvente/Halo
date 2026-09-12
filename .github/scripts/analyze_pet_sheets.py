from pathlib import Path
from PIL import Image, ImageDraw
import json
import numpy as np
from scipy import ndimage

root = Path('Halo/Halo Icons/Pets/halo-pets-v2')
out = Path('/tmp/pet-atlas-analysis')
out.mkdir(parents=True, exist_ok=True)
manifest = json.loads((root/'manifest.json').read_text())
cell_w = manifest['cellSize']['width']
cell_h = manifest['cellSize']['height']
cols = manifest['columns']
report=[]

def nearest_cell(cx, cy, rows):
    c = int(round((cx - cell_w/2) / cell_w))
    r = int(round((cy - cell_h/2) / cell_h))
    return max(0,min(cols-1,c)), max(0,min(rows-1,r))

def component_assignments(im, rows):
    arr=np.array(im)
    alpha=arr[:,:,3]
    labels,count=ndimage.label(alpha>=8)
    objects=ndimage.find_objects(labels)
    assignments={(r,c):[] for r in range(rows) for c in range(cols)}
    comps=[]
    for lab, sl in enumerate(objects, start=1):
        if sl is None: continue
        yy,xx=sl
        sub=(labels[yy,xx]==lab)
        area=int(sub.sum())
        if area < 8: continue
        ys,xs=np.nonzero(sub)
        gx=xs+xx.start; gy=ys+yy.start
        cx=float(gx.mean()); cy=float(gy.mean())
        c,r=nearest_cell(cx,cy,rows)
        bbox=(int(gx.min()),int(gy.min()),int(gx.max()+1),int(gy.max()+1))
        comps.append((lab,area,cx,cy,bbox,r,c))
        assignments[(r,c)].append((lab,area,bbox))
    return arr,labels,assignments,comps

def clean_sheet(im, rows, assignments, labels, arr):
    # Build one canonical coordinate space per animation row. Connected components are assigned
    # from the whole transparent atlas, so pixels that overflow a nominal 200x200 cell stay with
    # the correct frame instead of becoming neighbour fragments.
    output=Image.new('RGBA',(cols*cell_w,rows*cell_h),(0,0,0,0))
    previews=Image.new('RGBA',(cols*cell_w,rows*cell_h),(42,42,42,255))
    pd=ImageDraw.Draw(previews)
    for r in range(rows):
        relative_boxes=[]
        frame_masks=[]
        for c in range(cols):
            labs=[lab for lab,area,bbox in assignments[(r,c)] if area>=20]
            mask=np.isin(labels,labs) if labs else np.zeros(labels.shape,dtype=bool)
            ys,xs=np.nonzero(mask)
            if len(xs)==0:
                frame_masks.append((mask,None))
                continue
            bbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
            rel=(bbox[0]-c*cell_w,bbox[1]-r*cell_h,bbox[2]-c*cell_w,bbox[3]-r*cell_h)
            relative_boxes.append(rel)
            frame_masks.append((mask,bbox))
        if not relative_boxes:
            continue
        ux0=min(b[0] for b in relative_boxes); uy0=min(b[1] for b in relative_boxes)
        ux1=max(b[2] for b in relative_boxes); uy1=max(b[3] for b in relative_boxes)
        union_w=max(1,ux1-ux0); union_h=max(1,uy1-uy0)
        pad=8
        scale=min(1.0,(cell_w-2*pad)/union_w,(cell_h-2*pad)/union_h)
        target_w=max(1,int(round(union_w*scale))); target_h=max(1,int(round(union_h*scale)))
        base_x=(cell_w-target_w)//2; base_y=(cell_h-target_h)//2
        report.append(f'    clean row {r}: union=({ux0},{uy0},{ux1},{uy1}) size={union_w}x{union_h} scale={scale:.3f}')
        for c,(mask,bbox) in enumerate(frame_masks):
            if bbox is None: continue
            # Reconstruct only components assigned to this frame on a canonical row-union canvas.
            canvas=np.zeros((union_h,union_w,4),dtype=np.uint8)
            ys,xs=np.nonzero(mask)
            # Convert global pixel positions into row-relative canonical coordinates.
            lx=xs-c*cell_w-ux0; ly=ys-r*cell_h-uy0
            valid=(lx>=0)&(ly>=0)&(lx<union_w)&(ly<union_h)
            canvas[ly[valid],lx[valid]]=arr[ys[valid],xs[valid]]
            frame=Image.fromarray(canvas,'RGBA')
            if scale < 0.999:
                frame=frame.resize((target_w,target_h),Image.Resampling.LANCZOS)
            cell=Image.new('RGBA',(cell_w,cell_h),(0,0,0,0))
            cell.alpha_composite(frame,(base_x,base_y))
            output.alpha_composite(cell,(c*cell_w,r*cell_h))
            bg=Image.new('RGBA',(cell_w,cell_h),(62,62,62,255)); bg.alpha_composite(cell)
            previews.alpha_composite(bg,(c*cell_w,r*cell_h))
            pd.rectangle((c*cell_w,r*cell_h,(c+1)*cell_w-1,(r+1)*cell_h-1),outline=(255,70,70,255),width=2)
            pd.text((c*cell_w+5,r*cell_h+5),f'{r}:{c}',fill=(255,255,0,255))
    return output,previews

for species in ['cat','dog','fox']:
    for atlas_name, defs in manifest['atlases'].items():
        p = root/species/f'{atlas_name}.png'
        im = Image.open(p).convert('RGBA')
        rows = len(defs)
        report.append(f'[{species}/{atlas_name}] size={im.size} expected=({cols*cell_w},{rows*cell_h})')
        sheet = Image.new('RGBA', (cols*cell_w, rows*cell_h), (42,42,42,255))
        dr = ImageDraw.Draw(sheet)
        for r, definition in enumerate(defs):
            row_boxes=[]
            for c in range(cols):
                cell=im.crop((c*cell_w,r*cell_h,(c+1)*cell_w,(r+1)*cell_h))
                alpha=cell.getchannel('A')
                mask=alpha.point(lambda a: 255 if a >= 8 else 0)
                bbox=mask.getbbox()
                row_boxes.append(bbox)
                x=c*cell_w; y=r*cell_h
                bg=Image.new('RGBA',(cell_w,cell_h),(62,62,62,255)); bg.alpha_composite(cell)
                sheet.alpha_composite(bg,(x,y))
                dr.rectangle((x,y,x+cell_w-1,y+cell_h-1),outline=(255,70,70,255),width=2)
                if bbox:
                    bx0,by0,bx1,by1=bbox
                    dr.rectangle((x+bx0,y+by0,x+bx1-1,y+by1-1),outline=(60,255,110,255),width=2)
                dr.text((x+5,y+5),f'{r}:{c}',fill=(255,255,0,255))
            report.append(f"  row {r:02d} {definition['id']}: {row_boxes}")
        sheet.save(out/f'{species}-{atlas_name}.png')

        arr,labels,assignments,comps=component_assignments(im,rows)
        report.append(f'  connected components >=8px: {len(comps)}')
        clean,preview=clean_sheet(im,rows,assignments,labels,arr)
        clean.save(out/f'clean-{species}-{atlas_name}.png')
        preview.save(out/f'preview-clean-{species}-{atlas_name}.png')

(out/'report.txt').write_text('\n'.join(report))
print('\n'.join(report))
