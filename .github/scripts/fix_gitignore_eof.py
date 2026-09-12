from pathlib import Path
p = Path('.gitignore')
p.write_text(p.read_text().rstrip() + '\n')
