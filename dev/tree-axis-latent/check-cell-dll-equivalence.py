#!/usr/bin/env python3
"""Binary-only audit of the two retained macOS DLLs; no R or model evaluation.

Executable/data sections, dyld payloads, ordinary symbols, load commands and
all remaining bytes must agree. Only UUID, N_OSO debug timestamps and code
signature payload bytes may differ. A verify call recomputes the full audit.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

BASE = Path("/private/tmp/gllvm-tree-axis-latent-20260830")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def audit():
    old_path = BASE / "cell-library/gllvmTMB/libs/gllvmTMB.so"
    new_path = BASE / "cell-library-v2/gllvmTMB/libs/gllvmTMB.so"
    old, new = old_path.read_bytes(), new_path.read_bytes()
    assert len(old) == len(new) and old[:32] == new[:32]
    magic, _, _, _, ncmds, cmdbytes, _, _ = struct.unpack_from("<IiiIIIII", old)
    assert magic == 0xFEEDFACF
    allowed, sections, dyld, timestamps = [], [], [], []
    cursor = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", old, cursor)
        assert size >= 8 and cursor + size <= 32 + cmdbytes
        assert (cmd, size) == struct.unpack_from("<II", new, cursor)
        a, b = old[cursor:cursor + size], new[cursor:cursor + size]
        if cmd == 0x1B:  # LC_UUID
            assert size == 24 and a[:8] == b[:8]
            allowed.append(dict(start=cursor + 8, end=cursor + 24, kind="UUID"))
        else:
            assert a == b, f"Changed load command {cmd:#x}"
        if cmd == 0x19:  # LC_SEGMENT_64: section_64 entries follow 72-byte header
            nsects = struct.unpack_from("<I", a, 64)[0]
            assert size == 72 + 80 * nsects
            for j in range(nsects):
                definition = a[72 + 80 * j:72 + 80 * (j + 1)]
                name, segment, _, length, offset, _, _, _, flags, _, _, _ = struct.unpack(
                    "<16s16sQQIIIIIIII", definition)
                if length == 0 or flags & 0xFF in (1, 12, 18):
                    continue  # zero-fill sections have no file-backed bytes
                assert offset + length <= len(old)
                assert old[offset:offset + length] == new[offset:offset + length]
                sections.append(dict(name=name.rstrip(b"\0").decode(),
                    segment=segment.rstrip(b"\0").decode(), offset=offset, size=length,
                    definition_sha256=sha(definition),
                    old_sha256=sha(old[offset:offset + length]),
                    new_sha256=sha(new[offset:offset + length])))
        if cmd in (0x22, 0x80000022):  # LC_DYLD_INFO[_ONLY]
            values = struct.unpack("<II10I", a)[2:]
            for j, name in enumerate(("rebase", "bind", "weak_bind", "lazy_bind", "export")):
                offset, length = values[2 * j:2 * j + 2]
                assert offset + length <= len(old)
                assert old[offset:offset + length] == new[offset:offset + length]
                dyld.append(dict(name=name, offset=offset, size=length,
                    old_sha256=sha(old[offset:offset + length]),
                    new_sha256=sha(new[offset:offset + length])))
        if cmd == 0x2:  # LC_SYMTAB: only N_OSO n_value debug timestamps may differ
            _, _, offset, nsyms, strings, string_size = struct.unpack("<IIIIII", a)
            assert offset + 16 * nsyms <= len(old) and strings + string_size <= len(old)
            assert old[strings:strings + string_size] == new[strings:strings + string_size]
            for j in range(nsyms):
                at = offset + 16 * j
                sym_a, sym_b = old[at:at + 16], new[at:at + 16]
                strx, kind, _, _, value = struct.unpack("<IBBHQ", sym_a)
                if kind == 0x66:
                    assert sym_a[:8] == sym_b[:8] and strx < string_size
                    end = old.index(0, strings + strx, strings + string_size)
                    name = old[strings + strx:end].decode()
                    allowed.append(dict(start=at + 8, end=at + 16, kind="N_OSO timestamp"))
                    timestamps.append(dict(name=name, offset=at + 8, old=value,
                        new=struct.unpack("<IBBHQ", sym_b)[4]))
                else:
                    assert sym_a == sym_b, f"Changed non-N_OSO symbol {j}"
        if cmd == 0x1D:  # LC_CODE_SIGNATURE
            _, _, offset, length = struct.unpack("<IIII", a)
            assert offset + length <= len(old)
            allowed.append(dict(start=offset, end=offset + length, kind="code signature"))
        cursor += size
    assert cursor == 32 + cmdbytes and len(sections) == 15 and len(dyld) == 5
    runs = []
    for i, (a, b) in enumerate(zip(old, new)):
        if a == b:
            continue
        if runs and runs[-1][1] == i:
            runs[-1][1] += 1
        else:
            runs.append([i, i + 1])
    differences = []
    for start, end in runs:
        matches = [x for x in allowed if x["start"] <= start and end <= x["end"]]
        assert len(matches) == 1, f"Difference outside ignored metadata: {start}:{end}"
        differences.append(dict(offset=start, length=end - start, kind=matches[0]["kind"]))
    return dict(schema="tree-axis-cell-mach-o-equivalence-v1", equivalent=True,
        old_file=dict(path=str(old_path), sha256=sha(old), size=len(old)),
        new_file=dict(path=str(new_path), sha256=sha(new), size=len(new)),
        sections=sections, dyld=dyld, debug_timestamps=timestamps,
        allowed_metadata=allowed, differences=differences,
        differing_bytes=sum(x["length"] for x in differences),
        auditor_sha256=sha(Path(__file__).read_bytes()),
        model_evaluations=0, outer_optimizer_calls=0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", type=Path)
    group.add_argument("--verify", type=Path)
    opts = parser.parse_args()
    receipt = audit()
    if opts.write:
        with opts.write.open("x") as stream:
            json.dump(receipt, stream, indent=2)
            stream.write("\n")
    else:
        assert json.loads(opts.verify.read_text()) == receipt, "Binary audit receipt changed"
    print("CELL_DLL_EQUIVALENCE_PASS: 15 file-backed sections and 5 dyld payloads exact; "
          f"{receipt['differing_bytes']} differing bytes restricted to non-model metadata; zero model evaluations")
