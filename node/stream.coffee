
fs = require 'fs'
Promise = require 'when'

class Stream

  constructor: (@path, @options) ->
    @data = new Buffer(0)
    @stream = fs.createReadStream(@path, @options)
    @stream.on 'error', @_error

  _error: (err) ->
    throw err

  # Loads the bytes from the file into memory
  _load: (byte, cb) ->
    if byte < @data.length
      cb()
    else
      bytes = @stream.read(byte - @data.length + 1)
      if bytes isnt null
        @data = Buffer.concat [@data, bytes]
        cb()
      else
        @stream.once 'readable', => @_load(byte, cb)

  # Promise wrapper for _load
  load: (byte) ->
    deferred = Promise.defer()
    @_load byte, ->
      deferred.resolve()
    return deferred.promise

  rangeSync: (start, end) ->
    return @data[start..end]

  range: (start, end) ->
    byte = end - start
    @load(byte).then => @rangeSync(start, end)


  # GET BYTE

  getByteSync: (offset) ->
    return @data[offset]

  getByte: (offset) ->
    @load(offset).then => @getByteSync(offset)


  # IS BIT SET

  isBitSetSync: (offset, bit) ->
    return (@data[offset]  & (1 << bit)) isnt 0

  isBitSet: (offset) ->
    @load(offset).then => @isBitSetSync(offset)


  # FIND ZERO

  findZeroSync: (start, end) ->
    while @data[start] isnt 0
      if start++ >= end then return end
    return i

  findZero: (start, end) ->
    @load(end).then => @findZeroSync(start, end)


  # GET INT

  getIntSync: (offset, bigEndian) ->
      int = if bigEndian then (((bytes[1] << 8) + bytes[2]) << 8) + bytes[3] else
                              (((bytes[3] << 8) + bytes[2]) << 8) + bytes[1]
      if int < 0 then int += 16777216
      return int

  getInt: (offset, bigEndian) ->
    @range(offset, offset + 2).then (bytes) =>
      @getIntSync(offset, bigEndian)


  # DECODE STRING

  decodeStringSync: (charset, start, end) ->
    switch charset
      when 'ascii'
        text: @data.toString(charset, start, end)
        length: end - start
      when 'latin1'
        buf = @data.slice(start, end)
        text = iconv.fromEncoding(buf, 'latin1')
        text:   text,
        length: Buffer.byteLength(text)
      when 'utf16'
        bytes = @rangeSync(start, end)
        text:   readUTF16String(bytes),
        length: bytes.length
      when 'utf8'
        text = @data.toString(charset, start, end)
        text:   text,
        length: Buffer.byteLength(text)

  decodeString: (charset, start, end) ->
    @load(end).then => @decodeStringSync(charset, start, end)


  # STRTOK.UINT32_BE

  UINT32_BE_SYNC: (offset) ->
    return ((@data[offset] << 23) * 2) + (
      (@data[offset + 1] << 16) |
      (@data[offset + 2] << 8)  |
      (@data[offset + 3]))

  UINT32_BE: (offset) ->
    @load(offset + 3).then >
      @UINT32_BE_SYNC(offset)


# READ UTF16 STTRING

readUTF16String = (bytes) ->
  ix = 0
  offset1 = 1
  offset2 = 0
  maxBytes = bytes.length

  if bytes[0] is 0xFE and bytes[1] is 0xFF
    bigEndian = true
    ix = 2
    offset1 = 0
    offset2 = 1
  else if bytes[0] is 0xFF and bytes[1] is 0xFE
    bigEndian = false
    ix = 2

  str = ''
  for j in [0..maxBytes]
    byte1 = bytes[ix + offset1]
    byte2 = bytes[ix + offset2]
    word1 = (byte1 << 8) + byte2
    ix += 2

    if word1 is 0x0000
      break
    else if byte1 < 0xD8 or byte1 >= 0xE0
      str += String.fromCharCode(word1)
    else
      byte3 = bytes[ix + offset1]
      byte4 = bytes[ix + offset2]
      word2 = (byte3 << 8) + byte4
      ix += 2
      str += String.fromCharCode(word1, word2)
  return str


module.exports = Stream
