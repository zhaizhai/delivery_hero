assert = require 'assert'
Path = require 'paths-js/path'

class Point
  constructor: (@x, @y) ->

class SVG
  # TODO: is there something more recent?
  SVG_NS = "http://www.w3.org/2000/svg"
  MOUSE_EVTS = [
    'mouseover', 'mouseout', 'mouseenter', 'mouseleave',
    'click'
  ]
  PRIMITIVES = [
    'g', 'circle', 'path', 'animate', 'text'
  ]

  create_elt = (type, attrs, children = []) ->
    ret = document.createElementNS SVG_NS, type
    for k, v of attrs
      if k in MOUSE_EVTS
        do (v) ->
          ret.addEventListener k, (args...) ->
            return v.apply ret, args
        continue
      ret.setAttribute k, v

    for child in children
      ret.appendChild child
    return ret

  @attrs = (elt, new_attrs) ->
    for k, v of new_attrs
      elt.setAttribute k, v
    return elt

  @root = (width, height) ->
    ret = document.createElementNS SVG_NS, 'svg'
    ret.setAttribute 'width', width
    ret.setAttribute 'height', height
    return ret

  make_primitive = (prim) =>
    @[prim] = (attrs, children) ->
      create_elt prim, attrs, children
  for prim in PRIMITIVES
    make_primitive prim


to_radians = (deg) -> Math.PI * deg / 180

exports.util =
  arrow: (p, opts) ->
    {tip, length, angle, direction} = opts

    assert (tip? and length? and angle? and
            direction? and (tip instanceof Point))

    direction = to_radians direction
    angle = to_radians angle

    th1 = Math.PI + direction - angle
    start = tip.shift (length * (Math.cos th1)),
              (length * (Math.sin th1))
    th2 = Math.PI + direction + angle
    end = tip.shift (length * (Math.cos th2)),
              (length * (Math.sin th2))

    p = p.moveto(start).lineto(tip).lineto(end)
    return p

  make_closed_path: (pts) ->
    ret = Path().moveto pts[0]
    for pt in pts[1..]
      ret = ret.lineto pt
    return ret.closepath().print()

  rounded_rect_path: (x, y, w, h, r) ->
    return Path().moveto(x + w - r, y)
      .arc(r, r, 0, 0, 1, x + w, y + r)
      .lineto(x + w, y + h - r)
      .arc(r, r, 0, 0, 1, x + w - r, y + h)
      .lineto(x + r, y + h)
      .arc(r, r, 0, 0, 1, x, y + h - r)
      .lineto(x, y + r)
      .arc(r, r, 0, 0, 1, x + r, y)
      .closepath()

  bezier: (prevpath, pts) ->
    if pts.length < 2
      throw new Error "Need at least two points!"
    [x0, y0, vx0, vy0] = pts[0]
    [x1, y1, vx1, vy1] = pts[1]
    ret = if prevpath?
      prevpath.lineto(x0, y0)
    else
      Path().moveto(x0, y0)
    ret = ret.curveto(
        x0 + vx0, y0 + vy0,
        x1 - vx1, y1 - vy1,
        x1, y1
      )
    for [x, y, vx, vy] in pts[2..]
      ret = ret.smoothcurveto(x - vx, y - vy, x, y)
    return ret


for k, v of SVG
  exports[k] = v
