-------------------------------------------------------------------------------
-- state.lua
-------------------------------------------------------------------------------
--
-- Store and restore mpv(1) playback state using a JSON file.
--
-- The following properties are supported:
--      playlist
--      playlist-pos
--      time-pos
--      vid, aid, sid
--      audio-delay
--
-- Usage:
-- mpv --script=state.lua --script-opts=state-filename=state.json <filenames>
--
-- Properties in the state file take precedence over options from the mpv
-- command line. It is possible to pass /dev/null as <filename> if there is an
-- existing state file. This makes it possible to start mpv with a fabricated
-- state file and without any further playback related options.
--
-------------------------------------------------------------------------------
--
-- Example for a JSON state file:
-- {
--   "playlist-pos": 6,
--   "playlist": [
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 01 - Gumbo.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 02 - The Gift.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 03 - Our Language.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 04 - The True Welcome.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 05 - Swing: Pure Pleasure.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 06 - Swing: The Velocity of Celebration.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 07 - Dedicated to Chaos.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 08 - Risk.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 09 - The Adventure.mkv",
--     "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 10 - A Masterpiece by Midnight.mkv"
--   ],
--   "time-pos": 3732.062,
--   "vid": 1,
--   "aid": 1,
--   "sid": 1,
--   "audio-delay": 0,
--   "reason": "quit",
--   "statistics": {
--     "stop-time": 1612074581,
--     "start-position": 3731.261,
--     "start-time": 1612074580
--   }
-- }
--
-------------------------------------------------------------------------------


local msg = require "mp.msg"
local utils = require "mp.utils"

local state = {statistics={}}
local state_filename = mp.get_property_native("options/script-opts")["state-filename"]

local playlist_set = false
local playback_set = false

local duration = 0

-- Prepare default values.
local init_playlist_pos = 0
local init_time_pos = nil
local init_vid = nil
local init_aid = nil
local init_sid = nil
local init_audio_delay = nil


-- Load a previous state from a JSON file.
local function load_state()
    local file = io.open(state_filename, "r")
    if file == nil then
        return
    end

    msg.info("load state from", state_filename)
    state, err = utils.parse_json(file:read("*a"))
    file:close()

    -- Prepare the statistics table.
    if state["statistics"] == nil then
        state["statistics"] = {}
    end

    -- Prepare initialization values from the state file. These initialization
    -- values are subsequently used in the file-loaded event handler. In case
    -- of a missing playlist value the filenames are taken from the mpv command
    -- line, otherwise they are completely ignored as are all other options.
    if state["playlist"] ~= nil then
        mp.command("playlist-clear")
        for i = 1,#state["playlist"] do
            mp.commandv("loadfile", state["playlist"][i], "append")
        end
    end

    if state["playlist-pos"] ~= nil then
        init_playlist_pos = state["playlist-pos"]
    end

    if state["time-pos"] ~= nil then
        init_time_pos = state["time-pos"]
    end

    if state["vid"] ~= nil then
        init_vid = state["vid"]
    end

    if state["aid"] ~= nil then
        init_aid = state["aid"]
    end

    if state["sid"] ~= nil then
        init_sid = state["sid"]
    end

    if state["audio-delay"] ~= nil then
        init_audio_delay = state["audio-delay"]
    end
end

-- Write the current state to a JSON file.
local function save_state()
    local file = io.open(state_filename, "w")
    local result, err = utils.format_json(state)
    if err == nil then
        file:write(result)
    end
    file:close()
end

-- Restore all playback related properties in one go.
local function restore_playback_properties()
    if playback_set then
        return
    end

    if init_time_pos ~= nil then
        state["statistics"]["start-position"] = init_time_pos
        msg.info("restore time-pos to", init_time_pos)
        mp.set_property_number("time-pos", init_time_pos)
    end

    if init_vid ~= nil then
        msg.info("restore vid to", init_vid)
        mp.set_property_number("vid", init_vid)
    end

    if init_aid ~= nil then
        msg.info("restore aid to", init_aid)
        mp.set_property_number("aid", init_aid)
    end

    if init_sid ~= nil then
        msg.info("restore sid to", init_sid)
        mp.set_property_number("sid", init_sid)
    end

    if init_audio_delay ~= nil then
        msg.info("restore audio-delay to", init_audio_delay)
        mp.set_property_number("audio-delay", init_audio_delay)
    end

    -- Mark the playback related properties as set.
    playback_set = true
end

-- Handler for file-loaded event.
local function on_file_loaded(event)
    -- XXX I would've loved to use a separate event handler just for the
    -- initial setup that unregisters itself after being called (similar to
    -- on_time_pos_initially_changed()) but it didn't work.

    -- XXX Also it seems that we can't prevent the first file in the playlist
    -- from being loaded by default and so we have to switch to the file we
    -- want just after that.

    -- Set the playlist position property to the initial value taken from the
    -- loaded state. After the property has been set a follow-up file-loaded
    -- event is triggered for the file from the new position. Only then can we
    -- set the playback related properties.
    if not playlist_set then
        msg.info("restore playlist-pos to", init_playlist_pos)
        if init_playlist_pos == 0 then
            -- mpv always loads the first file in the playlist, there seems to
            -- be no way around that. So, we don't have to explicitly set the
            -- playlist-pos property, but we have to restore the playback
            -- related properties here immediately.
            restore_playback_properties()
        else
            mp.set_property_number("playlist-pos", init_playlist_pos)
        end

        -- Mark the playlist position as set.
        playlist_set = true
    else
        -- The playlist-pos property has been changed, restore the playback
        -- settings now.
        restore_playback_properties()
    end
end

-- Handler for end-file property.
local function on_end_file(event)
    msg.info("writing state to", state_filename)
    state["statistics"]["stop-time"] = os.time()
    if event.reason == "eof" then
        state["time-pos"] = duration
    end
    state["reason"] = event.reason
    save_state()
end

-- Handler for playlist property.
local function on_playlist_property_changed(name, value)
    local playlist = {}

    for i, item in ipairs(value) do
        table.insert(playlist, item["filename"])
        if item["current"] then
            state["playlist-pos"] = i - 1
        end
    end

    state["playlist"] = playlist
end

-- Handler for time-pos event.
local function on_time_pos_changed(name, value)
    if value ~= nil then
        state["time-pos"] = value
    end
end

-- Initial handler for time-pos property.
local function on_time_pos_initially_changed(name, value)
    if value ~= nil then
        state["time-pos"] = value
        if state["statistics"]["start-position"] == nil then
            state["statistics"]["start-position"] = value
        end
        mp.unobserve_property(on_time_pos_initially_changed)
        mp.observe_property("time-pos", "number", on_time_pos_changed)
    end
end

-- Handler for duration property.
local function on_duration_changed(name, value)
    duration = value
end

-- Handler for all other properties.
local function on_property_changed(name, value)
    state[name] = value
end

-- Main context.
if state_filename ~= nil then
    msg.info("state plugin enabled")

    load_state()

    mp.register_event("file-loaded", on_file_loaded)
    mp.register_event("end-file", on_end_file)

    mp.observe_property("playlist", "native", on_playlist_property_changed)
    mp.observe_property("time-pos", "number", on_time_pos_initially_changed)
    mp.observe_property("duration", "number", on_duration_changed)
    mp.observe_property("vid", "number", on_property_changed)
    mp.observe_property("aid", "number", on_property_changed)
    mp.observe_property("sid", "number", on_property_changed)
    mp.observe_property("audio-delay", "number", on_property_changed)
end

state["statistics"]["start-time"] = os.time()

return {}
