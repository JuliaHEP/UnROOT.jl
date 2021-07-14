"""
    splitup(data::Vector{UInt8}, offsets, T::Type; skipbytes=0)

Given the `offsets` and `data` return by `array(...; raw = true)`, reconstructed the actual
array (with custome struct, can be jagged as well).
"""
function splitup(data::Vector{UInt8}, offsets, T::Type; skipbytes=0)
    packedsize = packedsizeof(T)
    out = sizehint!(Vector{Vector{T}}(), length(offsets))
    io = IOBuffer(data)
    for l in diff(offsets)
        skip(io, skipbytes)
        n = (l - skipbytes) / packedsize
        push!(out, [readtype(io, T) for _ in 1:n])
    end
    out
end

# Custom struct interpretation
abstract type CustomROOTStruct end


# TLorentzVector
const LVF64 = LorentzVector{Float64}
Base.show(io::IO, lv::LorentzVector) = print(io, "LV(x=$(lv.x), y=$(lv.y), z=$(lv.z), t=$(lv.t))")
function Base.reinterpret(::Type{LVF64}, v::AbstractVector{UInt8}) where T
    # x,y,z,t in ROOT
    v4 = ntoh.(reinterpret(Float64, v[1+32:end]))
    # t,x,y,z in LorentzVectors.jl
    LVF64(v4[4], v4[1], v4[2], v4[3])
end
function interped_data(rawdata, rawoffsets, ::Type{Vector{LVF64}}, ::Type{Offsetjagg})
    @views map(1:length(rawoffsets)-1) do idx
        idxrange = rawoffsets[idx]+10+1 : rawoffsets[idx+1]
        interped_data(rawdata[idxrange], rawoffsets[idx], LVF64, Nojagg)
    end
end
function interped_data(rawdata, rawoffsets, ::Type{LVF64}, ::Type{J}) where {T, J <: JaggType}
    # even with rawoffsets, we know each TLV is destinied to be 64 bytes
    [
     reinterpret(LVF64, x) for x in Base.Iterators.partition(rawdata, 64)
    ]
end
# TLorentzVector ends

# KM3NeT
struct KM3NETDAQHit <: CustomROOTStruct
    dom_id::Int32
    channel_id::UInt8
    tdc::Int32
    tot::UInt8
end
function readtype(io::IO, T::Type{KM3NETDAQHit})
    T(readtype(io, Int32), read(io, UInt8), read(io, Int32), read(io, UInt8))
end
# Experimental implementation for maximum performance (using reinterpret)
primitive type DAQHit 80 end
function Base.getproperty(hit::DAQHit, s::Symbol)
    r = Ref(hit)
    GC.@preserve r begin
        if s === :dom_id
            return ntoh(unsafe_load(Ptr{Int32}(Base.unsafe_convert(Ptr{Cvoid}, r))))
        elseif s === :channel_id
            return unsafe_load(Ptr{UInt8}(Base.unsafe_convert(Ptr{Cvoid}, r)+4))
        elseif s === :tdc
            return unsafe_load(Ptr{UInt32}(Base.unsafe_convert(Ptr{Cvoid}, r)+5))
        elseif s === :tot
            return unsafe_load(Ptr{UInt8}(Base.unsafe_convert(Ptr{Cvoid}, r)+9))
        end
    end
    error("unknown field $s of type $(typeof(hit))")
end
Base.show(io::IO, h::DAQHit) = print(io, "DAQHit(", h.dom_id, ',', h.channel_id, ',', h.tdc, ',', h.tot, ')')


struct KM3NETDAQTriggeredHit
    dom_id::Int32
    channel_id::UInt8
    tdc::Int32
    tot::UInt8
    trigger_mask::UInt64
end
function readtype(io::IO, T::Type{KM3NETDAQTriggeredHit})
    dom_id = readtype(io, Int32)
    channel_id = read(io, UInt8)
    tdc = read(io, Int32)
    tot = read(io, UInt8)
    skip(io, 6)
    trigger_mask = readtype(io, UInt64)
    T(dom_id, channel_id, tdc, tot, trigger_mask)
end

struct KM3NETDAQEventHeader
    detector_id::Int32
    run::Int32
    frame_index::Int32
    UTC_seconds::UInt32
    UTC_16nanosecondcycles::UInt32
    trigger_counter::UInt64
    trigger_mask::UInt64
    overlays::UInt32
end

function readtype(io::IO, T::Type{KM3NETDAQEventHeader})
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
