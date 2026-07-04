#!/usr/bin/env python3
"""Deregister a Swift file from Fidel.xcodeproj (objectVersion 56, manual refs).
Removes the file's 4 pbxproj lines (PBXBuildFile, PBXFileReference, group child,
Sources phase entry). Symmetric with add_swift_file.py. Idempotent.

Usage:
    python3 tools/remove_swift_file.py FidelTests/LearnHeroTests.swift

Only edits project.pbxproj; delete the file from disk separately (git rm).
Matches the 4 lines by the file's basename appearing in a pbxproj comment/path,
which for a unique filename is exactly those 4 lines.
"""
import os
import sys

PBX = "Fidel.xcodeproj/project.pbxproj"


def main():
    if len(sys.argv) != 2:
        print("ERROR: expected one arg: the repo-relative .swift path")
        sys.exit(1)
    name = os.path.basename(sys.argv[1])
    if not name.endswith(".swift"):
        print("ERROR: only .swift files")
        sys.exit(1)

    lines = open(PBX).read().splitlines(keepends=True)
    # A pbxproj line referencing this file always contains either the comment
    # "/* <name> */" / "/* <name> in Sources */" or "path = <name>;".
    tok_comment = f"/* {name} "
    tok_comment2 = f"/* {name} */"
    tok_path = f"path = {name};"
    kept = [ln for ln in lines
            if not (tok_comment in ln or tok_comment2 in ln or tok_path in ln)]

    removed = len(lines) - len(kept)
    if removed == 0:
        print(f"SKIP: {name} not referenced in project")
        return
    open(PBX, "w").writelines(kept)
    print(f"REMOVED {name}: deleted {removed} pbxproj line(s) "
          f"(expected 4: buildFile, fileRef, group child, sources entry)")


if __name__ == "__main__":
    main()
