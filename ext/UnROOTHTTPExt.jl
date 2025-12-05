module UnROOTHTTPExt

import UnROOT: AbstractSourceStream, read_seek_nb
import HTTP

mutable struct HTTPStream <: AbstractSourceStream
    uri::HTTP.URI
    seekloc::Int
    size::Int
    multipart::Bool
    scitoken::String
    function HTTPStream(uri::AbstractString; scitoken = _find_scitoken())
        #TODO: determine multipart support
        test = HTTP.request("GET", uri,
        ("Range" => "bytes=0-3", "User-Agent" => "UnROOTjl", "Authorization" => "Bearer $scitoken")
        )
        @assert test.status==206 "bad network or wrong server"
        @assert String(test.body)=="root" "not a root file"
        multipart = false
        local v
        for pair in test.headers
            if lowercase(pair[1]) == "content-range"
                v = pair[2]
                break
            end
        end
        size = parse(Int, match(r"/(\d+)", v).captures[1])
        new(HTTP.URI(uri), 0, size, multipart, scitoken)
    end
end

function Base.close(fobj::HTTPStream) # no-op
    nothing
end

function Base.read(fobj::HTTPStream, nb::Integer)
    @debug nb
    b = read_seek_nb(fobj, fobj.seekloc, nb)
    fobj.seekloc += nb
    return b
end

function read_seek_nb(fobj::HTTPStream, seek, nb)
    stop = seek+nb-1
    stop = min(fobj.size-1, stop)
    hd = ("Range" => "bytes=$(seek)-$stop", "Authorization" => "Bearer $(fobj.scitoken)")
    b = HTTP.request(HTTP.stack(), "GET", fobj.uri, hd, UInt8[]).body
    return b
end

end
