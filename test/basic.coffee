ID3 = require '../lib_stream/id3'
fs = require 'fs'

path = "/home/stayrad/Projects/Groovy/cache/1342693.mp3"

file = new ID3(path)
file.on 'ready', ->
  file.parse().then ->
    console.log file

# Writing to an arbitrary position in a file is possible!
# 
# fs.write(path, data, data_i, data_length, fs_position)
