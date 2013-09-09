
Promise = require 'when'
parser  = require './id3v2_parser'
strtok  = require 'strtok'
FRAMES  = require './id3v2_frames.json'

readTags = () ->

  offset = 0

  Promise.all [
    @stream.range(0,5)
    readTagSize(@stream)
  ], then ([buffer, tagSize]) =>

    majorVersion = buffer[3]
    minorVersion = buffer[4]

    id3 =
      version:     "2.#{ majorVersion }.#{ minorVersion }"
      major:       majorVersion
      unsync:      @stream.isBitSetSync(5, 7)
      xheader:     @stream.isBitSetSync(5, 6)
      xindicator:  @stream.isBitSetSync(5, 5)
      size:        tagSize

    offset += 10

    if id3.xheader
      console.log 'has xheader'

    frames = if id3.unsync then {} else
      readFrames(@stream, id3, offset, id3.size - 10).then (frames) ->
        frames
        frames.id3 = id3
        return frames


readFrames = (stream, id3, offset, end) ->
  frames = {}

  getFrame = (offset) ->
    return stream.load(offset + 7).then ->

      return if offset >= end

      return _readFrame(stream, id3, offset, end).then ([frame, finished, offset]) ->
        if finished then return

        # Add frame to collection
        if frames[frame.id]?.id?
          frames[frame.id] = [frames[frame.id]]
          frames[frame.id].push(frame)
        else
          frames[frame.id] = frame

        # Keep looping!
        return getFrame(offset)

  getFrame(offset).then ->
    return frames


_readFrame = (stream, id3, offset) ->

  deferred = Promise.defer()

  flags = null
  frameOffset = offset
  frame =
    id:           null
    size:         null
    description:  null
    data:         null

  switch id3.major

    when 2
      frame.id = stream.data.toString('ascii', frameOffset, frameOffset + 3)
      frame.size = stream.getIntSync(frameOffset + 3, true)
      frameHeaderSize = 6

    when 3
      frame.id = stream.data.toString('ascii', frameOffset, frameOffset + 4)
      frame.size = stream.UINT32_BE_SYNC(frameOffset + 4)
      frameHeaderSize = 10

    when 4
      frame.id = stream.data.toString('ascii', frameOffset, frameOffset + 4)
      frame.size = readTagSize(stream, frameOffset + 4)
      frameHeaderSize = 10

  # Last frame
  if frame.id in ['', '\u0000\u0000\u0000\u0000']
    return deferred.resolve [frame, true, offset]

  # Set description
  frame.description = FRAMES[frame.id] or 'Unknown'

  # Advance to next frame
  offset += frameHeaderSize + frame.size

  if id3.major <= 2
    deferred.resolve [frame, false, offset]


  readFrameFlags(stream, frameOffset + 8).then (flags) ->

      frameOffset += frameHeaderSize

      if flags?.format.data_length_indicator
        readTagSize(stream, frameOffset).then (frameDataSize) ->
        frameOffset  += 4
        frame.size   -= 4

      if flags?.format.unsync
        # Unimplemented
        deferred.resolve [null, false, offset]

      parser.readData(stream, frame.id, frameOffset, frame.size, flags, id3.major).then (data) ->
        frame.data = data
        deferred.resolve [frame, false, offset]


  return deferred.promise

readTagSize = (stream, offset=6) ->
  stream.range(offset, offset + 3). then (bytes) ->
    # 0x7f = 0b01111111
    return bytes[3] & 0x7f         |
         ((bytes[2] & 0x7f) << 7)  |
         ((bytes[1] & 0x7f) << 14) |
         ((bytes[0] & 0x7f) << 21)

readFrameFlags = (stream, offset) ->
  stream.load(offset + 1).then ->
    message:
      tag_alter_preservation:  stream.isBitSetSync(offset, 6),
      file_alter_preservation: stream.isBitSetSync(offset, 5),
      read_only:               stream.isBitSetSync(offset, 4)
    format:
      grouping_identity:       stream.isBitSetSync(offset + 1, 7),
      compression:             stream.isBitSetSync(offset + 1, 3),
      encryption:              stream.isBitSetSync(offset + 1, 2),
      unsync:                  stream.isBitSetSync(offset + 1, 1),
      data_length_indicator:   stream.isBitSetSync(offset + 1, 0)

module.exports =
  readTags: readTags
