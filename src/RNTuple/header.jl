Base.@kwdef struct FieldRecord
    field_version::UInt32
    type_version::UInt32
    parent_field_id::UInt32
    struct_role::UInt16
    flags::UInt16
    field_name::String
    type_name::String
    type_alias::String
    field_desc::String
    repetition::Int64
    source_field_id::Int32
    root_streamer_checksum::Int32
end
function _rntuple_read(io, ::Type{FieldRecord})
    field_version = read(io, UInt32)
    type_version = read(io, UInt32)
    parent_field_id = read(io, UInt32)
    struct_role = read(io, UInt16)
    flags = read(io, UInt16)
    field_name, type_name, type_alias, field_desc = (_rntuple_read(io, String) for _=1:4)
    repetition = if !iszero(flags & 0x01)
        read(io, Int64)
    else
        0
    end
    source_field_id = if !iszero(flags & 0x02)
        read(io, Int32)
    else
        -1
    end
    root_streamer_checksum = if !iszero(flags & 0x04)
        read(io, Int32)
    else
        -1
    end
    FieldRecord(;field_version, type_version, parent_field_id, 
                struct_role, flags, field_name, type_name, type_alias, field_desc, repetition, source_field_id, root_streamer_checksum)
end

struct ColumnRecord
    type::UInt16
    nbits::UInt16
    field_id::UInt32
    flags::UInt16
    representation_idx::UInt16
    first_ele_idx::Int64
end
function _rntuple_read(io, ::Type{ColumnRecord})
    type = read(io, UInt16)
    nbits = read(io, UInt16)
    field_id = read(io, UInt32)
    flags = read(io, UInt16)
    first_ele_idx = if !iszero(flags & 0x0008)
        read(io, Int64)
    else
        0
    end
    representation_idx = read(io, UInt16)
    ColumnRecord(type, nbits, field_id, flags, representation_idx, first_ele_idx)
end


@SimpleStruct struct AliasRecord
    physical_id::UInt32
    field_id::UInt32
end

@SimpleStruct struct ExtraTypeInfo
    type_ver_from::UInt32
    type_ver_to::UInt32
    content_identifier::UInt32
    type_name::String
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
