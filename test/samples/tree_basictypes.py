import ROOT as r

# from https://en.cppreference.com/w/cpp/language/types
typenames = [
        # char
        "char", "unsigned char",
        # bool
        "bool",
        # short
        "short", "short int", "signed short", "signed short int", "unsigned short", "unsigned short int",
        # int
        "int", "signed", "signed int", "unsigned", "unsigned int",
        # long
        "long", "long int", "long int", "signed long", "signed long int", "unsigned long", "unsigned long int",
        # long long
        "long long", "long long int", "signed long long", "signed long long int", "unsigned long long", "unsigned long long int",
        # float/double
        "float", "double",
        ]

print(len(typenames), typenames)

roottypestrs = set()
for typename in typenames:
    obj = r.vector(typename)
    # print(typename, obj, obj())
    roottypestr = str(obj).split("'")[1].split("<")[1].split(">")[0]
    roottypestrs.add(roottypestr)

# since many of the above map to the same "root type", `roottypestrs` ends up being

# {'long', 'Long64_t', 'unsigned char', 'short', 'unsigned long', 'long double',
#         'char', 'unsigned short', 'ULong64_t', 'float', 'bool', 'double',
#         'int', 'unsigned int'}

print(len(roottypestrs), roottypestrs)

import ROOT as r
f = r.TFile("tree_basictypes.root", "recreate")
t = r.TTree("t", "")

d_objs = dict()
for typename in roottypestrs:
    nicename = typename.lower().replace("_t","").replace(" ","")
    obj = r.vector(typename)()
    t.Branch(nicename, obj)
    d_objs[typename] = obj

for ievt in range(3):
    for typename, obj in d_objs.items():
        obj.clear()
        for _ in range(ievt):
            obj.push_back(1)
    t.Fill()

t.Write()
f.Close()
