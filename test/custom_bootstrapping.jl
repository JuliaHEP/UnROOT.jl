using Test
using UnROOT


@testset "custom bootstrapping" begin
    # manual interpretation (splitting)
    f_manual = UnROOT.samplefile("km3net_online.root")

    data, offsets = UnROOT.array(f_manual, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"; raw=true)
    headers_manual = UnROOT.splitup(data, offsets, UnROOT._KM3NETDAQEventHeader; jagged=false)

    data, offsets = UnROOT.array(f_manual, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
    event_hits_manual = UnROOT.splitup(data, offsets, UnROOT._KM3NETDAQHit; skipbytes=10)

    data, offsets = UnROOT.array(f_manual, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits"; raw=true)
    event_thits_manual = UnROOT.splitup(data, offsets, UnROOT._KM3NETDAQTriggeredHit; skipbytes=10)

    close(f_manual)  # we can close, everything is in memory

    # automatic interpretation
    customstructs = Dict(
            "KM3NETDAQ::JDAQEvent.snapshotHits" => Vector{UnROOT._KM3NETDAQHit},
            "KM3NETDAQ::JDAQEvent.triggeredHits" => Vector{UnROOT._KM3NETDAQTriggeredHit},
            "KM3NETDAQ::JDAQEvent.KM3NETDAQ::JDAQEventHeader" => UnROOT._KM3NETDAQEventHeader
    )
    f_auto = UnROOT.samplefile("km3net_online.root"; customstructs=customstructs)
    headers_auto = LazyBranch(f_auto, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader")
    event_hits_auto = LazyBranch(f_auto, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits")
    event_thits_auto = LazyBranch(f_auto, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits")

    for event_hits ∈ [event_hits_manual, event_hits_auto]
        @test length(event_hits) == 3
        @test length(event_hits[1]) == 96
        @test length(event_hits[2]) == 124
        @test length(event_hits[3]) == 78
        @test event_hits[1][1].dom_id == 806451572
        @test event_hits[1][1].tdc == 30733918
        @test event_hits[1][end].dom_id == 809544061
        @test event_hits[1][end].tdc == 30735112
        @test event_hits[3][1].dom_id == 806451572
        @test event_hits[3][1].tdc == 63512204
        @test event_hits[3][end].dom_id == 809544061
        @test event_hits[3][end].tdc == 63512892
    end
    for event_thits ∈ [event_thits_manual, event_thits_auto]
        @test length(event_thits) == 3
        @test length(event_thits[1]) == 18
        @test length(event_thits[2]) == 53
        @test length(event_thits[3]) == 9
        @test event_thits[1][1].dom_id == 806451572
        @test event_thits[1][1].tdc == 30733918
        @test event_thits[1][end].dom_id == 808972598
        @test event_thits[1][end].tdc == 30733192
        @test event_thits[3][1].dom_id == 808447186
        @test event_thits[3][1].tdc == 63511558
        @test event_thits[3][end].dom_id == 809526097
        @test event_thits[3][end].tdc == 63511708
    end

    for headers ∈ [headers_manual, headers_auto]
        @test length(headers) == 3
        for header in headers
            @test header.run == 6633
            @test header.detector_id == 44
            @test header.UTC_seconds == 0x5dc6018c
        end
        @test headers[1].frame_index == 127
        @test headers[2].frame_index == 127
        @test headers[3].frame_index == 129
        @test headers[1].UTC_16nanosecondcycles == 0x029b9270
        @test headers[2].UTC_16nanosecondcycles == 0x029b9270
        @test headers[3].UTC_16nanosecondcycles == 0x035a4e90
        @test headers[1].trigger_counter == 0
        @test headers[2].trigger_counter == 1
        @test headers[3].trigger_counter == 0
        @test headers[1].trigger_mask == 22
        @test headers[2].trigger_mask == 22
        @test headers[3].trigger_mask == 4
        @test headers[1].overlays == 6
        @test headers[2].overlays == 21
        @test headers[3].overlays == 0
    end

    close(f_auto)
end
