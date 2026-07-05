#!/usr/bin/env python3
"""Register an existing resource file (JSON, etc.) into Fidel.xcodeproj
(objectVersion 56, manual file references). Idempotent. Places the file in the
folder-group that matches its parent directory and in the Fidel app target's
Resources build phase.

This is the Resources-phase analog of add_swift_file.py (which only handles
.swift files in Sources phases). Use it for bundled content JSON added under
Fidel/Data/ — e.g. new lesson-type content banks.

Usage:
    python3 tools/add_resource_file.py Fidel/Data/reading_passages.json
    python3 tools/add_resource_file.py Fidel/Data/listening_dialogues.json

Routing:
  - The file is added to the group matching its parent directory (e.g. Data).
  - It is added to the Fidel app target's Resources build phase (the phase that
    already bundles vocabulary.json), never the FidelTests phase.

New ids use the collision-free "FE" range so they never clash with the "FF"
range add_swift_file.py assigns, nor the existing AAA00.. / AAA01.. ids.
"""
import os
import sys

PBX = "Fidel.xcodeproj/project.pbxproj"

# A resource we know lives in the Fidel app's Resources build phase. Used to
# disambiguate the app phase from the (empty) FidelTests Resources phase.
APP_RESOURCE_MARKER = "vocabulary.json in Resources"

# Map file extension -> pbxproj lastKnownFileType.
FILE_TYPES = {
    ".json": "text.json",
    ".csv": "text",
    ".txt": "text",
    ".plist": "text.plist.xml",
}


def fail(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        fail("expected exactly one argument: the repo-relative resource path")
    rel = sys.argv[1]
    name = os.path.basename(rel)
    parent = os.path.basename(os.path.dirname(rel))
    ext = os.path.splitext(name)[1].lower()
    if ext not in FILE_TYPES:
        fail(f"unsupported resource extension {ext!r}; supported: {sorted(FILE_TYPES)}")
    if not os.path.exists(rel):
        fail(f"file does not exist on disk: {rel} (create it first)")

    text = open(PBX).read()
    if f"/* {name} */" in text:
        print(f"SKIP: {name} already referenced in project")
        return

    file_type = FILE_TYPES[ext]

    # Unique id pair in the FE range (distinct from add_swift_file.py's FF range).
    n = 1
    while f"AAAFE{n:04d}00" in text:
        n += 1
    ref_id = f"AAAFE{n:04d}00"    # PBXFileReference
    build_id = f"AAAFE{n:04d}01"  # PBXBuildFile

    build_line = (f"\t\t{build_id} /* {name} in Resources */ = "
                  f"{{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};\n")
    ref_line = (f"\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; "
                f"lastKnownFileType = {file_type}; path = {name}; "
                f"sourceTree = \"<group>\"; }};\n")
    child_line = f"\t\t\t\t{ref_id} /* {name} */,\n"
    phase_line = f"\t\t\t\t{build_id} /* {name} in Resources */,\n"

    # 1) PBXBuildFile section
    marker = "/* Begin PBXBuildFile section */\n"
    if marker not in text:
        fail("no PBXBuildFile section")
    text = text.replace(marker, marker + build_line, 1)

    # 2) PBXFileReference section
    marker = "/* Begin PBXFileReference section */\n"
    if marker not in text:
        fail("no PBXFileReference section")
    text = text.replace(marker, marker + ref_line, 1)

    # 3) Group children — find the PBXGroup whose `path = <parent>;`, then insert
    #    the child right after that group's `children = (` line.
    path_tok = f"\n\t\t\tpath = {parent};\n"
    pidx = text.find(path_tok)
    if pidx == -1:
        fail(f"could not find group with path = {parent}")
    cidx = text.rfind("children = (\n", 0, pidx)
    if cidx == -1:
        fail(f"could not find children list for group {parent}")
    insert_at = cidx + len("children = (\n")
    text = text[:insert_at] + child_line + text[insert_at:]

    # 4) Fidel app Resources build phase — the one already bundling vocabulary.json,
    #    NOT the empty FidelTests Resources phase. Use rfind: the marker also occurs
    #    in the (earlier) PBXBuildFile section; its LAST occurrence is the phase entry.
    midx = text.rfind(APP_RESOURCE_MARKER)
    if midx == -1:
        fail(f"could not find the app Resources phase (marker {APP_RESOURCE_MARKER!r})")
    fidx = text.rfind("files = (\n", 0, midx)
    if fidx == -1:
        fail("could not find files list in the app Resources phase")
    insert_at = fidx + len("files = (\n")
    text = text[:insert_at] + phase_line + text[insert_at:]

    open(PBX, "w").write(text)
    print(f"ADDED {name}: group={parent} target=Fidel(Resources) "
          f"ref={ref_id} build={build_id}")


if __name__ == "__main__":
    main()
