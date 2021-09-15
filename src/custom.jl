"""
    splitup(data::Vector{UInt8}, offsets, T::Type; skipbytes=0)

Given the `offsets` and `data` return by `array(...; raw = true)`, reconstructed the actual
array (with custome struct, can be jagged as well).
"""
function splitup(data::Vector{UInt8}, offsets, T::Type; skipbytes=0, jagged=true)
    packedsize = packedsizeof(T)

    if jagged
        out = Vector{Vector{T}}()
    else
        out = Vector{T}()
    end
    sizehint!(out, length(offsets))

    io = IOBuffer(data)
    for l in diff(offsets)
        skip(io, skipbytes)
        if jagged
            n = (l - skipbytes) / packedsize
            push!(out, [readtype(io, T) for _ in 1:n])
        else
            # n != 1 && warning("The packed size of the entry does not match the data size.")
            push!(out, readtype(io, T))
        end
    end
    out
end

# Custom struct interpretation
abstract type CustomROOTStruct end


# TLorentzVector
const LVF64 = LorentzVector{Float64}
Base.show(io::IO, lv::LorentzVector) = print(io, "LV(x=$(lv.x), y=$(lv.y), z=$(lv.z), t=$(lv.t))")
function Base.reinterpret(::Type{LVF64}, v::AbstractVector{UInt8}) where T
    # first 32 bytes are TObject header we don't care
    # x,y,z,t in ROOT
    v4 = ntoh.(reinterpret(Float64, @view v[1+32:end]))
    # t,x,y,z in LorentzVectors.jl
    LVF64(v4[4], v4[1], v4[2], v4[3])
end

"""
    interped_data(rawdata, rawoffsets, ::Type{Vector{LorentzVector{Float64}}}, ::Type{Offsetjagg})

The `interped_data` method specialized for `LorentzVector`. This method will get called by
[`basketarray`](@ref) instead of the default method for `TLorentzVector` branch.
"""
function interped_data(rawdata, rawoffsets, ::Type{Vector{LVF64}}, ::Type{Offsetjagg})
    _size = 64 # needs to account for 32 bytes header
    dp = 0 # book keeping for copy_to!
    lr = length(rawoffsets)
    offset = Vector{Int32}(undef, lr)
    offset[1] = 0
    @views @inbounds for i in 1:lr-1
        start = rawoffsets[i]+10+1
        stop = rawoffsets[i+1]
        l = stop-start+1
        if l > 0
            unsafe_copyto!(rawdata, dp+1, rawdata, start, l)
            dp += l
            offset[i+1] = offset[i] + l
        else
            offset[i+1] = offset[i]
        end
    end
    resize!(rawdata, dp)
    real_data = interped_data(rawdata, offset, LVF64, Nojagg)
    offset .÷= _size
    offset .+= 1
    VectorOfVectors(real_data, offset)
end
function interped_data(rawdata, rawoffsets, ::Type{LVF64}, ::Type{J}) where {T, J <: JaggType}
    # even with rawoffsets, we know each TLV is destinied to be 64 bytes
    [
     reinterpret(LVF64, x) for x in Base.Iterators.partition(rawdata, 64)
    ]
end
# TLorentzVector ends

# KM3NeT
struct _KM3NETDAQHit <: CustomROOTStruct
    dom_id::Int32
    channel_id::UInt8
    tdc::Int32
    tot::UInt8
end
function readtype(io::IO, T::Type{_KM3NETDAQHit})
    T(readtype(io, Int32), read(io, UInt8), read(io, Int32), read(io, UInt8))
end
function interped_data(rawdata, rawoffsets, ::Type{Vector{_KM3NETDAQHit}}, ::Type{J}) where {T, J <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, _KM3NETDAQHit, skipbytes=10)
end


struct _KM3NETDAQTriggeredHit
    dom_id::Int32
    channel_id::UInt8
    tdc::Int32
    tot::UInt8
    trigger_mask::UInt64
end
function readtype(io::IO, T::Type{_KM3NETDAQTriggeredHit})
    dom_id = readtype(io, Int32)
    channel_id = read(io, UInt8)
    tdc = read(io, Int32)
    tot = read(io, UInt8)
    skip(io, 6)
    trigger_mask = readtype(io, UInt64)
    T(dom_id, channel_id, tdc, tot, trigger_mask)
end

function UnROOT.interped_data(rawdata, rawoffsets, ::Type{Vector{_KM3NETDAQTriggeredHit}}, ::Type{J}) where {T, J <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, _KM3NETDAQTriggeredHit, skipbytes=10)
end

struct _KM3NETDAQEventHeader
    detector_id::Int32
    run::Int32
    frame_index::Int32
    UTC_seconds::UInt32
    UTC_16nanosecondcycles::UInt32
    trigger_counter::UInt64
    trigger_mask::UInt64
    overlays::UInt32
end
packedsizeof(::Type{_KM3NETDAQEventHeader}) = 76

function readtype(io::IO, T::Type{_KM3NETDAQEventHeader})
    skip(io, 18)
    detector_id = readtype(io, Int32)
    run = readtype(io, Int32)
    frame_index = readtype(io, Int32)
    skip(io, 6)
    UTC_seconds = readtype(io, UInt32)
    UTC_16nanosecondcycles = readtype(io, UInt32)
    skip(io, 6)
    trigger_counter = readtype(io, UInt64)
    skip(io, 6)
    trigger_mask = readtype(io, UInt64)
    overlays = readtype(io, UInt32)
    T(detector_id, run, frame_index, UTC_seconds, UTC_16nanosecondcycles, trigger_counter, trigger_mask, overlays)
end

function UnROOT.interped_data(rawdata, rawoffsets, ::Type{_KM3NETDAQEventHeader}, ::Type{J}) where {T, J <: UnROOT.JaggType}
    UnROOT.splitup(rawdata, rawoffsets, _KM3NETDAQEventHeader, jagged=false)
end
