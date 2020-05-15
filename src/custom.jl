# Custom, hardcoded streamers

# KM3NeT

struct KM3NETDAQHit
    dom_id::Int32
    channel_id::UInt8
    tdc::Int32
    tot::UInt8
end
Base.sizeof(T::Type{KM3NETDAQHit}) = 10
function readtype(io::IO, T::Type{KM3NETDAQHit})
    T(readtype(io, Int32), read(io, UInt8), read(io, Int32), read(io, UInt8))
end
# Experimental implementation for maximum performance (using reinterpret)
primitive type DAQHit 80 end
function Base.getproperty(hit::DAQHit, s::Symbol)
    r = Ref(hit)
    GC.@preserve r begin
        if s === :dom_id
            return bswap(unsafe_load(Ptr{Int32}(Base.unsafe_convert(Ptr{Cvoid}, r))))
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
Base.sizeof(T::Type{KM3NETDAQTriggeredHit}) = 24
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

Base.sizeof(T::Type{KM3NETDAQEventHeader}) = 40

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
