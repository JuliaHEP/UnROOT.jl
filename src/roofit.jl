"""
    AbstractRooAbsBinning

Abstract supertype for RooFit binning objects attached to a [`RooRealVar`](@ref).
"""
abstract type AbstractRooAbsBinning end

"""
    RooUniformBinning

Representation of a persisted `RooUniformBinning`. The current RooFitResult
reader keeps this type for API completeness, but may leave the `binning` field
of a [`RooRealVar`](@ref) as `missing` when the serialized binning object is not
needed by the current fixtures.
"""
struct RooUniformBinning <: AbstractRooAbsBinning
    name::String
    title::String
    xlo::Float64
    xhi::Float64
    nbins::Int32
    binw::Float64
end

"""
    RooRealVar

Julia representation of a persisted RooFit `RooRealVar`.

This exposes the parameter name, current value, symmetric/asymmetric errors,
plotting metadata, and the attached binning object when available.
"""
struct RooRealVar
    name::String
    title::String
    value::Float64
    error::Float64
    asymerrlo::Float64
    asymerrhi::Float64
    plotmin::Float64
    plotmax::Float64
    plotbins::Int32
    unit::String
    label::String
    bool_attributes::Set{String}
    string_attributes::Dict{String, String}
    binning::Union{Missing, AbstractRooAbsBinning}
end

"""
    RooArgList

Julia representation of a persisted RooFit `RooArgList`.

The contained arguments can be indexed by position or, when the elements carry
names, via `list["parameter_name"]`.
"""
struct RooArgList{T}
    name::String
    owncont::Bool
    allrrv::Bool
    args::Vector{T}
end

function _typed_rooarglist(name::String, owncont::Bool, allrrv::Bool, args::AbstractVector)
    T = isempty(args) ? Any : foldl(typejoin, map(typeof, args))
    return RooArgList{T}(name, owncont, allrrv, convert(Vector{T}, args))
end

Base.length(x::RooArgList) = length(x.args)
Base.getindex(x::RooArgList, i::Int) = x.args[i]
Base.iterate(x::RooArgList, state=1) = state > length(x) ? nothing : (x[state], state + 1)
Base.eltype(::Type{RooArgList{T}}) where {T} = T
Base.getindex(x::RooArgList, name::AbstractString) = only(filter(arg -> !ismissing(arg) && hasproperty(arg, :name) && getproperty(arg, :name) == name, x.args))

"""
    RooFitResult

Julia representation of a top-level persisted RooFit `RooFitResult`.

This provides access to the core fit summary, parameter lists, covariance and
correlation matrices when stored, and the global correlation coefficients.
"""
struct RooFitResult
    name::String
    title::String
    status::Int32
    covqual::Int32
    numbadnll::Int32
    minnll::Float64
    edm::Float64
    constpars::Union{Missing, RooArgList}
    initpars::Union{Missing, RooArgList}
    finalpars::Union{Missing, RooArgList}
    correlation_matrix::Union{Missing, Matrix{Float64}}
    covariance_matrix::Union{Missing, Matrix{Float64}}
    global_correlation_coefficients::Union{Missing, Vector{Float64}}
    status_history::Vector{Pair{String, Int32}}
end

function Base.show(io::IO, x::RooRealVar)
    print(io, "RooRealVar($(x.name)=$(x.value) +/- $(x.error))")
end

function Base.show(io::IO, x::RooArgList)
    print(io, "RooArgList($(length(x)) entries)")
end

function Base.show(io::IO, x::RooFitResult)
    nfloat = x.finalpars === missing ? 0 : length(x.finalpars)
    print(io, "RooFitResult($(x.name), $(nfloat) floating parameters)")
end

function _skip_versioned_object(io, T::Type)
    preamble = Preamble(io, T)
    endcheck(io, preamble)
end

function _skip_object(io, T::Type)
    preamble = Preamble(io, T)
    ismissing(preamble.cnt) && error("Unable to skip object $(T) without a byte count")
    seek(io, preamble.start + preamble.cnt)
    return nothing
end

function _seek_to_object_end(io, preamble::Preamble)
    ismissing(preamble.cnt) || seek(io, preamble.start + preamble.cnt)
    return nothing
end

function _skip_counted_blob(io)
    preamble = Preamble(io, Missing)
    ismissing(preamble.cnt) && error("Unable to skip counted blob without a byte count")
    seek(io, preamble.start + preamble.cnt)
    return nothing
end

