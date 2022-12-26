"""
    RNTuple

This is the struct for holding all metadata (schema) needed to completely describe
and RNTuple from ROOT, just like `TTree`, to obtain a table-like data object, you need
to use `LazyTree` explicitly.
"""
struct RNTuple
    header::RNTupleEnvelope{RNTupleHeader}
    footer::RNTupleEnvelope{RNTupleFooter}
end

function ROOT_3a3a_Experimental_3a3a_RNTuple(io, tkey::TKey, refs)
    local_io = datastream(io, tkey)
    skip(local_io, 6)
    anchor = ROOT_3a3a_Experimental_3a3a_RNTuple(
                    fCheckSum = readtype(local_io, Int32),
                    fVersion = readtype(local_io, UInt32),
                    fSize = readtype(local_io, UInt32),
                    fSeekHeader = readtype(local_io, UInt64),
                    fNBytesHeader = readtype(local_io, UInt32),
                    fLenHeader = readtype(local_io, UInt32),
                    fSeekFooter = readtype(local_io, UInt64),
                    fNBytesFooter = readtype(local_io, UInt32),
                    fLenFooter = readtype(local_io, UInt32),
                    fReserved = readtype(local_io, UInt64),
                                       )
    header_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekHeader, anchor.fNBytesHeader), anchor.fLenHeader)
    header_io = IOBuffer(header_bytes)
    header = _rntuple_read(header_io, RNTupleEnvelope{RNTupleHeader})

    footer_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekFooter, anchor.fNBytesFooter), anchor.fLenFooter)
    footer_io = IOBuffer(footer_bytes)
    footer = _rntuple_read(footer_io, RNTupleEnvelope{RNTupleFooter})
    rnt = RNTuple(header, footer)
    @assert header.crc32 == footer.payload.header_crc32

    return rnt
end
