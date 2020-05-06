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
