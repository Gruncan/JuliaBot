create(c::Client, ::Type{Reaction}, m::Message, emoji::StringOrChar) = create_reaction(c, m.channel_id, m.id, emoji)
function create(c::Client, ::Type{Reaction}, m::Message, e::Emoji)
    emoji = e.id === nothing ? e.name : "$(e.name):$(e.id)"
    return create_reaction(c, m.channel_id, m.id, emoji)
end

retrieve(c::Client, ::Type{Reaction}, m::Message, emoji::StringOrChar) = get_reactions(c, m.channel_id, m.id, emoji)
retrieve(c::Client, ::Type{Reaction}, m::Message, e::Emoji) = get(Reaction, c, m, e.name)

delete(c::Client, ::Type{Reaction}, m::Message) = delete_all_reactions(c, m.channel_id, m.id)
function delete(c::Client, emoji::StringOrChar, m::Message, u::User)
    return if c.state.user !== nothing && u.id == c.state.user.id
        delete_own_reaction(c, m.channel_id, m.id, emoji)
    else
        delete_user_reaction(c, m.channel_id, m.id, emoji, u.id)
    end
end
function delete(c::Client, e::Emoji, m::Message, u::User)
    emoji = e.id === nothing ? e.name : "$(e.name):$(e.id)"
    delete(c, emoji, m, u)
end
