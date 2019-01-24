module CspExamples

"""
    S31_COPY(west::Channel, east::Channel)

3.1 COPY

> "Problem: Write a process X to copy characters output by process west
to process, east."

As an addition to the paper's example, we stop when west is closed,
otherwise we would just hang at this point. To indicate this to the
client, we close the east channel.
"""
function S31_COPY(west::Channel{Char}, east::Channel{Char})
    for c in west
        put!(east, c)
    end
    close(east)
end

"""
    S32_SQUASH(west::Channel, east::Channel)

3.2 SQUASH

> "Problem: Adapt the previous program [COPY] to replace every pair of
consecutive asterisks "**" by an upward arrow "↑". Assume that the final
character input is not an asterisk."
"""
function S32_SQUASH(west::Channel{Char}, east::Channel{Char})
    for c in west
        if c == '*'
            c1 = take!(west)
            if c1 == '*'
                put!(east, '↑')
            else
                put!(east, c)
                put!(east, c1)
            end
        else
            put!(east, c)
        end
    end
    close(east)
end

"""
    S32_SQUASH_EXT(west::Channel, east::Channel)

Hoare adds a remark to 3.2 SQUASH: "(2) As an exercise, adapt this
process to deal sensibly with input which ends with an odd number of
asterisks."
"""
function S31_SQUASH_EXT(west::Channel{Char}, east::Channel{Char})
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
    close(east)
end

end
