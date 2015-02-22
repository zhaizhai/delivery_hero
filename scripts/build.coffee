fs = require 'fs'
iced = require 'iced-coffee-script'
browserify = require 'browserify'
through = require 'through'

b = browserify()

transform_fn = (file) ->
  data = ''
  write = (buf) ->
    data += buf
  end = ->
    try
      compiled_src = iced.compile data
    catch e
      console.error "Couldn't compile #{file}"
      throw e

    @queue compiled_src
    @queue null
  return (through write, end)

[_, _, source_filename] = process.argv

b.transform transform_fn
b.add source_filename
b.bundle (err, js_buf) ->
  throw err if err
  js_string = js_buf.toString()
  console.log js_string


