{EventEmitter} = require 'events'
assert = require 'assert'

{YmacsEditor} = require 'editor.coffee'
{Renderer} = require 'renderer.coffee'
{TimerLoop, EventQueue} = require 'util.coffee'

opposite = (dir) ->
  l = ['up', 'left', 'down', 'right', 'up', 'left']
  return l[l.indexOf(dir) + 2]
rotate_left = (dir) ->
  l = ['up', 'left', 'down', 'right', 'up']
  return l[l.indexOf(dir) + 1]
rotate_right = (dir) ->
  l = ['up', 'right', 'down', 'left', 'up']
  return l[l.indexOf(dir) + 1]

class Point
  constructor: (@x, @y) ->

  equals: (other) ->
    return @x == other.x and @y == other.y

  shift: (dir, amt = 1) ->
    switch dir
      when 'up' then return (new Point @x, (@y + amt))
      when 'down' then return (new Point @x, (@y - amt))
      when 'left' then return (new Point (@x - amt), @y)
      when 'right' then return (new Point (@x + amt), @y)
      else throw new Error "Invalid shift direction! #{dir}"


class Animation
  constructor: (@eq, @cb) ->
    @bindings = {}
    @duration = 1000 # TODO
    @timeout_id = null

  apply_bindings: (obj) ->
    r = 1 - (@eq.time_left @timeout_id) / @duration
    for k, v of @bindings
      obj[k] = v(r)

  run: ->
    @timeout_id = @eq.set_timeout @duration, =>
      @cb()

class DeliveryAnimation extends Animation
  constructor: (@eq, @cb) ->
    super @eq, @cb
    @duration = 2000
    @bindings =
      moved_ratio: (r) ->
        [a, b] = [0.4, 0.6]
        if r < a
          return 0.5 - 0.5 * (a - r) * (a - r) / a / a
        if r > b
          return 0.5 + 0.5 * (r - b) * (r - b) / (1 - b) / (1 - b)
        return 0.5

class PickupAnimation extends Animation
  constructor: (@eq, @cb) ->
    super @eq, @cb
    @duration = 2000
    @bindings =
      moved_ratio: (r) ->
        [a, b] = [0.4, 0.6]
        if r < a
          return 0.5 - 0.5 * (a - r) * (a - r) / a / a
        if r > b
          return 0.5 + 0.5 * (r - b) * (r - b) / (1 - b) / (1 - b)
        return 0.5

class MoveAnimation extends Animation
  constructor: (@eq, @cb) ->
    super @eq, @cb
    @duration = 1000
    @bindings =
      moved_ratio: (r) -> r



class Car extends EventEmitter
  @wrap = (car, world) ->
    return {
      direction: -> return car.dir
      set_next_direction: (dir) ->
        car.next_dir = dir
      coming_from: -> return (car.approaching.shift car.dir, -1)
      approaching: -> return car.approaching
      items: -> car.items.slice()

      deliver: ->
        assert car.status is 'drive'
        car.status = 'deliver'
      pickup: (order_id) ->
        console.log 'picking up!'
        assert car.status is 'drive'
        for r in world.restaurants
          if not (car.approaching.equals r.location)
            continue
          # TODO: do this during the pickup animation
          order = r.take order_id
          car.orders.push order
          car.status = 'pickup'
          return
        console.warn 'No pickup possible!'

      on: (evt, handler) ->
        if evt not in ['approaching']
          throw new Error "#{evt} is not a valid event!"
        car.on evt, handler
    }

  constructor: (@eq) ->
    @orders = []

    @moved_ratio = 1.0
    @dir = 'right'
    @next_dir = 'right'
    @approaching = new Point 5, 5 # TODO

    @animation = null
    @status = 'drive'

  complete_move: ->
    new_dir = @next_move()
    @moves = @moves.slice 1

    old_loc = @next
    @next = old_loc.shift new_dir

    @dir = new_dir
    @moved_ratio = 0.0

    @controls.location_changed.call @, old_loc

  do_next_animation: (cb) ->
    @animation = if @status is 'deliver'
      new DeliveryAnimation @eq, =>
        delivery = null # TODO
        @status = 'drive'
        @emit 'delivery_complete', delivery
        cb()
    else if @status is 'pickup'
      new PickupAnimation @eq, =>
        @status = 'drive'
        @emit 'pickup_complete' # TODO: include order
        cb()
    else
      new MoveAnimation @eq, =>
        cb()
    @animation.run()

  start: ->
    while true
      await @do_next_animation defer()
      @animation = null

      @next_dir ?= @dir
      @approaching = @approaching.shift @next_dir
      @dir = @next_dir
      @next_dir = null
      @moved_ratio = 0.0

      # TODO: might be nice to emit this closer to actually reaching
      # the target
      @emit 'approaching', @approaching
      # next dir may be different now..


