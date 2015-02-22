class EventQueue
  constructor: ->
    @_next_id = 0
    @_now = 0
    @_timeouts = []

  now: -> @_now

  tick: (ms) ->
    while @_timeouts.length > 0
      to = @_timeouts[0]
      to_wait = to.expiry - @_now

      if to_wait > ms
        @_now += ms
        return

      @_now += to_wait
      ms -= to_wait
      @_timeouts = @_timeouts.slice 1
      to.cb()
    @_now += ms

  set_timeout: (ms, cb) ->
    new_to =
      id: @_next_id++
      expiry: @_now + ms
      cb: cb

    for to, idx in @_timeouts
      if to.expiry <= new_to.expiry
        continue
      @_timeouts.splice idx, 0, new_to
      return new_to.id

    @_timeouts.push new_to
    return new_to.id

  time_left: (timeout_id) ->
    for to in @_timeouts
      if to.id is timeout_id
        return to.expiry - @_now
    throw new Error "Couldn't find timeout id #{timeout_id}!"

class TimerLoop
  constructor: (@tick_length) ->
    @_timeout_id = null

  run: (fn) ->
    last = (new Date).valueOf()
    on_tick = =>
      now = (new Date).valueOf()
      fn (now - last)
      last = now
      @_timeout_id = setTimeout on_tick, @tick_length
    on_tick()

  stop: ->
    clearTimeout @_timeout_id


exports.EventQueue = EventQueue
exports.TimerLoop = TimerLoop