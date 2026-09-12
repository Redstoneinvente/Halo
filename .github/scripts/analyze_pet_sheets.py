from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

root = Path('Halo/Halo Icons/Pets/halo-pets-v2')
out = Path('/tmp/pet-atlas-analysis')
out.mkdir(parents=True, exist_ok=True)
manifest = json.loads((root/'manifest.json').read_text())
cell_w = manifest['cellSize']['width']
cell_h = manifest['cellSize']['height']
cols = manifest['columns']
report=[]

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
                # Ignore near-transparent antialias noise.
                mask=alpha.point(lambda a: 255 if a >= 8 else 0)
                bbox=mask.getbbox()
                row_boxes.append(bbox)
                x=c*cell_w; y=r*cell_h
                # checker-ish neutral bg then actual cell
                bg=Image.new('RGBA',(cell_w,cell_h),(62,62,62,255))
                bg.alpha_composite(cell)
                sheet.alpha_composite(bg,(x,y))
                dr.rectangle((x,y,x+cell_w-1,y+cell_h-1),outline=(255,70,70,255),width=2)
                if bbox:
                    bx0,by0,bx1,by1=bbox
                    dr.rectangle((x+bx0,y+by0,x+bx1-1,y+by1-1),outline=(60,255,110,255),width=2)
                dr.text((x+5,y+5),f'{r}:{c}',fill=(255,255,0,255))
            report.append(f"  row {r:02d} {definition['id']}: {row_boxes}")
        sheet.save(out/f'{species}-{atlas_name}.png')

(out/'report.txt').write_text('\n'.join(report))
print('\n'.join(report))
