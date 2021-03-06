{EventEmitter} = require 'events'
Stream = require './stream'
id3v1  = require './id3v1'
id3v2  = require './id3v2'

isArray = Array.isArray.bind(Array)

class ID3File extends EventEmitter

  constructor: (@path) ->
    @stream = new Stream(@path)
    @getID3Version().then (@version) =>
      if @version is 'id3v1'
        console.log @path
      @emit 'ready'

  getID3Version: () ->
    @stream.range(0, 11).then (buffer) ->
      if 'ID3' is buffer.toString('binary', 0, 3)
        return 'id3v2'
      else if 'ftypM4A' is buffer.toString('binary', 4, 11)
        return 'id4'
      return 'id3v1'

  parse: () ->
    @getTags().then (frames) =>
      @tags = frames

  get: (name) ->
    if not @tags? then return null
    if @version in ['id3v1', 'id4']
      return @tags[name] or null
    else
      if ID3v2_ALIAS.hasOwnProperty name
        name = ID3v2_ALIAS[name]
      if isArray(name)
        for tag in name
          if @tags[tag]
            if isArray(@tags[tag])
              data = @tags[tag][0].data
            else
              data = @tags[tag].data
            return data
      else if @tags.hasOwnProperty name
        data = @tags[name].data
        return data
    return null

  getTags: (version=@version) ->
    switch version
      when 'id3v1'
        return id3v1.readTags.call(this)
      when 'id3v2'
        return id3v2.readTags.call(this)
      when 'id4'
        return id4.readTags.call(this)
      else
        return {}

ID3v2_ALIAS =
  'title'  : ['TIT2', 'TT2'],
  'artist' : ['TPE1', 'TP1'],
  'album'  : ['TALB', 'TAL'],
  'year'   : ['TYER', 'TYE'],
  'comment': ['COMM', 'COM'],
  'track'  : ['TRCK', 'TRK'],
  'genre'  : ['TCON', 'TCO'],
  'picture': ['APIC', 'PIC'],
  'lyrics' : ['USLT', 'ULT']

module.exports = ID3File
