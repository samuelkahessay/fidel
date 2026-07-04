#!/usr/bin/env python3
"""Register an existing Swift file into Fidel.xcodeproj (objectVersion 56,
manual file references). Idempotent. Places the file in the folder-group that
matches its parent directory and in the correct target's Sources phase.

Usage:
    python3 tools/add_swift_file.py Fidel/Services/NextStepPlanner.swift
    python3 tools/add_swift_file.py FidelTests/NextStepPlannerTests.swift

Routing:
  - Path under FidelTests/  -> BAA ids, FidelTests group, FidelTests Sources phase.
  - Path under Fidel/<Folder>/ -> AAA ids, <Folder> group, Fidel Sources phase.

New ids use the collision-free "FF" range (existing ids are AAA00.. / AAA01.. / BAA00..).
"""
import os
import re
import sys

PBX = "Fidel.xcodeproj/project.pbxproj"
FIDEL_SOURCES_PHASE = "AAA00800001"  # Fidel target Sources build phase


def fail(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        fail("expected exactly one argument: the repo-relative .swift path")
    rel = sys.argv[1]
    name = os.path.basename(rel)
    parent = os.path.basename(os.path.dirname(rel))
    if not name.endswith(".swift"):
        fail("only .swift files are supported")
    if not os.path.exists(rel):
        fail(f"file does not exist on disk: {rel} (create it first)")

    text = open(PBX).read()
    if f"/* {name} */" in text:
        print(f"SKIP: {name} already referenced in project")
        return

    is_test = rel.split("/")[0] == "FidelTests"
    prefix = "BAA" if is_test else "AAA"
    group_path = "FidelTests" if is_test else parent

    # Unique id pair in the FF range.
    n = 1
    while f"{prefix}FF{n:04d}00" in text:
        n += 1
    ref_id = f"{prefix}FF{n:04d}00"    # PBXFileReference
    build_id = f"{prefix}FF{n:04d}01"  # PBXBuildFile

    build_line = (f"\t\t{build_id} /* {name} in Sources */ = "
                  f"{{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};\n")
    ref_line = (f"\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; "
                f"lastKnownFileType = sourcecode.swift; path = {name}; "
                f"sourceTree = \"<group>\"; }};\n")
    child_line = f"\t\t\t\t{ref_id} /* {name} */,\n"
    phase_line = f"\t\t\t\t{build_id} /* {name} in Sources */,\n"

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

    # 3) Group children — find the PBXGroup whose `path = <group_path>;`, then
    #    insert the child right after that group's `children = (` line.
    path_tok = f"\n\t\t\tpath = {group_path};\n"
    pidx = text.find(path_tok)
    if pidx == -1:
        fail(f"could not find group with path = {group_path}")
    cidx = text.rfind("children = (\n", 0, pidx)
    if cidx == -1:
        fail(f"could not find children list for group {group_path}")
    insert_at = cidx + len("children = (\n")
    text = text[:insert_at] + child_line + text[insert_at:]

    # 4) Correct Sources build phase.
    phases = [m.start() for m in re.finditer(
        r"[A-Z0-9]+ /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;", text)]
    if len(phases) < (2 if is_test else 1):
        fail("could not find the expected Sources build phase(s)")
    if is_test:
        # The phase that is NOT the Fidel app phase.
        target_phase = next(p for p in phases
                            if not text[p:p + 20].startswith(FIDEL_SOURCES_PHASE))
    else:
        target_phase = next(p for p in phases
                            if text[p:p + 20].startswith(FIDEL_SOURCES_PHASE))
    fidx = text.find("files = (\n", target_phase)
    if fidx == -1:
        fail("could not find files list in the target Sources phase")
    insert_at = fidx + len("files = (\n")
    text = text[:insert_at] + phase_line + text[insert_at:]

    open(PBX, "w").write(text)
    print(f"ADDED {name}: group={group_path} target={'FidelTests' if is_test else 'Fidel'} "
          f"ref={ref_id} build={build_id}")


if __name__ == "__main__":
    main()
