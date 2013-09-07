
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

  range: (start, end) ->
    byte = end - start
    @load(byte).then =>
      return @data[start..end]


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
    return start

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

  decodeString: (charset, start, end) ->
    @load(end).then ->
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
          bytes = @range(start, end)
          text:   readUTF16String(bytes),
          length: bytes.length
        when 'utf8'
          text = @data.toString(charset, start, end)
          text:   text,
          length: Buffer.byteLength(text)


  # STRTOK.UINT32_BE

  UINT32_BE_SYNC: (offset) ->
    return ((@data[offset] << 23) * 2) + (
      (@data[offset + 1] << 16) |
      (@data[offset + 2] << 8)  |
      (@data[offset + 3]))

  UINT32_BE: (offset) ->
    @load(offset + 3).then >
      @UINT32_BE_SYNC(offset)

module.exports = Stream
