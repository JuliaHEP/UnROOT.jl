module Debug

import ..UnROOT: ROOTFile, streamerfor

function streamerdiff(f1::ROOTFile, f2::ROOTFile, classname::AbstractString)
  sinfo1 = streamerfor(f1, classname)
  sinfo2 = streamerfor(f2, classname)

  println("==========")
  println("A: class version $(sinfo1.streamer.fClassVersion) (checksum: $(sinfo1.streamer.fCheckSum))")
  println("B: class version $(sinfo2.streamer.fClassVersion) (checksum: $(sinfo2.streamer.fCheckSum))")
  println()

  deps1 = sinfo1.dependencies
  deps2 = sinfo2.dependencies

  common_deps = union(deps1, deps2)
  println("Common dependencies: " * join(common_deps, ", "))

  streamers1 = copy(sinfo1.streamer.fElements.elements)
  streamers2 = copy(sinfo2.streamer.fElements.elements)

  while length(streamers1) > 0 && length(streamers2) > 0
    s1 = popfirst!(streamers1)
    s2 = popfirst!(streamers2)
    println("--------------")
    println("A: $(s1.fName)")
    println("B: $(s2.fName)")
    if s1 != s2
      fields1 = collect(fieldnames(typeof(s1)))
      fields2 = collect(fieldnames(typeof(s2)))
      while length(fields1) > 0 && length(fields2) > 0
          f1 = popfirst!(fields1)
          f2 = popfirst!(fields2)
          if f1 != f2
              println("Mismatch of fields: $f1 - $f2")
              break
          end
          v1 = getfield(s1, f1)
          v2 = getfield(s2, f2)
          if v1 != v2
              println("Mismatch of field values in $f1:")
              println("    A: $v1")
              println("    B: $v2")
          end
      end
    end
  end
  if length(streamers1) > 0
    println("\nMissing in B: " * join([s.fName for s in streamers1], ", "))
  end
  if length(streamers2) > 0
    println("\nMissing in A: " * join([s.fName for s in streamers2], ", "))
  end
end

end
