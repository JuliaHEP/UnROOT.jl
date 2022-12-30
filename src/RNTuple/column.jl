function read_col_page(io, col_record::ColumnRecord, page::PageDescription)
    nbits = col_record.nbits
    T = rntuple_col_type_dict[col_record.type]
    bytes = read_pagedesc(io, page, nbits)
    reinterpret(T, bytes)
end
