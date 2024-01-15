"""
    macro stack(into, structs...)

Stack the fields of multiple structs and create a new one.
The first argument is the name of the new struct followed by the
ones to be stacked. Parametric types are not supported and
the fieldnames needs to be unique.

Example:

    @stack Baz Foo Bar

Creates `Baz` with the concatenated fields of `Foo` and `Bar`

"""
macro stack(into, structs...)
    fields = []
    for _struct in structs
        names = fieldnames(getfield(__module__, _struct))
        types = [fieldtype(getfield(__module__, _struct), field) for field in names]
        for (n, t) in zip(names, types)
            push!(fields, :($n::$t))
        end
    end

    esc(
        quote
            struct $into
                $(fields...)
            end
        end
    )
end

"""
    unpack(x::CompressionHeader)

Return the following information:
- Name of compression algorithm
- Level of the compression
- compressedbytes and uncompressedbytes according to [uproot3](https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/source/compressed.py#L132)
"""
function unpack(x::CompressionHeader)
    algname = String(x.algo)
    # shift without casting to `Int` will give you 0x00 because we're shifting 0 bits into UInt8
    compressedbytes = x.c1 + (Int(x.c2) << 8) + (Int(x.c3) << 16)
    uncompressedbytes = x.u1 + (Int(x.u2) << 8) + (Int(x.u3) << 16)

    return algname, x.method, compressedbytes, uncompressedbytes
end


abstract type JaggType end
struct Nojagg      <:JaggType  end
struct Nooffsetjagg<:JaggType  end
struct Offsetjagg  <:JaggType  end
struct Offsetjaggjagg  <:JaggType  end
# this is a preliminary workaround for 6 byte offset jaggedness
struct Offset6jaggjagg  <:JaggType  end

function JaggType(f, branch, leaf)
    # https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/interp/auto.py#L144

    streamer = streamerfor(f, branch)

    # Currently assuming that if a full StreamerInfo is passed, we need to deal with
    # each entry as a whole instance
    typeof(streamer) == StreamerInfo && return Nojagg

    if !ismissing(streamer)
        if typeof(streamer) <: TStreamerBasicType
            (match(r"\[.*\]", leaf.fTitle) !== nothing) && return Nooffsetjagg
            return Nojagg
        end
        if typeof(streamer) <: TStreamerBase
            leaf isa TLeafElement && leaf.fLenType==0 && return Offsetjagg
            return Nojagg
        end
        if streamer.fSTLtype == Const.kSTLvector
            (match(r"\[.*\]", leaf.fTitle) !== nothing) && return Offset6jaggjagg
            return Offsetjagg
        end
    end

    # TODO this might be redundant but for now it works
    (match(r"\[.*\]", leaf.fTitle) !== nothing) && return Nooffsetjagg
    leaf isa TLeafElement && leaf.fLenType==0 && return Offsetjagg
    !hasproperty(branch, :fClassName) && return Nojagg

    return Nojagg
end

"""
    parseTH(th::Dict{Symbol, Any}; raw=true) -> (counts, edges, sumw2, nentries)
    parseTH(th::Dict{Symbol, Any}; raw=false) -> Union{FHist.Hist1D, FHist.Hist2D}

When `raw=true`, parse the output of [`TH`](@ref) into a tuple of `counts`, `edges`, `sumw2`, and `nentries`.
When `raw=false`, parse the output of [`TH`](@ref) into FHist.jl histograms.

# Example
```julia
julia> UnROOT.parseTH(UnROOT.samplefile("histograms1d2d.root")["myTH1D"])
([40.0, 2.0], (-2.0:2.0:2.0,), [800.0, 2.0], 4.0)

julia> UnROOT.parseTH(UnROOT.samplefile("histograms1d2d.root")["myTH1D"]; raw=false)
edges: -2.0:2.0:2.0
bin counts: [40.0, 2.0]
total count: 42.0
```

    !!! note
    TH1 and TH2 inputs are supported.
"""
function parseTH(th::Dict{Symbol, Any}; raw=true)
    xmin = th[:fXaxis_fXmin]
    xmax = th[:fXaxis_fXmax]
    xnbins = th[:fXaxis_fNbins]
    xbins = isempty(th[:fXaxis_fXbins]) ? range(xmin, xmax, length=xnbins+1) : th[:fXaxis_fXbins];
    counts = th[:fN]
    nentries = th[:fEntries]
    sumw2 = th[:fSumw2]
    dimension = th[:fYaxis_fNbins]
    if dimension > 1
        ymin = th[:fYaxis_fXmin]
        ymax = th[:fYaxis_fXmax]
        ynbins = th[:fYaxis_fNbins]
        ybins = isempty(th[:fYaxis_fXbins]) ? range(ymin, ymax, length=ynbins+1) : th[:fYaxis_fXbins];
        counts = reshape(counts, (xnbins+2, ynbins+2))[2:end-1, 2:end-1]
        if !isempty(sumw2)
            sumw2 = reshape(sumw2, (xnbins+2, ynbins+2))[2:end-1, 2:end-1]
        end
        edges = (xbins, ybins)
    else
        counts = counts[2:end-1]
        if !isempty(sumw2)
            sumw2 = sumw2[2:end-1]
        end
        edges = (xbins,)
    end
    if raw
        return counts, edges, sumw2, nentries
    elseif dimension > 1
        return Hist2D(FHist.Histogram(edges, counts),sumw2, nentries)
    else
        return Hist1D(FHist.Histogram(edges, counts),sumw2, nentries)
    end
end

function samplefile(filename::AbstractString)
    return ROOTFile(normpath(joinpath(@__DIR__, "../test/samples", filename)))
end
