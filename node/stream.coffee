
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

  # Return an inclusive range
  range: (start, end) ->
    byte = end - start
    @load(byte).then =>
      return @data[start..end]

  getByte: (offset) ->
    @load(offset).then =>
      return @data[offset]

  isBitSet: (offset, bit, sync) ->
    # Sync
    if sync then return (@data[offset]  & (1 << bit)) isnt 0
    # Async
    @getByte(offset).then (byte) -> return (byte & (1 << bit)) isnt 0

  findZero: (start, end) ->
    @load(end).then =>
      i = start
      while @data[i] isnt 0
        if i >= end
          return end
        i  += 1
      return i

  getInt: (offset, bigEndian) ->
    Promise.all [
      @getByte(offset)
      @getByte(offset + 1)
      @getByte(offset + 2)
    ], ([byte1, byte2, byte3]) ->
      int = if bigEndian then (((byte1 << 8) + byte2) << 8) + byte3 else
                              (((byte3 << 8) + byte2) << 8) + byte1
      if int < 0 then int += 16777216
      return int

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

module.exports = Stream
