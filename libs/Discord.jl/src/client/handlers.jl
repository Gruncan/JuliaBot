const DEFAULT_PRIORITY = 100

# Indicators for fallback handlers to run.
@enum FallbackReason FB_PREDICATE FB_PARSERS FB_ALLOWED FB_PERMISSIONS FB_COOLDOWN

# An event handler.
abstract type AbstractHandler{T<:AbstractEvent} end

# The event type that a handler accepts.
Base.eltype(::AbstractHandler{T}) where T = T

# Put and take a handler's results.
Base.put!(::AbstractHandler, ::Vector) = nothing
Base.take!(::AbstractHandler) = []

predicate(::AbstractHandler) = alwaystrue
handler(::AbstractHandler) = donothing
fallback(::AbstractHandler, ::FallbackReason) = donothing
priority(::AbstractHandler) = DEFAULT_PRIORITY
expiry(::AbstractHandler) = nothing
stopcond(::AbstractHandler) = alwaysfalse

# Update the handler's expiry.
dec!(::AbstractHandler) = nothing

# Check expiry and collection status.
isexpired(::AbstractHandler) = false
iscollecting(::AbstractHandler) = false

# Collect the handler's results.
results(::AbstractHandler) = []

# A generic event handler.
mutable struct Handler{T} <: AbstractHandler{T}
    predicate::Function
    handler::Function
    fallback::Function
    priority::Int
    remaining::Nullable{Int}
    expiry::Nullable{DateTime}
    stopcond::Nullable{Function}
    collect::Bool
    results::Vector{Any}
    chan::Channel{Vector{Any}}

    function Handler{T}(
        predicate::Function,
        handler::Function,
        fallback::Function,
        priority::Int,
        remaining::Nullable{Int},
        expiry::Nullable{DateTime},
        stopcond::Nullable{Function},
        collect::Bool,
    ) where T <: AbstractEvent
        return new{T}(
            predicate, handler, fallback, priority,
            remaining, expiry, stopcond, collect, [], Channel{Vector{Any}}(1),
        )
    end
    function Handler{T}(
        predicate::Function,
        handler::Function,
        fallback::Function,
        priority::Int,
        remaining::Nullable{Int},
        expiry::Period,
        stopcond::Nullable{Function},
        collect::Bool,
    ) where T <: AbstractEvent
        return new{T}(
            predicate, handler, fallback, priority,
            remaining, now() + expiry, stopcond, collect, [], Channel{Vector{Any}}(1),
        )
    end
end

predicate(h::Handler) = h.predicate
handler(h::Handler) = h.handler
fallback(h::Handler, ::FallbackReason) = h.fallback
priority(h::Handler) = h.priority
expiry(h::Handler) = h.expiry
stopcond(h::Handler) = h.stopcond
dec!(h::Handler) = h.remaining isa Int && (h.remaining -= 1)
iscollecting(h::Handler) = h.collect
results(h::Handler) = h.results
Base.put!(h::Handler, v::Vector) = put!(h.chan, v)

function isexpired(h::Handler)
    return if h.remaining isa Int && h.remaining <= 0
        true
    elseif h.expiry isa DateTime && now() > h.expiry
        true
    elseif h.stopcond isa Function
        try
            h.stopcond(results(h)) === true
        catch
            # TODO: Log this?
            false
        end
    else
        false
    end
end

function Base.take!(h::Handler)
    iscollecting(h) || return []

    # Only wait for one condition.
    while true
        isexpired(h) && break
        sleep(Millisecond(100))
    end

    # Expired handlers don't always get cleaned up immediately.
    isready(h.chan) ? take!(h.chan) : results(h)
end
