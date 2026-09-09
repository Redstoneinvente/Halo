"""Portable structural validation. Does not compile Swift or prove runtime behavior."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
pbx = (root / "Halo.xcodeproj/project.pbxproj").read_text()
definitions = re.findall(r"^([0-9A-F]{24}) =", pbx, re.M)
assert len(definitions) == len(set(definitions)), "Duplicate project object IDs"
assert set(re.findall(r"\b[0-9A-F]{24}\b", pbx)) <= set(definitions), "Unresolved project object IDs"
paths = re.findall(r'lastKnownFileType = sourcecode.swift; path = "?([^";]+)"?;', pbx)
for path in paths:
    full = root / path if path.startswith("Tests/") else root / "Halo" / path
    assert full.is_file(), f"Missing source: {path}"
expected = {str(p.relative_to(root / "Halo")) for p in (root / "Halo").rglob("*.swift")}
assert expected <= set(paths), f"Sources absent from project: {expected - set(paths)}"
scheme = ET.parse(root / "Halo.xcodeproj/xcshareddata/xcschemes/Halo.xcscheme")
for ref in scheme.findall(".//BuildableReference"):
    assert ref.attrib["BlueprintIdentifier"] in definitions
assert scheme.find(".//TestableReference") is not None, "Scheme has no test target"
with (root / "Halo/Halo.entitlements").open("rb") as stream:
    plistlib.load(stream)
for path in (root / "Examples").iterdir():
    if path.suffix in {".haloTheme", ".haloPlugin"}:
        data = json.loads(path.read_text())
        assert data["version"] == 1
print(f"PASS: {len(expected)} app sources, project references, test scheme, entitlements, examples")
try:
    import tree_sitter
    import tree_sitter_swift
except ImportError:
    print("SKIP: Swift syntax parser unavailable; run Xcode validation on macOS")
else:
    parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
    failures = []
    for source in root.rglob("*.swift"):
        tree = parser.parse(source.read_bytes())
        if tree.root_node.has_error:
            def visit(node):
                if node.type == "ERROR" or node.is_missing:
                    failures.append(f"{source.relative_to(root)}:{node.start_point.row + 1}: {node.type}")
                for child in node.children:
                    visit(child)
            visit(tree.root_node)
    assert not failures, "Swift syntax errors:\n" + "\n".join(failures)
    print("PASS: Swift grammar parsing (not SDK type-checking)")
