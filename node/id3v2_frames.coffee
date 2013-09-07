
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



