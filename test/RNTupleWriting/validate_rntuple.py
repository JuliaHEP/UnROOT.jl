#!/usr/bin/env python
"""Validate a UnROOT.jl-written RNTuple file with C++ ROOT.

Reads the file with ROOT's RDataFrame and checks, for every column described in
the JSON sidecar produced by ``output_sample.jl``, that

  1. the column is *readable* by ROOT, and
  2. every value matches exactly what UnROOT.jl wrote (correctness).

Usage:
    validate_rntuple.py <file.root> [expected.json]

Exit status is non-zero if any column is missing, unreadable, or mismatched.
This is intentionally data-driven: it validates whatever columns the sidecar
lists, so extending `output_sample.jl` automatically extends the checks here.
"""
import json
import sys

import ROOT


def to_py(x):
    """Convert a read-back value (numpy scalar/array, cppyy RVec, str) to plain
    Python lists/scalars so it can be compared structurally."""
    if isinstance(x, bytes):
        return x.decode()
    if isinstance(x, str):
        return x
    if hasattr(x, "__len__"):           # numpy array, RVec, vector, list
        return [to_py(e) for e in x]
    if hasattr(x, "item"):              # numpy scalar
        return x.item()
    return x


def read_column(df, name, ctype):
    """Read one column into a plain Python list, one element per entry.

    Uses ``AsNumpy`` (which, unlike ``Take``, reads ``(u)int8`` columns as
    integers rather than chars) and falls back to ``Take`` for nested types
    that AsNumpy cannot materialize without a generated dictionary.
    """
    try:
        values = df.AsNumpy([name])[name]
    except Exception:
        values = df.Take[ctype](name).GetValue()
    return [to_py(v) for v in values]


def to_compare(got, exp, is_float):
    """Structurally compare a read-back value `got` against expected `exp`.

    The expected value (decoded from JSON) drives the recursion, so this works
    uniformly for scalars, vectors, and nested vectors.
    """
    if isinstance(exp, list):
        got_list = list(got)
        if len(got_list) != len(exp):
            return False, f"length {len(got_list)} != {len(exp)}"
        for i, (g, e) in enumerate(zip(got_list, exp)):
            ok, msg = to_compare(g, e, is_float)
            if not ok:
                return False, f"[{i}] {msg}"
        return True, ""
    if isinstance(exp, bool):
        return (bool(got) == exp), f"{bool(got)} != {exp}"
    if isinstance(exp, str):
        return (str(got) == exp), f"{str(got)!r} != {exp!r}"
    if is_float:
        return (float(got) == float(exp)), f"{float(got)!r} != {float(exp)!r}"
    return (int(got) == int(exp)), f"{int(got)} != {exp}"


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    root_file = argv[1]
    json_file = argv[2] if len(argv) >= 3 else root_file + ".expected.json"

    with open(json_file) as fh:
        spec = json.load(fh)

    ntuple = spec["ntuple_name"]
    n_entries = spec["n_entries"]
    columns = spec["columns"]
    print(f"Validating {root_file} (ntuple={ntuple!r}, "
          f"compression={spec.get('compression')}, "
          f"{len(columns)} columns, {n_entries} entries)")

    df = ROOT.RDataFrame(ntuple, root_file)

    # readability: entry count and column presence
    actual_count = int(df.Count().GetValue())
    if actual_count != n_entries:
        print(f"  FAIL entry count: got {actual_count}, expected {n_entries}")
        return 1
    available = set(str(c) for c in df.GetColumnNames())

    failures = 0
    for col in columns:
        name = col["name"]
        is_float = col["float"]
        expected = col["values"]

        if name not in available:
            print(f"  FAIL {name}: column not present in file")
            failures += 1
            continue

        try:
            ctype = str(df.GetColumnType(name))
            got = read_column(df, name, ctype)
        except Exception as exc:  # readability failure
            print(f"  FAIL {name}: not readable by ROOT ({exc})")
            failures += 1
            continue

        if len(got) != len(expected):
            print(f"  FAIL {name}: read {len(got)} entries, expected {len(expected)}")
            failures += 1
            continue

        ok, msg = to_compare(got, expected, is_float)
        if ok:
            print(f"  PASS {name} ({ctype})")
        else:
            print(f"  FAIL {name} ({ctype}): {msg}")
            failures += 1

    if failures:
        print(f"{failures}/{len(columns)} columns FAILED")
        return 1
    print(f"All {len(columns)} columns read back correctly.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
