struct FieldRecord
    field_version::UInt32
    type_version::UInt32
    parent_field_id::UInt32
    struct_role::UInt16
    flags::UInt16
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
    field_name, type_name, type_alias, field_desc = (_rntuple_read(io, String) for _=1:4)
    FieldRecord(field_version, type_version, parent_field_id, 
                struct_role, flags, field_name, type_name, type_alias, field_desc)
end

struct ColumnRecord
    type::UInt16
    nbits::UInt16
    field_id::UInt32
    flags::UInt32
end
function _rntuple_read(io, ::Type{ColumnRecord})
    type = read(io, UInt16)
    nbits = read(io, UInt16)
    field_id = read(io, UInt32)
    flags = read(io, UInt32)
    ColumnRecord(type, nbits, field_id, flags)
end

@with_kw struct AliasRecord
    physical_id::UInt32
    field_id::UInt32
end
function _rntuple_read(io, ::Type{AliasRecord})
    physical_id = read(io, UInt32)
    field_id = read(io, UInt32)
    ColumnRecord(; physical_id, field_id)
end

@with_kw struct ExtraTypeInfo
    type_ver_from::UInt32
    type_ver_to::UInt32
    content_identifier::UInt32
end
function _rntuple_read(io, ::Type{ExtraTypeInfo})
    type_ver_from = read(io, UInt32)
    type_ver_to = read(io, UInt32)
    content_identifier = read(io, UInt32)
    ColumnRecord(; type_ver_from, type_ver_to, content_identifier)
end

@with_kw struct RNTupleHeader
    feature_flag::UInt64
    rc_tag::UInt32
    name::String
    ntuple_description::String
    writer_identifier::String
    field_records::Vector{FieldRecord}
    column_records::Vector{ColumnRecord}
    alias_columns::Vector{AliasRecord}
    extra_type_infos::Vector{ExtraTypeInfo}
end
function _rntuple_read(io, ::Type{RNTupleHeader})
    feature_flag = read(io, UInt64)
    rc_tag = read(io, UInt32)
    name, ntuple_description, writer_identifier = (_rntuple_read(io, String) for _=1:3)
    field_records = _rntuple_read(io, RNTupleListFrame{FieldRecord})
    column_records = _rntuple_read(io, RNTupleListFrame{ColumnRecord})
    alias_columns = _rntuple_read(io, RNTupleListFrame{AliasRecord})
    extra_type_infos = _rntuple_read(io, RNTupleListFrame{ExtraTypeInfo})
    RNTupleHeader(; feature_flag, rc_tag, name, ntuple_description, 
                  writer_identifier, field_records, column_records, alias_columns, extra_type_infos)
end
