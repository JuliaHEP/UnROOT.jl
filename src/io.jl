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
   quote
       $(esc(data))
       $(@__MODULE__).unpack(io, ::Type{$(esc(struct_name))}) = $(esc(struct_name))($([:(ntoh(read(io, $(esc(t))))) for t in types]...))
       nothing
   end
end
