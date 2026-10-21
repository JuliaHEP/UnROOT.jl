# Dump the first N entries of every field of every RNTuple in a file to JSON via uproot.
import sys, os, json, math, uproot, awkward as ak, numpy as np
path, out, N = sys.argv[1], sys.argv[2], int(sys.argv[3])
res = {}
f = uproot.open(path)
for k in f.keys():
    obj = f[k]
    if not isinstance(obj, uproot.models.RNTuple.Model_ROOT_3a3a_RNTuple):
        continue
    name = k.split(";")[0]
    d = {"num_entries": int(obj.num_entries), "fields": {}, "errors": {}}
    for fname in obj.keys():
        try:
            arr = obj[fname].array(entry_stop=N)
            d["fields"][fname] = ak.to_list(arr)
        except Exception as e:
            d["errors"][fname] = f"{type(e).__name__}: {str(e)[:200]}"
    res[name] = d
def default(o):
    if isinstance(o, (np.integer,)): return int(o)
    if isinstance(o, (np.floating,)): return float(o)
    if isinstance(o, (bytes,)): return o.decode("latin1")
    if isinstance(o, np.ndarray): return o.tolist()
    return str(o)
with open(out, "w") as fh:
    json.dump(res, fh, default=default)
