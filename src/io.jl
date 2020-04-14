function unpack() end

struct ROOTString
    value::AbstractString
end

readtype(io, ::Type{T}) where T<:Union{Integer, AbstractFloat} = ntoh(read(io, T))
readtype(io, ::Type{T}) where T<:AbstractVector{UInt8} = read(io, sizeof(T))

function readtype(io, ::Type{ROOTString})
    start = position(io)
    length = readtype(io, UInt8)

    if length == 255
        seek(io, start)
        length = readtype(io, UInt32)
    end

    ROOTString(String(read(io, length)))
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

    struct_size = sum([sizeof(eval(t)) for t in types])

    quote
        $(esc(data))  # executing the code to create the actual struct
        Base.sizeof(::Type{$(esc(struct_name))}) = $struct_size

        function $(@__MODULE__).unpack(io, ::Type{$(esc(struct_name))})
            $(esc(struct_name))($([:(readtype(io, $t)) for t in types]...))
        end

        nothing  # supress REPL output
    end
end