function _read_tnamed(io)
    preamble = Preamble(io, TNamed)
    parsefields!(io, Dict{Symbol, Any}(), TObject)
    name = readtype(io, String)
    title = readtype(io, String)
    endcheck(io, preamble)
    return name, title
end

function _read_stl_vector(read_item::Function, io; header=true)
    preamble = header ? Preamble(io, Missing) : nothing
    n = Int(readtype(io, UInt32))
    out = Vector{Any}(undef, n)
    for i in 1:n
        out[i] = read_item(io)
    end
    header && endcheck(io, preamble)
    return out
end

function _read_stl_vector_uint(io; header=true)
    preamble = header ? Preamble(io, Missing) : nothing
    n = Int(readtype(io, UInt32))
    out = UInt32[readtype(io, UInt32) for _ in 1:n]
    header && endcheck(io, preamble)
    return out
end

function _read_rooabscollection(io, tkey, refs)
    preamble = Preamble(io, RooAbsCollection)
    parsefields!(io, Dict{Symbol, Any}(), TObject)
    _skip_versioned_object(io, RooPrintable)
    args = _read_stl_vector(io) do io′
        readobjany!(io′, tkey, refs)
    end
    owncont = readtype(io, Bool)
    name = readtype(io, String)
    allrrv = readtype(io, Bool)
    endcheck(io, preamble)
    return _typed_rooarglist(name, owncont, allrrv, args)
end

function _read_roostlrefcountlist(io, tkey, refs)
    preamble = Preamble(io, var"RooSTLRefCountList<RooAbsArg>")
    storage = _read_stl_vector(io) do io′
        readobjany!(io′, tkey, refs)
    end
    refcount = _read_stl_vector_uint(io)
    endcheck(io, preamble)
    return (; storage, refcount)
end

function _read_rooabsarg(io, tkey, refs)
    preamble = Preamble(io, RooAbsArg)
    name, title = _read_tnamed(io)
    _skip_versioned_object(io, RooPrintable)
    _read_roostlrefcountlist(io, tkey, refs)
    _read_roostlrefcountlist(io, tkey, refs)
    _read_roostlrefcountlist(io, tkey, refs)
    _read_roostlrefcountlist(io, tkey, refs)
    _skip_object(io, RooRefArray)
    # RooFit stores additional transient attribute containers here. We don't
    # expose them yet, but we do need to skip them cleanly to stay aligned.
    _skip_counted_blob(io)
    _skip_counted_blob(io)
    bool_attributes = Set{String}()
    string_attributes = Dict{String, String}()
    readtype(io, Bool)
    readtype(io, Bool)
    readtype(io, Int32)
    readtype(io, Bool)
    endcheck(io, preamble)
    return name, title, bool_attributes, string_attributes
end

function _read_rooabsreal(io, tkey, refs)
    preamble = Preamble(io, RooAbsReal)
    name, title, bool_attributes, string_attributes = _read_rooabsarg(io, tkey, refs)
    plotmin = readtype(io, Float64)
    plotmax = readtype(io, Float64)
    plotbins = readtype(io, Int32)
    value = readtype(io, Float64)
    unit = readtype(io, String)
    label = readtype(io, String)
    readtype(io, Bool)
    readobjany!(io, tkey, refs)
    endcheck(io, preamble)
    return name, title, bool_attributes, string_attributes, plotmin, plotmax, plotbins, value, unit, label
end

function _read_rooreallvalue(io, tkey, refs)
    preamble = Preamble(io, RooAbsRealLValue)
    name, title, bool_attributes, string_attributes, plotmin, plotmax, plotbins, value, unit, label =
        _read_rooabsreal(io, tkey, refs)
    _skip_versioned_object(io, RooAbsLValue)
    endcheck(io, preamble)
    return name, title, bool_attributes, string_attributes, plotmin, plotmax, plotbins, value, unit, label
end

