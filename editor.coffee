


class YmacsEditor
  constructor: (@_w, @_h, @_initial_text = "") ->
    @_elt = null
    @_sending = false

  elt: -> @_elt

  init: (parent, cb) ->
    iframe_html = "<iframe src=\"editors/ymacs/ymacs.html\" width=\"#{@_w}\" height=\"#{@_h}\"></iframe>"
    @_elt = ($ iframe_html)
    @_elt.on 'load', =>
      @send_message 'init', @_initial_text, cb
    parent.append @_elt

  send_message: (prefix, mesg, cb) ->
    if @_sending
      throw new Error "Already sending a message!"
    @_sending = true

    old_on_mesg = window.onmessage
    window.onmessage = (e) =>
      @_sending = false
      window.onmessage = old_on_mesg
      return cb (e.data.slice (prefix.length + 1))

    iframe = @_elt.get(0)
    iframe.contentWindow.postMessage "#{prefix}:#{mesg}", '*'

  get_text: (cb) ->
    @send_message 'get-code', '', cb


exports.YmacsEditor = YmacsEditor