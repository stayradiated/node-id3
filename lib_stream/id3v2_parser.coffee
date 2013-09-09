
readData = (stream, type, offset, length, flags, major=3) ->
  
  origType = type
  if type[0] is 'T'
    type = 'T*'

  switch type

    # Album art
    when 'PIC', 'APIC'
      range = offset + length
      stream.load(range).then ->

        charset  = getTextEncoding stream.data[offset++]
        pic      = {}

        switch major

          when 2
            pic.format = stream.data.toString 'ascii', offset, offset + 3
            offset    += 4

          when 3, 4
            end        = stream.findZeroSync(offset, range)
            pic.format = stream.decodeStringSync(charset, offset, end)
            offset    += pic.format.length + 1
            pic.format = pic.format.text

        pic.type = PICTURE_TYPE[ stream.data[offset++] ]

        end             = stream.findZeroSync(offset, range)
        pic.description = stream.decodeStringSync(charset, offset, end)
        offset         += pic.description.length + 1
        pic.description = pic.description.text

        # Save memory by only duplicating the image data if the user wants to
        Object.defineProperty pic, 'data',
          get: -> data or data = stream.data.slice(offset, range)

        return pic

    # Comments
    when 'COM', 'COMM'
      range = offset + length
      stream.load(range).then ->

        charset = getTextEncoding stream.data[offset++]
        comment = {}

        # Language
        comment.language = stream.data.toString('ascii', offset, offset += 3)

        # Short description
        end                       = stream.findZeroSync(offset, range)
        comment.short_description = stream.decodeStringSync(charset, offset, end)
        offset                   += comment.short_description.length + 1
        comment.short_description = comment.short_description.text

        # Text
        comment.text = stream.decodeStringSync(charset, offset, range).text

        return comment

    # ???
    when 'CNT', 'PCNT'
      return stream.UINT32_BE(offset)

    # Text?
    when 'T*'
      range = offset + length - 1
      stream.load(range + 1).then ->

        charset = getTextEncoding stream.data[offset++]

        if stream.data[range] is 0 and range >= offset
          text = stream.decodeStringSync(charset, offset, range).text
        else
          text = stream.decodeStringSync(charset, offset, range + 1).text

        switch origType
          when 'TCO', 'TCON' then return text.replace(/^\(\d+\)/, '')

        return text

    # Lyrics
    when 'ULT', 'USLT'
      range = offset + length
      stream.load(range).then ->

        charset = getTextEncoding stream.data[offset++]
        lyrics = {}

        lyrics.language = stream.data.toString('ascii', offset, offset += 3)

        end               = stream.findZeroSync(offset, range)
        lyrics.descriptor = stream.decodeStringSync(charset, offset, end)
        offset           += lyrics.descriptor.length
        lyrics.descriptor = lyrics.descriptor.text

        lyrics.text = stream.decodeStringSync(charset, offset, range)

        return lyrics

    else
      # console.log type
      # Promise fallback
      return stream.getByte(0).then -> return null


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

PICTURE_TYPE = [
  '32x32 pixels \'file icon\' (PNG only)',
  'Other file icon',
  'Cover (front)',
  'Cover (back)',
  'Leaflet page',
  'Media (e.g. lable side of CD)',
  'Lead artist/lead performer/soloist',
  'Artist/performer',
  'Conductor',
  'Band/Orchestra',
  'Composer',
  'Lyricist/text writer',
  'Recording Location',
  'During recording',
  'During performance',
  'Movie/video screen capture',
  'A bright coloured fish',
  'Illustration',
  'Band/artist logotype',
  'Publisher/Studio logotype'
]