struct RooPrintable end
struct RooDirItem end
struct RooAbsBinning end
struct RooAbsCollection end
struct RooAbsArg end
struct RooAbsReal end
struct RooAbsRealLValue end
struct RooAbsLValue end
struct RooRefArray end
struct var"TMatrixTBase<double>" end
struct var"RooSTLRefCountList<RooAbsArg>" end
struct var"TVectorT<double>" end
struct var"TMatrixTSym<double>" end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{RooUniformBinning})
    _skip_object(io, RooUniformBinning)
    return missing
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{RooRefArray})
    preamble = Preamble(io, RooRefArray)
    out = unpack(io, tkey, refs, TObjArray)
    endcheck(io, preamble)
    return out
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{RooArgList})
    preamble = Preamble(io, RooArgList)
    out = _read_rooabscollection(io, tkey, refs)
    endcheck(io, preamble)
    return out
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{RooRealVar})
    preamble = Preamble(io, RooRealVar)
    name, title, bool_attributes, string_attributes, plotmin, plotmax, plotbins, value, unit, label =
        _read_rooreallvalue(io, tkey, refs)
    error = readtype(io, Float64)
    asymerrlo = readtype(io, Float64)
    asymerrhi = readtype(io, Float64)
    binning = readobjany!(io, tkey, refs)
    _seek_to_object_end(io, preamble)
    return RooRealVar(
        name,
        title,
        value,
        error,
        asymerrlo,
        asymerrhi,
        plotmin,
        plotmax,
        plotbins,
        unit,
        label,
        bool_attributes,
        string_attributes,
        binning,
    )
end

function _read_tmatrix(io)
    parsefields!(io, Dict{Symbol, Any}(), TObject)
    nrows = Int(readtype(io, Int32))
    ncols = Int(readtype(io, Int32))
    readtype(io, Int32)
    readtype(io, Int32)
    readtype(io, Int32)
    readtype(io, Int32)
    readtype(io, Float64)
    packed = [readtype(io, Float64) for _ in 1:(nrows * (ncols + 1) ÷ 2)]
    out = Matrix{Float64}(undef, nrows, ncols)
    idx = 1
    for i in 1:nrows
        for j in i:ncols
            out[i, j] = packed[idx]
            out[j, i] = packed[idx]
            idx += 1
        end
    end
    return out
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{var"TMatrixTSym<double>"})
    Preamble(io, var"TMatrixTSym<double>")
    return _read_tmatrix(io)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{var"TVectorT<double>"})
    preamble = Preamble(io, var"TVectorT<double>")
    parsefields!(io, Dict{Symbol, Any}(), TObject)
    nrows = readtype(io, UInt32)
    row_lwb = readtype(io, Int32)
    skip(io, 1)
    out = [readtype(io, Float64) for _ in row_lwb+1:nrows]
    _seek_to_object_end(io, preamble)
    return out
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{RooFitResult})
    preamble = Preamble(io, RooFitResult)
    name, title = _read_tnamed(io)
    _skip_versioned_object(io, RooPrintable)
    _skip_versioned_object(io, RooDirItem)
    status = readtype(io, Int32)
    covqual = readtype(io, Int32)
    numbadnll = readtype(io, Int32)
    minnll = readtype(io, Float64)
    edm = readtype(io, Float64)
    constpars = readobjany!(io, tkey, refs)
    initpars = readobjany!(io, tkey, refs)
    finalpars = readobjany!(io, tkey, refs)
    correlation_matrix = readobjany!(io, tkey, refs)
    covariance_matrix = readobjany!(io, tkey, refs)
    global_correlation_coefficients = readobjany!(io, tkey, refs)
    # Status history is part of RooFitResult, but the current fixtures do not
    # expose a stable standalone encoding for it yet, so we defer full support.
    status_history = Pair{String, Int32}[]
    _seek_to_object_end(io, preamble)
    return RooFitResult(
        name,
        title,
        status,
        covqual,
        numbadnll,
        minnll,
        edm,
        constpars,
        initpars,
        finalpars,
        correlation_matrix,
        covariance_matrix,
        global_correlation_coefficients,
        status_history,
    )
end

function RooFitResult(io, tkey::TKey, refs)
    return unpack(datastream(io, tkey), tkey, refs, RooFitResult)
end

function RooRealVar(io, tkey::TKey, refs)
    return unpack(datastream(io, tkey), tkey, refs, RooRealVar)
end

function RooArgList(io, tkey::TKey, refs)
    return unpack(datastream(io, tkey), tkey, refs, RooArgList)
end

function RooUniformBinning(io, tkey::TKey, refs)
    return unpack(datastream(io, tkey), tkey, refs, RooUniformBinning)
end

function var"TVectorT<double>"(io, tkey::TKey, refs)
    return unpack(datastream(io, tkey), tkey, refs, var"TVectorT<double>")
end

function var"TMatrixTSym<double>"(io, tkey::TKey, refs)
    return unpack(datastream(io, tkey), tkey, refs, var"TMatrixTSym<double>")
end
