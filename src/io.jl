function unpack() end

macro io(data)
   struct_name = data.args[2]

   types = []
   for f in data.args[3].args
       isa(f, LineNumberNode) && continue
       isa(f, Symbol) && error("Untyped field")
       Meta.isexpr(f, :(::)) || error("")
       push!(types, f.args[2])
   end

   struct_size = 0
   parsers = []
   for t in types
       type_ = eval(t)
       if type_ <: Union{Integer, AbstractFloat}
           push!(parsers, :(ntoh(read(io, $t))))
       elseif type_ <: AbstractVector{UInt8}
           push!(parsers, :(read(io, sizeof($t))))
       else
           error("No parser found for type $t")
       end
       struct_size += sizeof(type_)
   end


   quote
       $(esc(data))  # executing the code to create the actual struct
       Base.sizeof(::Type{$(esc(struct_name))}) = $struct_size

       function $(@__MODULE__).unpack(io, ::Type{$(esc(struct_name))})
           $(esc(struct_name))($(parsers...))
       end

       nothing  # supress REPL output
   end
end
