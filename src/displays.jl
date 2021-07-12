function children(f::ROOTFile)
    ch = Vector{TTree}()
    for k in keys(f)
        lock(f.fobj)
        try
            push!(ch, f[k])
        catch
        finally
            unlock(f.fobj)
        end
    end
    ch
end
function children(t::TTree)
    ks = keys(t)
    [ first(ks, 5); ifelse(length(ks)>5,"⋮","") ]
end
printnode(io::IO, t::TTree) = print(io, t.fName)
printnode(io::IO, f::ROOTFile) = print(io, f.filename)

function Base.show(io::IO, tree::LazyTree)
    _hs = _make_header(tree)
    _ds = displaysize(io)
    PrettyTables.pretty_table(
        io,
        tree;
        header=_hs,
        alignment=:l,
        vlines=[1],
        hlines=[:header],
        crop_num_lines_at_beginning=2,
        row_number_alignment=:l,
        row_number_column_title="Row",
        show_row_number=true,
        compact_printing=false,
        formatters=(v, i, j) -> _treeformat(v, _ds[2] ÷ min(5, length(_hs[1]))),
        display_size=(min(_ds[1], 40), min(_ds[2], 160)),
    )
end
_symtup2str(symtup, trunc=15) = collect(first.(string.(symtup), trunc))
function _make_header(t)
    pn = propertynames(t)
    header = _symtup2str(pn)
    subheader = _symtup2str(Tables.columntype.(Ref(t), pn))
    (header, subheader)
end
function _treeformat(val, trunc)
    s = if isempty(val)
        "[]"
    elseif val isa Vector{T} where T<:Integer
        string(Int.(val))
    elseif val isa Vector{T} where T<:AbstractFloat
        string(round.(Float64.(val); sigdigits=3))
    else
        string(val)
    end
    first(s, trunc)
end
