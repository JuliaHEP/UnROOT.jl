#=
These functions are used to display a ROOTFile is a tree-like fashion
by using `AbstractTrees` printing functions. We customize what the children
of ROOTFile and a TTree is, and how to print the final `node`.
=#
struct TKeyNode
    name::AbstractString
    classname::AbstractString
end
function children(f::T) where T <: Union{ROOTFile,ROOTDirectory}
    # display TTrees recursively
    # subsequent TTrees with duplicate fName will be skipped
    # since TKey cycle number is guaranteed to be decreasing
    # then all TKeys in the file which are not for a TTree
    seen = Set{String}()
    ch = Vector{Union{TTree,TKeyNode,ROOTDirectory}}()
    T === ROOTFile ? lock(f) : nothing
    for k in keys(f)
        try
            obj = f[k]
            obj isa TTree || continue
            obj.fName ∈ seen && continue
            push!(ch, obj)
            push!(seen, obj.fName)
        catch
        end
    end
    tkeys = T === ROOTFile ? f.directory.keys : f.keys
    for tkey in tkeys
        kn = TKeyNode(tkey.fName, tkey.fClassName)
        kn.classname == "TTree" && continue
        if kn.classname == "TDirectory"
            push!(ch, f[tkey.fName])
        else
            push!(ch, kn)
        end
    end
    T === ROOTFile ? unlock(f) : nothing
    ch
end
function children(t::TTree)
    ks = keys(t)
    if length(ks) < 2
        return ks
    elseif length(ks) > 7
        return vcat(first(ks, 3), "⋮", ks[end-2:end])
    else
        return ks
    end
end
printnode(io::IO, t::TTree) = print(io, "$(t.fName) (TTree)")
printnode(io::IO, f::ROOTFile) = print(io, f.filename)
printnode(io::IO, f::ROOTDirectory) = print(io, "$(f.name) (TDirectory)")
printnode(io::IO, k::TKeyNode) = print(io, "$(k.name) ($(k.classname))")

function Base.show(io::IO, tree::LazyTree)
    io = io === stdout ? IOContext(io, :limit=>true, :compact=>true) : io
    _hs = _make_header(tree)
    _ds = displaysize(io)
    PrettyTables.pretty_table(
        io,
        innertable(tree);
        header=_hs,
        alignment=:l,
        vlines=[1],
        hlines=[:header],
        crop_num_lines_at_beginning=2,
        row_number_alignment=:l,
        row_number_column_title="Row",
        show_row_number=true,
        compact_printing=false,
        formatters=(v, i, j) -> _treeformat(v, _ds[2] ÷ min(8, length(_hs[1]))),
        display_size=(min(_ds[1], 40), min(_ds[2], 160)),
    )
end
_symtup2str(symtup, trunc=15) = collect(first.(string.(symtup), trunc))
function _make_header(t)
    pn = propertynames(t)
    header = _symtup2str(pn)
    subheader = _symtup2str(Tables.columntype.(Ref(innertable(t)), pn))
    (header, subheader)
end
function _treeformat(val, trunc)
    s = if val isa AbstractArray{T} where T<:Integer
        string(Int.(val))
    elseif val isa AbstractArray{T} where T<:AbstractFloat
        T = eltype(val)
        replace(string(round.(T.(val); sigdigits=3)), string(T)=>"")
    else
        string(val)
    end
    first(s, trunc)
end
