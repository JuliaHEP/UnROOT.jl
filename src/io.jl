"""
The `Cursor` type is embedded into Branches of a TTree such that when
we need to read the content of a Branch, we don't need to go through
the Directory and find the TKey and then seek to where the Branch is.

!!! note
    The `io` inside a `Cursor` is in fact only a buffer, it is NOT
    a `io` that refers to the whole file's stream.
"""
struct Cursor
    start::Int64
    io::IO
    tkey
    refs::Dict{Int32, Any}
end

Base.position(c::Cursor) = position(c.io)


function unpack() end
packedsizeof(T::Type) = sum(sizeof.(fieldtypes(T)))

@inline readtype(io, ::Type{T}) where T<:Union{Integer, AbstractFloat} = ntoh(read(io, T))
@inline readtype(io, ::Type{T}) where T<:Bool = read(io, T)
@inline readtype(io, v::Type{T}) where T<:AbstractVector{UInt8} = read(io, length(v))

# Non-C strings in .root are proceeded by 1 or more bytes signifying the length
# of the string that follows.
function readtype(io, ::Type{T}) where T<:AbstractString
    length = readtype(io, UInt8)

    if length == 255
        # first byte 0xff is useless now
        # https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/source/cursor.py#L91
        length = readtype(io, UInt32)
    end

    T(read(io, Int(length)))
end

struct CString
    value::String
end

function readtype(io, ::Type{T}) where {T<:CString}
    out = Char[]
    char = read(io, Char)
    while char != '\0'
        push!(out, char)
        char = read(io, Char)
    end
    String(out)
end


macro io(data)
    struct_name = data.args[2]
    types = []
    for f in data.args[3].args
        isa(f, LineNumberNode) && continue
        isa(f, Symbol) && error("Untyped field")
        Meta.isexpr(f, :(::)) || error("")
        push!(types, f.args[2])
    end

    # TODO: Need to figure out how to deal with Strings, probably dynamically
    # create the sizes instead of defining it just based on sizeof.
    # struct_size = sum([sizeof(eval(t)) for t in types])

    quote
        $(esc(data))  # executing the code to create the actual struct
        # Base.sizeof(::Type{$(esc(struct_name))}) = $struct_size

        function $(@__MODULE__).unpack(io, ::Type{T}) where {T<:$(esc(struct_name))}
            $(esc(struct_name))($([:(readtype(io, $t)) for t in types]...))
        end

        nothing  # suppress REPL output
    end
end


struct Preamble
    start::Int64
    cnt::Union{UInt32, Missing}
    version::UInt16
    type::Type
end

"""
Reads the preamble of an object.

The cursor will be put into the right place depending on the data.
"""
function Preamble(io, ::Type{T}) where {T}
    start = position(io)
    cnt = readtype(io, UInt32)
    version = readtype(io, UInt16)
    if Int64(cnt) & Const.kByteCountMask > 0
        cnt = Int64(cnt) & ~Const.kByteCountMask
        return Preamble(start, cnt + 4, version, T)
    else
        seek(io, start)
        version = readtype(io, UInt16)
        return Preamble(start, missing, version, T)
    end
end

function Preamble(io::Cursor, ::Type{T}) where {T}
    Preamble(io.io, T)
end

"""
    function skiptobj(io)

Skips a TObject.
"""
function skiptobj(io)
    version = readtype(io, Int16)
    if Int64(version) & Const.kByteCountMask > 0
        skip(io, 4)
    end
    fUniqueID = readtype(io, UInt32)
    fBits = readtype(io, UInt32)
    if fBits & Const.kIsReferenced > 0
        skip(io, 2)
    end
end

"""
    function endcheck(io, preamble::Preamble)

Checks if everything went well after parsing a TObject. Used in conjunction
with `Preamble`.
"""
function endcheck(io, preamble::T) where {T<:Preamble}
    if !ismissing(preamble.cnt)
        observed = position(io) - preamble.start
        if observed != preamble.cnt
            error("Object '$(preamble.type)' has $(observed) bytes; expected $(preamble.cnt)")
        end
    end
    nothing
end


function nametitle(io)
    preamble = Preamble(io, Missing)
    skiptobj(io)
    name = readtype(io, String)
    title = readtype(io, String)
    endcheck(io, preamble)
    name, title
end
