struct ROOTDirectory
    name::AbstractString
    header::ROOTDirectoryHeader
    keys::Vector{TKey}
end

struct ROOTFile
    format_version::Int32
    header::FileHeader
    fobj::IOStream
    tkey::TKey
    streamer_key::TKey
    directory::ROOTDirectory
end


function ROOTFile(filename::AbstractString)
    fobj = Base.open(filename)
    preamble = unpack(fobj, FilePreamble)
    String(preamble.identifier) == "root" || error("Not a ROOT file!")
    format_version = preamble.fVersion

    if format_version < 1000000
        header = unpack(fobj, FileHeader32)
    else
        header = unpack(fobj, FileHeader64)
    end

    # Streamers
    if header.fSeekInfo != 0
        seek(fobj, header.fSeekInfo)
        streamer_key = unpack(fobj, TKey)
        refs, tlist = read_streamers(fobj, streamer_key)
    end

    seek(fobj, header.fBEGIN)
    tkey = unpack(fobj, TKey)

    # Reading the header key for the top ROOT directory
    seek(fobj, header.fBEGIN + header.fNbytesName)
    dir_header = unpack(fobj, ROOTDirectoryHeader)
    if dir_header.fSeekKeys == 0
        ROOTFile(format_version, header, fobj, tkey, [])
    end

    seek(fobj, dir_header.fSeekKeys)
    header_key = unpack(fobj, TKey)

    n_keys = readtype(fobj, Int32)
    keys = [unpack(fobj, TKey) for _ in 1:n_keys]

    directory = ROOTDirectory(tkey.fName, dir_header, keys)

    ROOTFile(format_version, header, fobj, tkey, streamer_key, directory)
end

function Base.getindex(f::ROOTFile, s::AbstractString)
    f.directory.keys[findfirst(isequal(s), keys(f))]
end


function Base.keys(f::ROOTFile)
    keys(f.directory)
end

function Base.keys(d::ROOTDirectory)
    [key.fName for key in d.keys]
end


function Base.get(f::ROOTFile, k::TKey)
end
