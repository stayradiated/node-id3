
Promise = require 'when'
parser  = require './id3v2_frames'
FRAMES  = require './id3v2_frames.json'

readTags = () ->

  offset = 0

  Promise.all [
    @stream.range(0,5)
    readTagSize(@stream)
  ], then ([buffer, tagSize]) =>

    console.log buffer[5]

    majorVersion = buffer[3]
    minorVersion = buffer[4]

    id3 =
      version:     "2.#{majorVersion}.#{minorVersion}"
      major:       majorVersion
      unsync:      @stream.isBitSet(5, 7, true)
      xheader:     @stream.isBitSet(5, 6, true)
      xindicator:  @stream.isBitSet(5, 5, true)
      size:        tagSize

    console.log id3

    offset += 10

    if id3.xheader
      console.log 'has xheader'

    frames = if id3.unsync then {} else
      readFrames(stream, id3, offset, id3.size -10)
    
    frames.id3 = id3;

    console.log frames

readFrames = (stream, id3, offset, end) ->
  frames = {}

  while offset < end
    flags = null
    frame_offset = offset
    frame =
      id: null
      size: null
      description: null
      data: null

    switch id3.major

      when 2
        frame.id = stream.data.toString('ascii', frame_offset, frame_offset + 3)
        frame.size = stream.getInt24(frame_offset + 3, true)
        frame_header_size = 6

      when 3
        frame.id = stream.data.toString('ascii', frame_offset, frame_offset + 4)
        frame.size = strtok.UINT32_BE.get(stream, frame_offset + 4)
        frame_header_size = 10

      when 4
        frame.id = stream.data.toString('ascii', frame_offset, frame_offset + 4)
        frame.size = readTagSize(stream, frame_offset + 4)
        frame_header_size = 10

    # Last frame
    break if frame.id in ['', '\u0000\u0000\u0000\u0000']

    # Advance to next frame
    offset += frame_header_size + frame.size

    if id3.major > 2
      flags = readFrameFlags(stream, frame_offset + 8)

    frame_offset += frame_header_size

    if flags?.format.data_length_indicator
      frame_data_size = readTagSize(stream, frame_offset)
      frame_offset   += 4
      frame.size     -= 4

    if flags?.format.unsync
      # Unimplemented
      continue

    # Parse data
    try
      frame.data = parser.readData(b, frame.id, frame_offset, frame.size, flags, major)
    catch error
      console.log "Couldn't pass frame"
      continue

    frame.description = FRAMES[frame.id] or 'Unknown'

    if frames.hasOwnProperty frame.id
      if frames[frame.id].id
        frames[frame.id] = [frames[frame.id]]
      frames[frame.id].push(frame)
    else
      frames[frame.id] = frame

  return frames

readTagSize = (stream, offset=6) ->
  Promise.all [
    stream.getByte(offset)
    stream.getByte(offset + 1)
    stream.getByte(offset + 2)
    stream.getByte(offset + 3)
  ], ([size1, size2, size3, size4]) ->
    # 0x7f = 0b01111111
    return size4 & 0x7f or
      ((size3 & 0x7f) << 7) or
      ((size2 & 0x7f) << 14) or
      ((size1 & 0x7f) << 21)

readFrameFlags = (b, offset) ->
  message:
    tag_alter_preservation:  isBitSetAt(b, offset, 6),
    file_alter_preservation: isBitSetAt(b, offset, 5),
    read_only:               isBitSetAt(b, offset, 4)
  format:
    grouping_identity:       isBitSetAt(b, offset + 1, 7),
    compression:             isBitSetAt(b, offset + 1, 3),
    encryption:              isBitSetAt(b, offset + 1, 2),
    unsync:                  isBitSetAt(b, offset + 1, 1),
    data_length_indicator:   isBitSetAt(b, offset + 1, 0)

module.exports =
  readTags: readTags
