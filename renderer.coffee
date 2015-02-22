Path = require 'paths-js/path'
SVG = require 'svg.coffee'

remove_all_children = (node) ->
  while node.firstChild
    node.removeChild node.firstChild

class Renderer
  constructor: (@tile_size) ->
    @N = 8
    [w, h] = [(@N * tile_size), (@N * tile_size)]
    @root = SVG.root w, h

    @bg = SVG.g {}
    @fg = SVG.g {}

    @root.appendChild SVG.g {
      transform: "scale(1, -1) translate(0, -#{h})"
    }, [@bg, @fg]

  clear: (preserve_bg = true) ->
    if not preserve_bg
      remove_all_children @bg
    remove_all_children @fg

  render_background: ->
    for i in [0...@N]
      for j in [0...@N]
        [x, y] = [i * @tile_size, j * @tile_size]
        d = 5
        border = SVG.util.rounded_rect_path (x + d), (y + d),
          (@tile_size - 2 * d), (@tile_size - 2 * d), 3
        box = SVG.path {
          d: border.print()
          fill: 'gray'
          stroke: 'black'
        }
        @bg.appendChild box

  render_restaurant: (restaurant) ->
    loc = restaurant.location
    [rx, ry] = [loc.x * @tile_size, loc.y * @tile_size]

    ts = @tile_size
    outline = Path().moveto(-0.55 * ts, 0.15 * ts)
      .lineto(-0.15 * ts, 0.15 * ts)
      .lineto(-0.15 * ts, 0.55 * ts)
      .lineto(-0.35 * ts, 0.75 * ts)
      .lineto(-0.55 * ts, 0.55 * ts)
      .closepath()
    r_graphic = SVG.path {
      d: outline.print()
      fill: 'red'
      stroke: 'black'
    }
    num_orders = restaurant.num_untaken_orders()
    r_txt = SVG.text {
      x: -0.45 * ts, y: -0.45 * ts, fill: 'black'
      transform: "scale(1, -1)"
    }
    r_txt.innerHTML = '' + num_orders

    @fg.appendChild (SVG.g {
      transform: "translate(#{rx}, #{ry})"
    }, [r_graphic, r_txt])

  render_car: (car) ->
    pos = car.approaching.shift car.dir,
      (car.moved_ratio - 1)
    theta = if car.dir in ['up', 'down']
      90
    else
      0

    [cw, ch] = [@tile_size * 0.5, @tile_size * 0.3]
    car_graphic = SVG.path {
      d: (SVG.util.rounded_rect_path (-cw/2), (-ch/2), cw, ch, 3).print()
      fill: 'blue'
      stroke: 'black'
    }
    r = @tile_size * 0.05
    gap = @tile_size * 0.02
    dots = for order, idx in car.orders
      SVG.circle {
        r: r
        cx: (-cw/2) + 4 * gap + (2 * r + gap) * idx
        cy: (ch/2) - 4 * gap
        fill: 'green'
      }

    [cx, cy] = [pos.x * @tile_size, pos.y * @tile_size]
    car_svg = SVG.g {
      transform: "translate(#{cx}, #{cy}) rotate(#{theta})"
    }, [car_graphic].concat(dots)
    @fg.appendChild car_svg


exports.Renderer = Renderer