function children(f::ROOTFile)
    ch = Vector{TTree}()
    for k in keys(f)
        try
            push!(ch, f[k])
        catch
            unlock(f) #TODO remove these hacks
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

function Base.show(io::IO, m::MIME"text/plain", tree::T) where T <: _LazyTreeType
    PrettyTables.pretty_table(io, tree; 
                 header=_make_header(tree),
                 alignment = :l,
                 compact_printing=true,
                 crop = :both,
                 display_size = (min(Base.displaysize()[1], 40), -1),
                 vlines = :none,
                 formatters = _treeformat
                )
end
_symtup2str(symtup, trunc=15) = collect(first.(string.(symtup), trunc))
function _make_header(t)
    pn = propertynames(t)
    header = _symtup2str(pn)
    subheader = _symtup2str(Tables.columntype.(Ref(t), pn))
    (header, subheader)
end
function _treeformat(val, i, j)
    s = if isempty(val)
        "[]"
    elseif val isa Vector{T} where T<:Integer
        string(Int.(val))
    elseif val isa Vector{T} where T<:AbstractFloat
        string(round.(Float64.(val); sigdigits=3))
    else
        string(val)
    end
    s
end

