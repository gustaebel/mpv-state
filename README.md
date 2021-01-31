# mpv-state

Store and restore `mpv(1)` playback state using a JSON file.

## Usage

```sh
mpv --script=mpv-state.lua --script-opts=mpv-state-filename=state.json <filenames>
```

Properties in the state file take precedence over options from the mpv command
line. It is possible to pass `/dev/null` as `<filename>` if there is an existing
state file. This makes it possible to start mpv with a fabricated state file
and without any further playback related options.

## Playback properties

The following properties are currently supported:

- playlist
- playlist-pos
- time-pos
- vid, aid, sid
- audio-delay

## Setup

Refer to <https://mpv.io/manual/stable/#script-location>.

## JSON state file

Example for a JSON state file:

```json
{
  "playlist-pos": 6,
  "playlist": [
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 01 - Gumbo.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 02 - The Gift.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 03 - Our Language.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 04 - The True Welcome.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 05 - Swing: Pure Pleasure.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 06 - Swing: The Velocity of Celebration.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 07 - Dedicated to Chaos.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 08 - Risk.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 09 - The Adventure.mkv",
    "/mnt/media/video/documentation/Ken Burns/Jazz/Jazz - 10 - A Masterpiece by Midnight.mkv"
  ],
  "time-pos": 3732.062,
  "vid": 1,
  "aid": 1,
  "sid": 1,
  "audio-delay": 0,
  "reason": "quit",
  "statistics": {
    "stop-time": 1612074581,
    "start-position": 3731.261,
    "start-time": 1612074580
  }
}
```
