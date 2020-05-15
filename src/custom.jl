# Custom, hardcoded streamers

# KM3NeT

struct KM3NETDAQHit
    dom_id::Int32
    channel_id::UInt8
    tdc::Int32
    tot::UInt8
end

# FIXME write a generic function to determine sizeof structs
# Julia 1.0 not supported (fieldtypes?)
# Base.sizeof(T::{KM3NETDAQHit}) = sum(sizeof.(fieldtypes(T)))
Base.sizeof(T::Type{KM3NETDAQHit}) = 10# Julia 1.0 not supported (fieldtypes?)

function readtype(io::IO, T::Type{KM3NETDAQHit})
    T(readtype(io, Int32), read(io, UInt8), read(io, Int32), read(io, UInt8))
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
