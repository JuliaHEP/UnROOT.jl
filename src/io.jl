struct Cursor
    start
    io
    tkey
    refs
end

Base.position(c::Cursor) = position(c.io)


function unpack() end

@inline readtype(io, ::Type{T}) where T<:Union{Integer, AbstractFloat} = ntoh(read(io, T))
@inline readtype(io, ::Type{T}) where T<:Bool = read(io, T)
@inline readtype(io, ::Type{T}) where T<:AbstractVector{UInt8} = read(io, sizeof(T))

function readtype(io, ::Type{T}) where T<:AbstractString
    start = position(io)
    length = readtype(io, UInt8)

    if length == 255
        seek(io, start)
        length = readtype(io, UInt32)
    end

    T(read(io, length))
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
    parametric_types = []
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

        nothing  # supress REPL output
    end
end


struct Preamble
    start
    cnt
    version::Int64
    type::Type
end

"""
Reads the preamble of an object.

The cursor will be put into the right place depending on the data.
"""
function Preamble(io, ::Type{T}) where {T}
    # FIXME dirty hack
    if typeof(io) <: Cursor
        io = io.io
    end
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


"""
    function skiptobj(io)

Skips a TOBject.
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

Checks if everything went well after parsing a TOBject. Used in conjuction
with `Preamble`.
"""
function endcheck(io, preamble::T) where {T<:Preamble}
    if !ismissing(preamble.cnt)
        observed = position(io) - preamble.start
        if observed != preamble.cnt
            error("Object '$(preamble.type)' has $(observed) bytes; expected $(preamble.cnt)")
        end
    end
    return true
end


function nametitle(io)
    preamble = Preamble(io, Missing)
    skiptobj(io)
    name = readtype(io, String)
    title = readtype(io, String)
    endcheck(io, preamble)
    name, title
end
