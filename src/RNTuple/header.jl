struct FieldRecord
    field_version::UInt32
    type_version::UInt32
    parent_field_id::UInt32
    struct_role::UInt16
    flags::UInt16
    repetition::Int64
    field_name::String
    type_name::String
    type_alias::String
    field_desc::String
end
function _rntuple_read(io, ::Type{FieldRecord})
    field_version = read(io, UInt32)
    type_version = read(io, UInt32)
    parent_field_id = read(io, UInt32)
    struct_role = read(io, UInt16)
    flags = read(io, UInt16)
    repetition = if flags == 0x0001
        read(io, Int64)
    else
        0
    end
    field_name, type_name, type_alias, field_desc = (_rntuple_read(io, String) for _=1:4)
    FieldRecord(field_version, type_version, parent_field_id, 
                struct_role, flags, repetition, field_name, type_name, type_alias, field_desc)
end

@SimpleStruct struct ColumnRecord
    type::UInt16
    nbits::UInt16
    field_id::UInt32
    flags::UInt32
end

@SimpleStruct struct AliasRecord
    physical_id::UInt32
    field_id::UInt32
end

@SimpleStruct struct ExtraTypeInfo
    type_ver_from::UInt32
    type_ver_to::UInt32
    content_identifier::UInt32
end

@SimpleStruct struct RNTupleHeader
    feature_flag::UInt64
    name::String
    ntuple_description::String
    writer_identifier::String
    field_records::Vector{FieldRecord}
    column_records::Vector{ColumnRecord}
    alias_columns::Vector{AliasRecord}
    extra_type_infos::Vector{ExtraTypeInfo}
end
