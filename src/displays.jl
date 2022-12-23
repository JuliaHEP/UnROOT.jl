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
children(t::Union{TTree, TBranchElement}) = t.fBranches
Base.show(io::IO, ::MIME"text/plain", b::Union{TTree, TBranchElement}) = print_tree(io, b)
printnode(io::IO, t::TBranchElement) = print(io, "$(t.fName)")
printnode(io::IO, t::TTree) = print(io, "$(t.fName) (TTree)")
printnode(io::IO, f::ROOTFile) = print(io, f.filename)
printnode(io::IO, f::ROOTDirectory) = print(io, "$(f.name) (TDirectory)")
printnode(io::IO, k::TKeyNode) = print(io, "$(k.name) ($(k.classname))")

Base.show(tree::LazyTree; kwargs...) = _show(stdout, tree; crop=:both, kwargs...)
Base.show(io::IO, tree::LazyTree; kwargs...) = _show(io, tree; kwargs...)
Base.show(io::IO, ::MIME"text/plain", tree::LazyTree) = _show(io, tree)
function _show(io::IO, tree::LazyTree; kwargs...)
    _hs = _make_header(tree)
    _ds = displaysize(io)
    PrettyTables.pretty_table(
        io,
        Tables.columns(tree);
        header=_hs,
        alignment=:l,
        vlines=[1],
        hlines=[:header],
        reserved_display_lines=2,
        row_number_alignment=:l,
        row_number_column_title="Row",
        show_row_number=true,
        compact_printing=false,
        formatters=(v, i, j) -> _treeformat(v, _ds[2] ÷ min(8, length(_hs[1]))),
        display_size=(min(_ds[1], 40), min(_ds[2], 160)),
        kwargs...
    )
    nothing
end


function Base.show(io::IO, ::MIME"text/plain", br::LazyBranch)
    print(io, summary(br))
    println(io, ": ")
    if length(br) < 200
        Base.print_array(IOContext(io, :limit => true), br[:])
    else
        head = @async br[1:100]
        tail = @async br[end-99:end]
        wait(head)
        wait(tail)
        Base.print_array(IOContext(io, :limit => true), vcat(head.result, tail.result))
    end
    nothing
end

# stop crazy stracktrace
function Base.show(io::IO, 
    ::Type{<:LazyTree{<:NamedTuple{Ns, Vs}}}) where {Ns, Vs}
    elip = length(Ns) > 5 ? "..." : ""
    println(io, "LazyTree with $(length(Ns)) branches:")
    println(io, join(first(Ns, 5), ", "), elip)
end

function Base.show(io::IO, ::MIME"text/html", tree::LazyTree)
    maxrows = 10
    maxcols = 30
    nrow = length(tree)
    t = Tables.columns(@view tree[1:min(maxrows,nrow)])
    # _hs has headers and subheaders
    _hs = first.(_make_header(tree), maxcols)
    ncol = length(t)
    withcommas(value) = reverse(join(join.(Iterators.partition(reverse(string(value)),3)),","))
    write(io, "<p>")
    write(io, "$(withcommas(nrow)) rows × $(ncol) columns")
    if (nrow > maxrows) && (ncol > maxcols)
        write(io, " (omitted printing of $(withcommas(nrow-maxrows)) rows and $(ncol-maxcols) columns)")
    elseif (nrow > maxrows)
        write(io, " (omitted printing of $(withcommas(nrow-maxrows)) rows)")
    elseif (ncol > maxcols)
        write(io, " (omitted printing of $(ncol-maxcols) columns)")
    end
    println(io, "</p>")
    PrettyTables.pretty_table(
        io,
        t;
        header=_hs,
        alignment=:l,
        row_number_column_title="",
        show_row_number=true,
        compact_printing=false,
        formatters=(v, i, j) -> _treeformat(v, 100),
        tf = PrettyTables.HtmlTableFormat(css = """th { color: #000; background-color: #fff; }"""),
        backend=Val(:html),
    )
    nothing
end
_symtup2str(symtup, trunc=15) = collect(first.(string.(symtup), trunc))
function _make_header(t)
    pn = propertynames(t)
    header = _symtup2str(pn)
    subheader = _symtup2str(eltype.(values(Tables.columns(t))))
    (header, subheader)
end
function _treeformat(val, trunc)
    s = if val isa AbstractArray{T} where T<:Integer
        T = Int
        replace(string(T.(val)), string(T)=>"")
    elseif val isa AbstractArray{T} where T<:AbstractFloat
        T = eltype(val)
        replace(string(round.(T.(val); sigdigits=3)), string(T)=>"")
    else
        string(val)
    end
    first(s, trunc)
end
