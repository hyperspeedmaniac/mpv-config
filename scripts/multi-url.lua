-- multi-url.lua
-- Opens multiple URLs passed via command line as a playlist
-- Usage: mpv url1 url2 url3 ...
-- Each URL after the first is appended to the playlist

local mp = require("mp")

mp.register_event("start-file", function()
    local count = mp.get_property_number("playlist-count", 0)
    if count > 1 then
        local pos = mp.get_property_number("playlist-pos", 0)
        mp.osd_message(string.format("Playlist: %d / %d", pos + 1, count), 2)
    end
end)
