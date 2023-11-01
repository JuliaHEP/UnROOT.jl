@io struct TKey32
    fNbytes::Int32
    fVersion::Int16
    fObjlen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey::Int32
    fSeekPdir::Int32
    fClassName::String
    fName::String
    fTitle::String
end

@io struct TKey64
    fNbytes::Int32
    fVersion::Int16
    fObjlen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey::Int64
    fSeekPdir::Int64
    fClassName::String
    fName::String
    fTitle::String
end

const TKey = Union{TKey32, TKey64}

function unpack(io, ::Type{TKey})
    start = position(io)
    skip(io, 4)
    fVersion = readtype(io, Int16)
    seek(io, start)
    if fVersion <= 1000
        return unpack(io, TKey32)
    end
    unpack(io, TKey64)
end

@with_kw struct TBasketKey
    fNbytes::Int32
    fVersion::Int16
    fObjlen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey::Int64
    fSeekPdir::Int64
    fClassName::String
    fName::String
    fTitle::String
    fBufferSize::Int32
    fNevBufSize::Int32
    fNevBuf::Int32
    fLast::Int32
end

function unpack(io, T::Type{TBasketKey})
    start = position(io)

    fNbytes = readtype(io, Int32)
    fVersion = readtype(io, Int16)  # FIXME if "complete" it's UInt16 (acc. uproot)

    inttype = fVersion <= 1000 ? Int32 : Int64

    fObjlen = readtype(io, Int32)
    fDatime = readtype(io, UInt32)
    fKeylen = readtype(io, Int16)

    # do a single read to get rest of bytes into memory
    # and offset by the 16 bytes we already read
    io = IOBuffer(read(io, fKeylen - 16))
    start = -16

    fCycle = readtype(io, Int16)
    fSeekKey = readtype(io, inttype)
    fSeekPdir = readtype(io, inttype)
    fClassName = readtype(io, String)
    fName = readtype(io, String)
    fTitle = readtype(io, String)

    # if complete (which is true for compressed, it seems?)
    seek(io, start + fKeylen - 18 - 1)
    fVersion = readtype(io, Int16)  # FIXME if "complete" it's UInt16 (acc. uproot)
    fBufferSize = readtype(io, Int32)
    fNevBufSize = readtype(io, Int32)
    fNevBuf = readtype(io, Int32)
    fLast = readtype(io, Int32)

    T(
      fNbytes,
      fVersion,
      fObjlen,
      fDatime,
      fKeylen,
      fCycle,
      fSeekKey,
      fSeekPdir,
      fClassName,
      fName,
      fTitle,
      fBufferSize,
      fNevBufSize,
      fNevBuf,
      fLast,
   )
end

iscompressed(t::T) where T<:Union{TKey, TBasketKey} = t.fObjlen != t.fNbytes - t.fKeylen
origin(t::T) where T<:Union{TKey, TBasketKey} = iscompressed(t) ? -t.fKeylen : t.fSeekKey
seekstart(io, t::T) where T<:Union{TKey, TBasketKey} = seek(io, t.fSeekKey + t.fKeylen)

datastream(io, tkey::TKey) = IOBuffer(decompress_datastreambytes(compressed_datastream(io, tkey), tkey))

"""
    compressed_datastream(io, tkey)

Extract all [compressionheader][rawbytes] from a `TKey`. This is an isolated function
because we want to compartmentalize disk I/O as much as possible.

See also: [`decompress_datastreambytes`](@ref)
"""
function compressed_datastream(io, tkey)
    seekstart(io, tkey)
    return read(io, tkey.fNbytes - tkey.fKeylen)
end

function _decompress_lz4!(input_ptr, input_size, output_ptr, output_size)
    CodecLz4.LZ4_decompress_safe(input_ptr, output_ptr, input_size, output_size)
    nothing
end

