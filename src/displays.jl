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
        kwargs...
    )
    nothing
end

function Base.show(io::IO, ::MIME"text/plain", br::LazyBranch)
    print(io, summary(br))
    println(": ")
    if length(br) < 200
        Base.print_array(IOContext(io, :limit => true), br[:])
    else
        head = @async br[1:100]
        tail = @async br[end-99:end]
        wait(head)
        wait(tail)
        Base.print_array(IOContext(io, :limit => true), Vcat(head.result, tail.result))
    end
    nothing
end

function Base.show(io::IO, ::MIME"text/html", tree::LazyTree)
    _hs = _make_header(tree)
    maxrows = 10
    maxcols = 30
    nrow = length(tree)
    t = @view innertable(tree)[1:min(maxrows,nrow)]
    ncol = length(Tables.columns(t))
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
    write(io, "</p>")
    PrettyTables.pretty_table(
        io,
        t;
        header=_hs,
        alignment=:l,
        row_number_column_title="",
        show_row_number=true,
        compact_printing=false,
        filters_col     = ((_,i) -> i <= maxcols,),
        formatters=(v, i, j) -> _treeformat(v, 100),
        tf = PrettyTables.HTMLTableFormat(css = """th { color: #000; background-color: #fff; }"""),
        backend=Val(:html),
    )
    nothing
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
