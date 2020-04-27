"""
    macro stack(into, structs...)

Stack the fields of multiple structs and create a new one.
The first argument is the name of the new struct followed by the
ones to be stacked. Parametric types are not supported and
the fieldnames needs to be unique.

Example:

    @stack Baz Foo Bar

Creates `Baz` with the concatenated fields of `Foo` and `Bar`

"""
macro stack(into, structs...)
    fields = []
    for _struct in structs
        names = fieldnames(getfield(__module__, _struct))
        types = [fieldtype(getfield(__module__, _struct), field) for field in names]
        for (n, t) in zip(names, types)
            push!(fields, :($n::$t))
        end
    end

    esc(
        quote
            struct $into
                $(fields...)
            end
        end
    )
end
