#!/bin/bash
# Build release: generates zip, addons.xml and addons.xml.md5

set -e

ADDON_XML="addon.xml"
NAME=$(grep 'addon id=' "$ADDON_XML" | sed -nE 's/.*id="([^"]+)".*/\1/p' | head -1)
VERSION=$(grep 'addon id=' "$ADDON_XML" | sed -nE 's/.*version="([^"]+)".*/\1/p' | head -1)

echo "Building $NAME version $VERSION"
mkdir -p repo/service.upnext

# Create temp copy
mkdir -p .build_temp/service.upnext
cp addon.xml .build_temp/service.upnext/
cp -r resources .build_temp/service.upnext/
cp LICENSE README.md changelog.txt .build_temp/service.upnext/

cd .build_temp

# Create zip
ZIP_FILE="../repo/service.upnext/${NAME}-${VERSION}.zip"
zip -r "$ZIP_FILE" service.upnext/ \
    -x "*/\.*" "*/\__pycache__/*" "*/*.pyc" "*/*.pyo" "*.DS_Store" \
    > /dev/null 2>&1

echo "Created: $(basename $ZIP_FILE)"

cd ..
rm -rf .build_temp

# Build the repository addon zip (installed once by the user)
REPO_ADDON_XML="repository.campipaolo.upnext/addon.xml"
REPO_NAME=$(grep 'addon id=' "$REPO_ADDON_XML" | sed -nE 's/.*id="([^"]+)".*/\1/p' | head -1)
REPO_VERSION=$(grep 'addon id=' "$REPO_ADDON_XML" | sed -nE 's/.*version="([^"]+)".*/\1/p' | head -1)
mkdir -p "repo/${REPO_NAME}"
rm -f "repo/${REPO_NAME}/${REPO_NAME}-${REPO_VERSION}.zip"
zip -r "repo/${REPO_NAME}/${REPO_NAME}-${REPO_VERSION}.zip" "$REPO_NAME" \
    -x "*/\.*" "*.DS_Store" > /dev/null 2>&1
echo "Created: ${REPO_NAME}-${REPO_VERSION}.zip"

# Generate addons.xml and md5
echo "Generating addons.xml and addons.xml.md5"

python3 - <<'PYEOF'
import hashlib
from pathlib import Path

ADDON_XML = Path("addon.xml")
REPO_DIR = Path("repo")
addons_xml = REPO_DIR / "addons.xml"

# Read every addon.xml to publish (the addon itself and its repository addon)
parts = []
for src in (ADDON_XML, Path("repository.campipaolo.upnext/addon.xml")):
    with open(src) as f:
        content = f.read().strip()
        # Remove XML declaration if present
        if content.startswith('<?xml'):
            content = content.split('?>', 1)[1].strip()
        parts.append(content)

wrapped = '<?xml version="1.0" encoding="UTF-8"?>\n<addons>\n' + '\n'.join(parts) + '\n</addons>\n'

# Write addons.xml
with open(addons_xml, 'w') as f:
    f.write(wrapped)

# Write md5
md5 = hashlib.md5(wrapped.encode()).hexdigest()
with open(REPO_DIR / "addons.xml.md5", 'w') as f:
    f.write(md5)

print("  Created: addons.xml")
print("  Created: addons.xml.md5")
PYEOF

# Generate index.html listings so Kodi can browse repo/ as a file source
echo "Generating index.html listings"

python3 - <<'PYEOF'
from pathlib import Path
from urllib.parse import quote

SKIP_DIRS = {"resources"}

def write_index(folder):
    items = []
    for p in sorted(folder.iterdir()):
        if p.is_dir() and p.name not in SKIP_DIRS:
            items.append((p.name + "/", quote(p.name) + "/"))
        elif p.suffix == ".zip":
            items.append((p.name, quote(p.name)))
    lines = ['<!DOCTYPE html>', '<html><head><meta charset="utf-8">',
             '<title>Index of /</title></head><body>', '<h1>Index of /</h1>', '<pre>']
    if folder != Path("repo"):
        lines.append('<a href="../">../</a>')
    for label, href in items:
        lines.append('<a href="%s">%s</a>' % (href, label))
    lines += ['</pre>', '</body></html>', '']
    (folder / "index.html").write_text("\n".join(lines))
    print("  Created: %s/index.html" % folder)

root = Path("repo")
write_index(root)
for sub in sorted(root.iterdir()):
    if sub.is_dir() and sub.name not in SKIP_DIRS:
        write_index(sub)
PYEOF

echo ""
echo "Done! Files in repo/:"
ls -1 repo/