class Restaurant extends EventEmitter
  @wrap = (restaurant) ->
    return {
      location: -> return restaurant.location
      orders: -> return (o for _, o of restaurant.orders)
      on: (evt, handler) ->
        if evt not in ['order']
          throw new Error "#{evt} is not a valid event!"
        restaurant.on evt, handler
    }

  constructor: (@eq, @location) ->
    @_next_id = 0
    @orders = {}

  num_taken_orders: ->
    return (o for _, o of @orders when o.taken).length
  num_untaken_orders: ->
    return (o for _, o of @orders when not o.taken).length

  start: ->
    while true
      await @eq.set_timeout 10000, defer()
      order =
        id: @_next_id++
        location: new Point 3, 3
        time: @eq.now()
        taken: false
      @orders[order.id] = order
      @emit 'order', order

  take: (order_id) ->
    order = @orders[order_id]
    if not order?
      console.log "orders", @orders
      throw new Error "invalid order id"

    assert not order.taken
    order.taken = true
    return order

  fulfill: (order_id) ->
    delete @orders[order_id]



class World
  constructor: (@eq) ->
    @restaurants = [
      new Restaurant @eq, (new Point 5, 5)
    ]
    @wrapped_restaurants = ((Restaurant.wrap r) for r in @restaurants)

    @cars = [new Car @eq]
    @wrapped_cars = ((Car.wrap car, @) for car in @cars)

  list_cars: -> return @wrapped_cars
  list_restaurants: -> return @wrapped_restaurants

  tick: (ms) ->
    @eq.tick ms
    for car in @cars
      if car.animation?
        car.animation.apply_bindings car



start = (world, renderer) ->
  for car in world.cars
    car.start()
  for restaurant in world.restaurants
    restaurant.start()

  tl = new TimerLoop 30
  tl.run (ms) =>
    world.tick ms

    renderer.clear()
    for car in world.cars
      renderer.render_car car
    for restaurant in world.restaurants
      renderer.render_restaurant restaurant

window.onload = ->
  eq = new EventQueue

  world = new World eq
  renderer = new Renderer 60
  renderer.render_background()
  ($ '#left-column').append renderer.root

  DEFAULT_CONTROLS =
    init_cars: (cars) ->
    init_restaurants: (restaurants) ->
  DEMO_CODE = """
  {
    init_restaurants: function(restaurants) {
      window.r = restaurants[0]
    },

    init_cars: function(cars) {
      var car = cars[0];
      car.on('approaching', function(loc) {
        var old_dir = car.direction();
        car.set_next_direction(rotate_right(old_dir));

        if (car.approaching().equals(r.location())) {
          var orders = r.orders();
          for (var i = 0; i < orders.length; i++) {
            var order = orders[i];
            if (!order.taken) {
              car.pickup(order.id);
              return;
            }
          }
        }

        if (old_dir === 'up') {
          car.deliver();
        }
      });
    }
  }
  """

  editor = new YmacsEditor 600, 500, DEMO_CODE
  await editor.init ($ '#right-column'), defer()

  start_button = ($ '<button>Start</button>').click =>
    await editor.get_text defer code
    console.log 'code was', code

    try
      util =
        rotate_right: rotate_right
      eval "code = #{code};"
    catch e
      throw e
      return

    console.log 'code is', code

    for k, v of DEFAULT_CONTROLS
      code[k] ?= v

    code.init_cars world.list_cars()
    code.init_restaurants world.list_restaurants()
    start world, renderer
  ($ '#left-column').append start_button
