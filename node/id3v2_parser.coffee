
readData = (stream, type, offset, length, flags, major=3) ->

  origType = type
  if type[0] is 'T'
    type = 'T*'

  switch type
    when 'PIC', 'APIC'
      start    = offset
      charset  = getTextEncoding stream[offset]
      pic      = {}
      offset  += 1

      switch major
        when 2
          pic.format = stream.data.toString 'ascii', offset, offset + 3
          offset    += 4
        when 3, 4
          pic.format = decodeString stream, charset, offset, findZero(b, offset, start + length)
          offset    += 1 + pic.format.length
          pic.format = pic.format.text

    when 'T*'

      start = offset
      range = start + length - 1

      stream.load(range + 1).then ->
        charset = getTextEncoding stream.data[offset]
        offset += 1
        console.log 'charset', charset
        if stream.data[range] is 0 and range >= offset
          text = stream.decodeStringSync(charset, offset, range).text
        else
          text = stream.decodeStringSync(charset, offset, range + 1).text
        console.log 'text', text

        switch origType
          when 'TCO', 'TCON'
            return text.replace(/^\(\d+\)/, '')

        return text

getTextEncoding = (byte) ->
  switch byte
    # ISO-8859-1
    when 0x00 then return 'latin1'
    # UTF-16, UTF-16BE
    when 0x01, 0x02 then return 'utf16'
    # UTF-8
    when 0x03 then return 'utf8'
  return 'utf8'

module.exports =
  readData: readData
