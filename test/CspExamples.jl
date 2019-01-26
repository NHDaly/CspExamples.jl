include("../src/CspExamples.jl")
using Test

fill_channel(ch, input) = for v in input
    put!(ch, v)
end

@testset "S31_COPY" begin
    input = "hello"
    # The input channel is a 1-character buffer as described in the paper.
    west = Channel(ch->(fill_channel(ch, input)), csize=1, ctype=Char)
    east = Channel{Char}(Inf) # allow buffering the output infinitely for ease of testing
    CspExamples.S31_COPY(west, east)
    @test String(collect(east)) == input
end

@testset "S32_SQUASH" begin
    # The input channel is a 1-character buffer as described in the paper.
    west = Channel(csize=1, ctype=Char) do ch
        fill_channel(ch, "hello*to**the*world")
    end
    east = Channel{Char}(Inf) # allow buffering the output infinitely for ease of testing
    CspExamples.S32_SQUASH(west, east)
    @test String(collect(east)) == "hello*to↑the*world"
end

# Convenience function to create and fill a channel.
make_filled_channel(input; csize=0, ctype=eltype(input)) = Channel(csize=csize, ctype=ctype) do ch
    fill_channel(ch, input)
end

@testset "S32_SQUASH_EXT" begin
    # Test 1 * at end
    west = make_filled_channel("hello**world*")
    east = Channel{Char}(Inf)
    CspExamples.S32_SQUASH_EXT(west, east)
    @test String(collect(east)) == "hello↑world*"

    # Test 3 *s at end
    west = make_filled_channel("hello**world***", csize=1)
    east = Channel{Char}(Inf)
    CspExamples.S32_SQUASH_EXT(west, east)
    @test String(collect(east)) == "hello↑world↑*"
end

@testset "S33_DISASSEMBLE" begin
    cardfile = Channel(ctype=String) do ch
        for s in ["hey", "buddy"]; put!(ch, s); end
    end
    X = Channel{Char}(Inf)
    CspExamples.S33_DISASSEMBLE(cardfile, X)
    @test String(collect(X)) == "hey buddy "
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

    # Expect to get back the inputstr split into 125-character lines
    expected = inputstr
    expected[end-1:end] .= ' '
    expected = [String(expected[1+(i-1)*linelength:i*linelength]) for i in 1:2]
    @test collect(lineprinter) == expected
end
