--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local location = {}
local mattata = require('mattata')
local https = require('ssl.https')
local url = require('socket.url')
local json = require('dkjson')
local setloc = require('plugins.setloc')
local redis = require('libs.redis')

function location:init()
    location.commands = mattata.commands(self.info.username):command('location'):command('loc').table
    location.help = '/location [query] - Sends your location, or a location from Google Maps. Alias: /loc.'
end

function location:on_inline_query(inline_query, configuration)
    local input = mattata.input(inline_query.query)
    local result = {}
    if not input then
        local loc = setloc.get_loc(inline_query.from.id)
        if not loc then
            return false, 'No location was found for the given user!'
        end
        local jdat = json.decode(loc)
        local output = mattata.inline_result():type('location'):id(1):title(jdat.address):latitude(jdat.latitude):longitude(jdat.longitude)
        return mattata.answer_inline_query(inline_query.id, output)
    end
    local jstr, res = https.request('https://api.opencagedata.com/geocode/v1/json?key=' .. configuration['keys']['location'] .. '&pretty=0&q=' .. url.escape(input))
    if res ~= 200 then
        return false, 'Connection error! [' .. res .. ']'
    end
    local jdat = json.decode(jstr)
    if jdat.total_results == 0 then
        return false, 'No results were found!'
    end
    local output = mattata.inline_result():type('location'):id(1):title(input):latitude(jdat.results[1].geometry.lat):longitude(jdat.results[1].geometry.lng)
    return mattata.answer_inline_query(inline_query.id, output)
end

function location:on_message(message, configuration, language)
    local input = mattata.input(message.text:lower())
    if not input and not setloc.get_loc(message.from.id) then
        local success = mattata.send_force_reply(message, language['location']['1'])
        if success then
            local action = mattata.command_action(message.chat.id, success.result.message_id)
            redis:set(action, '/setloc')
        end
        return
    elseif not input then
        local loc = setloc.get_loc(message.from.id)
        return mattata.send_location(
            message.chat.id,
            json.decode(loc).latitude,
            json.decode(loc).longitude
        )
    end
    local jstr, res = https.request('https://api.opencagedata.com/geocode/v1/json?key=' .. configuration['keys']['location'] .. '&pretty=0&q=' .. url.escape(input))
    if res ~= 200 then
        return mattata.send_reply(
            message,
            language['errors']['connection']
        )
    end
    local jdat = json.decode(jstr)
    if jdat.total_results == 0 then
        return mattata.send_reply(
            message,
            language['errors']['results']
        )
    end
    return mattata.send_location(
        message.chat.id,
        jdat.results[1].geometry.lat,
        jdat.results[1].geometry.lng
    )
end

return location