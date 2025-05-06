# Use
#    @warnpcfail precompile(args...)
# if you want to be warned when a precompile directive fails
macro warnpcfail(ex::Expr)
    modl = __module__
    file = __source__.file === nothing ? "?" : String(__source__.file)
    line = __source__.line
    quote
        $(esc(ex)) || @warn """precompile directive
     $($(Expr(:quote, ex)))
 failed. Please report an issue in $($modl) (after checking for duplicates) or remove this directive.""" _file=$file _line=$line
    end
end


function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{Type{ROOTFile},String})
    Base.precompile(Tuple{Type{TTree},IOStream,TKey32,Dict{Int32, Any}})
    Base.precompile(Tuple{typeof(getindex),ROOTFile,String})
    Base.precompile(Tuple{typeof(readfields!),Cursor,Dict{Symbol, Any},Type{TBranch_13}})
    Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TLeafF}})
    Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TLeafI}})
    Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TObjArray}})
    Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerBase}})
    Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerBasicPointer}})
    Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerBasicType}})
    Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerSTL}})
    Base.precompile(Tuple{var"##s446#126",Any,Any,Any})
end
