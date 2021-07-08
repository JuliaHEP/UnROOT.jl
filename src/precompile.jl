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


Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TLeafB}})
Base.precompile(Tuple{typeof(show),IOContext{IOBuffer},LazyBranch{Vector{Float32}, Nooffsetjagg}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TBranch}})
Base.precompile(Tuple{typeof(show),IOContext{IOBuffer},TBranch_13})
Base.precompile(Tuple{typeof(decompress_datastreambytes),Vector{UInt8},TBasketKey})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerBasicPointer}})
Base.precompile(Tuple{Type{ROOTDirectory},String,ROOTDirectoryHeader32,Vector{TKey32}})
Base.precompile(Tuple{typeof(compressed_datastream),IOStream,TBasketKey})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerSTL}})
Base.precompile(Tuple{Type{Table},ROOTFile,String,Vector{String}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerBasicType}})
Base.precompile(Tuple{typeof(getindex),ROOTFile,String})
Base.precompile(Tuple{typeof(interped_data),Vector{UInt8},Vector{Int32},TBranch_13,Type{Nooffsetjagg},Type{Vector{Float32}}})
Base.precompile(Tuple{typeof(interp_jaggT),TBranch_13,TLeafF})
Base.precompile(Tuple{Type{ROOTFile},String})
Base.precompile(Tuple{typeof(getindex),TTree,String})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerObject}})
Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:version, :fArrayLength, :fCountClass, :fXmax, :fSize, :fTitle, :fXmin, :fType, :fTypeName, :fName, :fArrayDim, :fCountName, :fFactor, :fMaxIndex, :fCountVersion, :fOffset), Tuple{UInt16, Int32, String, Float64, Int32, String, Float64, Int32, String, String, Int32, String, Float64, Vector{Int32}, Int32, Int64}},Type{TStreamerBasicPointer}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TLeafF}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerObjectPointer}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TLeafL}})
Base.precompile(Tuple{typeof(basketarray),ROOTFile,TBranch_13,Int64})
Base.precompile(Tuple{Type{TTree},IOStream,TKey32,Dict{Int32, Any}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerString}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TLeafO}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerObjectAny}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TLeafI}})
Base.precompile(Tuple{Type{LazyBranch},ROOTFile,TBranch_13})
Base.precompile(Tuple{typeof(readfields!),Cursor,Dict{Symbol, Any},Type{TBranch_13}})
Base.precompile(Tuple{typeof(unpack),IOBuffer,TKey32,Dict{Int32, Any},Type{TStreamerBase}})
Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:cursor, :fFirstEntry, :fIOFeatures, :fFillColor, :fMaxBaskets, :fWriteBasket, :fEntryOffsetLen, :fBaskets, :fTitle, :fZipBytes, :fSplitLevel, :fCompress, :fBasketSize, :fName, :fTotBytes, :fBasketEntry, :fLeaves, :fBasketSeek, :fFillStyle, :fBasketBytes, :fEntries, :fBranches, :fFileName, :fEntryNumber, :fOffset), Tuple{Cursor, Int64, ROOT_3a3a_TIOFeatures, Int16, UInt32, Int32, Int32, TObjArray, String, Int64, Int32, Int32, Int32, String, Int64, Vector{Int64}, TObjArray, Vector{Int64}, Int16, Vector{Int32}, Int64, TObjArray, String, Int64, Int32}},Type{TBranch_13}})
