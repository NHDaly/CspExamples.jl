include("../src/CspExamples.jl")
using Test

fill_channel(ch, input) = for v in input
    put!(ch, v)
end

@testset "S31_COPY" begin
    @testset "Copy pre-filled buffer" begin
        # The input channel is a 1-character buffer as described in the paper.
        west = Channel(ch->(fill_channel(ch, "hello")), csize=1, ctype=Char)
        east = Channel(ch->CspExamples.S31_COPY(west, ch), ctype=Char)
        @test String(collect(east)) == "hello"
    end
    @testset "test incremental concurrent copying" begin
        west = Channel{Char}(1)
        east = Channel(ch->CspExamples.S31_COPY(west, ch), ctype=Char, csize=Inf)
        put!(west, 'w');
        @test (yield(); isready(east))  # Need to yield before testing concurrent behavior
        put!(west, 'o'); put!(west, 'r'); put!(west, 'l'); put!(west, 'd');
        close(west)
        @test String(collect(east)) == "world"
    end
end

@testset "S32_SQUASH" begin
    # The input channel is a 1-character buffer as described in the paper.
    west = Channel(csize=1, ctype=Char) do ch
        fill_channel(ch, "hello*to**the*world")
    end
    east = Channel(ch->CspExamples.S32_SQUASH(west, ch), ctype=Char)
    @test String(collect(east)) == "hello*to↑the*world"
end

# Convenience function to create and fill a channel.
make_fill_close_chnl(input; csize=0, ctype=eltype(input)) = Channel(csize=csize, ctype=ctype) do ch
    fill_channel(ch, input)
end

@testset "S32_SQUASH_EXT" begin
    # Test 1 * at end
    west = make_fill_close_chnl("hello**world*")
    east = Channel(ch->CspExamples.S32_SQUASH_EXT(west, ch), ctype=Char)
    @test String(collect(east)) == "hello↑world*"

    # Test 3 *s at end
    west = make_fill_close_chnl("hello**world***", csize=1)
    east = Channel(ch->CspExamples.S32_SQUASH_EXT(west, ch), ctype=Char)
    @test String(collect(east)) == "hello↑world↑*"
end

@testset "S33_DISASSEMBLE" begin
    cardfile = Channel(ctype=String) do ch
        for s in ["hey", "buddy"]; put!(ch, s); end
    end
    @test "hey buddy " ==
            String(collect(Channel(X->CspExamples.S33_DISASSEMBLE(cardfile, X), ctype=Char)))
end

@testset "S34_ASSEMBLE" begin
    linelength = 3
    inputstr = rand('a':'z', linelength*2)
    X = Channel(ctype=Char) do ch
        # Pass two characters too few.
        for s in inputstr[1:end-2]; put!(ch, s); end
    end
    lineprinter = Channel(Inf)
    CspExamples.S34_ASSEMBLE(X, lineprinter, linelength)
    close(lineprinter)

    # Expect to get back the inputstr split into 125-character lines
    expected = inputstr
    expected[end-1:end] .= ' '
    expected = [String(expected[1+(i-1)*linelength:i*linelength]) for i in 1:2]
    @test collect(lineprinter) == expected
end

@testset "S35_Reformat" begin
    reformatted = Channel() do ch
        CspExamples.S35_Reformat(make_fill_close_chnl(["hello", "world"]), ch, 4)
    end
    @test collect(reformatted) == ["hell", "o wo", "rld "]
end
@testset "S35_Reformat2" begin
    reformatted = Channel() do ch
        CspExamples.S35_Reformat2(make_fill_close_chnl(["hello", "world"]), ch, 4)
    end
    @test collect(reformatted) == ["hell", "o wo", "rld "]
end
@testset "S35_Reformat_non_concurrent" begin
    # While the implementation of S35_Reformat_non_concurrent is more convoluted than
    # the concurrent version, the callsite is of course simpler because we don't have to
    # consider concurrency at all.
    #
    # A best-of-both-worlds approach might be to expose a "normal" interface like this one,
    # as a wrapper around a concurrent implementation.
    reformatted = CspExamples.S35_Reformat_non_concurrent(["hello", "world"], 4)
    @test reformatted == ["hell", "o wo", "rld "]
end
