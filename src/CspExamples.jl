module CspExamples

"""
    S31_COPY(west::Channel, east::Channel)

3.1 COPY

> "Problem: Write a process X to copy characters output by process west to process, east."

Julia uses Channels to communicate messages between Tasks, which we use to model Hoare's
"processes". This function takes each character out of west and puts it in east,
continuously, until west is closed.

As an addition to the paper's example, we stop when west is closed, otherwise we would just
hang at this point. Note that we don't close east. Returning from this function is signal
enough that west is closed -- at that point the caller can close(east) if desired. Or, the
user can pass this function in the Channel constructor, and when the function returns the
Channel is automatically closed.

Note that if west is never closed, we will never return, which is absolutely fine.
"""
function S31_COPY(west::Channel{Char}, east::Channel{Char})
    for c in west
        put!(east, c)
    end
end

"""
    S32_SQUASH(west::Channel, east::Channel)

3.2 SQUASH

> "Problem: Adapt the previous program [COPY] to replace every pair of
consecutive asterisks "**" by an upward arrow "↑". Assume that the final
character input is not an asterisk."

Following Hoare's example, if we get an asterisk from west, we then take another character
as well. If the second character is also an asterisk, we write the upward arrow; if not, we
put the two characters into east as we would have in COPY.
"""
function S32_SQUASH(west::Channel{Char}, east::Channel{Char})
    for c in west
        if c == '*'
            c1 = take!(west)
            if c1 == '*'
                put!(east, '↑')  # hooray for unicode
            else
                put!(east, c)
                put!(east, c1)
            end
        else
            put!(east, c)
        end
    end
end

"""
    S32_SQUASH_EXT(west::Channel, east::Channel)

Hoare adds a remark to 3.2 SQUASH: "(2) As an exercise, adapt this
process to deal sensibly with input which ends with an odd number of
asterisks."

We do this by wrapping the `take!` in a try-catch, since the naked take! will throw if the
Channel has been closed.
"""
function S32_SQUASH_EXT(west::Channel{Char}, east::Channel{Char})
    for c in west
        if c == '*'
            # TODO: Is it possible to also have a timeout like thomas11 does in Go?
            try
                c1 = take!(west)
                if c1 == '*'
                    put!(east, '↑')
                else
                    put!(east, c)
                    put!(east, c1)
                end
                continue
            catch end
        end
        put!(east, c)
    end
end


"""
    S33_DISASSEMBLE(cardfile::Channel{String}, X::Channel{Char})

3.3 DISASSEMBLE

> "Problem: to read cards from a cardfile and output to process X the stream of characters
they contain. An extra space should be inserted at the end of each card."

NOTE: I have typed the output Channel as `Channel{>:Char}`, meaning we don't care what the
element type of Channel is, as long as it includes Chars. This gives the caller more
flexibility. (e.g. they can pass a Channel{Any} if they want to.)
"""
function S33_DISASSEMBLE(cardfile::Channel{String}, X::Channel{>:Char})
    for cardimage in cardfile
        for c in cardimage
            put!(X, c)
        end
        put!(X, ' ')
    end
end

"""
    S34_ASSEMBLE(X::Channel{Char}, lineprinter::Channel{>:String}, linelength=125)

3.4 ASSEMBLE

> "Problem: To read a stream of characters from process X and print them in lines of 125
characters on a lineprinter. The last line should be completed with spaces if necessary."

NOTE: I've made the linelength a parameter, so that this method can split the input into
lines of whatever length desired. (This makes testing easier!)
"""
function S34_ASSEMBLE(X::Channel{Char}, lineprinter::Channel{>:String}, linelength=125)
    while isopen(X)
        out = Char[]
        for c in Base.Iterators.take(X, linelength)
            push!(out, c)
        end
        out = rpad(String(out), linelength)
        put!(lineprinter, out)
    end
end

"""
    S35_Reformat(west::Channel{String}, east::Channel{>:String}, linelength=125)

3.5 Reformat

> "Problem: Read a sequence of cards of 80 characters each, and print
the characters on a lineprinter at 125 characters per line. Every card
should be followed by an extra space, and the last line should be
completed with spaces if necessary."

This one's fun! We can reuse the existing functions by creating an intermediate Channel and
Task (equivalent to a Process in Hoare's paper) to act as the output and then input.

Note that this function blocks on its call to ASSEMBLE, so it doesn't return until the
reformatting is completed. This keeps with the style of the functions seen so far, which
block internally, allowing the caller to choose whether to run it asynchronously.
"""
function S35_Reformat(west::Channel{String}, east::Channel{>:String}, linelength=125)
    # This Channel constructor creates a channel and spawns a Task (and yields to it). When
    # the Task is completed, the Channel is closed.
    disassembled = Channel(ctype=Char) do ch
        S33_DISASSEMBLE(west, ch)
    end
    S34_ASSEMBLE(disassembled, east, linelength)
end

"""
    S35_Reformat2(west::Channel{String}, east::Channel{>:String}, linelength=125)

An alternative implementation of S35_Reformat, which makes the concurrency operations more
explicit, and keeps a style more similar to Go.
"""
function S35_Reformat2(west::Channel{String}, east::Channel{>:String}, linelength=125)
    tmp = Channel{Char}(0)
    @async begin
        S33_DISASSEMBLE(west, tmp);
        # Note that we must close(tmp) to signal to ASSEMBLE that it's okay to return,
        # because we've chosen to not have DISASSEMBLE and ASSEMBLE close output channels.
        close(tmp);
    end
    S34_ASSEMBLE(tmp, east, linelength)
end

"""
    S35_Reformat_non_concurrent(input::Array{String})::Array{String}

As Hoare notes in the paper:
> "This elementary problem [Reformat] is difficult to solve elegantly without coroutines."

This is indeed the case, as illustrated in this best-faith attempt. What makes it tricky is
that you have two separate, but overlapping, loops that end at different times. You cannot
represent them both as real for-loops in straightline code, but you can in concurrent
programming, because a concurrent program grants you two separate Instruction Pointers to
trace through each loop.

Here, without concurrency, we emulate the second loop (printing 125-character lines) by
with an if-statement, and manually re-initializing the loop's variables.
"""
function S35_Reformat_non_concurrent(input::Array{String}, linelength=125)::Array{String}
    outs = String[]
    out = Char[]
    for s in input
        for c in s
            push!(out, c)
            # This is the manual implementation of the "second loop":
            if length(out) == linelength
                # "end of the loop"
                push!(outs, rpad(String(out), linelength))
                out = Char[]  # Re-initialize
            end
        end
        push!(out, ' ')
    end
    # Here we have to duplicate the end of the "second loop" since there are two ways to
    # exit the "loop condition".
    push!(outs, rpad(String(out), linelength))
    return outs
end

end