"""
    decompress_datastreambytes(compbytes, tkey)

Process the compressed bytes `compbytes` which was read out by `compressed_datastream` and
pointed to from `tkey`. This function simply return uncompressed bytes according to
the compression algorithm detected (or the lack of).
"""
function decompress_datastreambytes(compbytes, tkey)
    # not compressed
    iscompressed(tkey) || return compbytes

    # compressed
    io = IOBuffer(compbytes)
    fulfilled = 0
    uncomp_data = Vector{UInt8}(undef, tkey.fObjlen)
    while fulfilled < tkey.fObjlen # careful with 0/1-based index when thinking about offsets
        compression_header = unpack(io, CompressionHeader)
        cname, _, compbytes, uncompbytes = unpack(compression_header)
        rawbytes = read(io, compbytes)
        @debug "Compression type: $(cname)"
        @debug "Compressed/uncompressed size in bytes: $(compbytes) / $(uncompbytes)"

        if cname == "L4"
            # skip checksum which is 8 bytes
            # original: lz4_decompress(rawbytes[9:end], uncompbytes)
            input = @view rawbytes[9:end]
            input_ptr = pointer(input)
            input_size = length(input)
            output_ptr = pointer(uncomp_data) + fulfilled
            output_size = uncompbytes
            _decompress_lz4!(input_ptr, input_size, output_ptr, output_size)
        elseif cname == "ZL"
            output = @view(uncomp_data[fulfilled+1:fufilled+uncompbytes])
            zlib_decompress!(Decompressor(), output, rawbytes, uncompbytes)
        elseif cname == "XZ"
            @view(uncomp_data[fulfilled+1:fufilled+uncompbytes]) .= transcode(XzDecompressor, rawbytes)
        elseif cname == "ZS"
            @view(uncomp_data[fulfilled+1:fufilled+uncompbytes]) .= transcode(ZstdDecompressor, rawbytes)
        else
            error("Unsupported compression type '$(String(compression_header.algo))'")
        end

        fulfilled += uncompbytes
    end
    return uncomp_data
end
@io struct FilePreamble
    identifier::SVector{4, UInt8}  # Root file identifier ("root")
    fVersion::Int32                # File format version
end

# https://root.cern/doc/v624/RMiniFile_8cxx_source.html#l00239
@io struct FileHeader32
    fBEGIN::Int32                  # Pointer to first data record
    fEND::UInt32                   # Pointer to first free word at the EOF
    fSeekFree::UInt32              # Pointer to FREE data record
    fNbytesFree::Int32             # Number of bytes in FREE data record
    nfree::Int32                   # Number of free data records
    fNbytesName::Int32             # Number of bytes in TNamed at creation time
    fUnits::UInt8                  # Number of bytes for file pointers
    fCompress::Int32               # Compression level and algorithm
    fSeekInfo::UInt32              # Pointer to TStreamerInfo record
    fNbytesInfo::Int32             # Number of bytes in TStreamerInfo record
    fUUID::SVector{18, UInt8}      # Universal Unique ID
end


@io struct FileHeader64
    fBEGIN::Int32                  # Pointer to first data record
    fEND::UInt64                   # Pointer to first free word at the EOF
    fSeekFree::UInt64              # Pointer to FREE data record
    fNbytesFree::Int32             # Number of bytes in FREE data record
    nfree::Int32                   # Number of free data records
    fNbytesName::Int32             # Number of bytes in TNamed at creation time
    fUnits::UInt8                  # Number of bytes for file pointers
    fCompress::Int32               # Compression level and algorithm
    fSeekInfo::UInt64              # Pointer to TStreamerInfo record
    fNbytesInfo::Int32             # Number of bytes in TStreamerInfo record
    fUUID::SVector{18, UInt8}      # Universal Unique ID
end

const FileHeader = Union{FileHeader32, FileHeader64}


@io struct ROOTDirectoryHeader32
    fVersion::Int16
    fDatimeC::UInt32
    fDatimeM::UInt32
    fNbytesKeys::Int32
    fNbytesName::Int32
    fSeekDir::Int32
    fSeekParent::Int32
    fSeekKeys::Int32
end

@io struct ROOTDirectoryHeader64
    fVersion::Int16
    fDatimeC::UInt32
    fDatimeM::UInt32
    fNbytesKeys::Int32
    fNbytesName::Int32
    fSeekDir::Int64
    fSeekParent::Int64
    fSeekKeys::Int64
end

const ROOTDirectoryHeader = Union{ROOTDirectoryHeader32, ROOTDirectoryHeader64}

function unpack(io, ::Type{ROOTDirectoryHeader})
    fVersion = readtype(io, Int16)
    skip(io, -2)

    if fVersion <= 1000
        return unpack(io, ROOTDirectoryHeader32)
    else
        return unpack(io, ROOTDirectoryHeader64)
    end

end


@io struct CompressionHeader
    algo::SVector{2, UInt8}
    method::UInt8
    c1::UInt8
    c2::UInt8
    c3::UInt8
    u1::UInt8
    u2::UInt8
    u3::UInt8
end


# Built-in types
# function THashList end
function TRef end
function TArray end
function TArrayC end
function TArrayS end
function TArrayL end
function TArrayL64 end
function TRefArray end

function aliasfor(classname)
    if classname == "ROOT::TIOFeatures"
        return ROOT_3a3a_TIOFeatures
    else
        nothing
    end
end
