ID3 = require '../node/id3'

# id3_3v1 = new ID3 "#{ __dirname }/sample3v1.mp3"
id3_3v2 = new ID3 "#{ __dirname }/sample3v2.mp3"
# id3_4   = new ID3 "#{ __dirname }/sample4.m4a"

id3_3v2.on 'ready', ->
  id3_3v2.parse()
