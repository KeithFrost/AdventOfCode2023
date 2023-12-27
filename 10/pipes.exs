defmodule Pipes do
  def parse_line(s, y, map) do
    line_map = String.trim(s) |> to_charlist() |>
      Enum.with_index(fn v, x -> {{x, y}, v} end) |>
      Map.new()
    Map.merge(map, line_map)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.with_index() |>
      Enum.reduce(%{}, fn {s, y}, map -> parse_line(s, y, map) end)
  end
  def start_pos(map) do
    {pos, ?S} = Enum.find(map, fn {_, v} -> v == ?S end)
    pos
  end

  def follow_pipe(candidate, trail, map) do
    {x0, y0} = List.first(trail)
    {x, y} = candidate
    v = Map.get(map, candidate, ?.)
    extend_trail = [candidate | trail]
    if v == ?S do
      extend_trail
    else
      next_candidate =
	case {x - x0, y - y0, v} do
	  {0, 1, ?|}  -> {x, y+1}
	  {0, 1, ?L}  -> {x+1, y}
	  {0, 1, ?J}  -> {x-1, y}
	  {0, -1, ?|} -> {x, y-1}
	  {0, -1, ?F} -> {x+1, y}
	  {0, -1, ?7} -> {x-1, y}
	  {1, 0, ?-}  -> {x+1, y}
	  {1, 0, ?J}  -> {x, y-1}
	  {1, 0, ?7}  -> {x, y+1}
	  {-1, 0, ?-} -> {x-1, y}
	  {-1, 0, ?F} -> {x, y+1}
	  {-1, 0, ?L} -> {x, y-1}
	  _ -> nil
	end
      if next_candidate == nil do
	nil
      else
	follow_pipe(next_candidate, extend_trail, map)
      end
    end
  end

  def left_edges(map) do
    Enum.filter(map, fn {{x, _}, _} -> x == 0 end) |>
      Enum.map(fn {pos, _} -> pos end) |>
      Enum.sort()
  end

  def count_inside(state, loop_set, map) do
    pos = state.pos
    v = Map.get(map, pos)
    if v == nil do
      state.count
    else
      {x, y} = pos
      state = %{state | pos: {x + 1, y}}
      xings = state.xings
      if MapSet.member?(loop_set, pos) do
	pstart = state.pstart
	state =
	  case {v, pstart} do
	    {?-, ?L} -> state
	    {?-, ?F} -> state
	    {?|, nil} -> %{state | xings: xings + 1}
	    {?J, ?L} -> %{state | pstart: nil}
	    {?J, ?F} -> %{state | xings: xings + 1, pstart: nil}
	    {?7, ?L} -> %{state | xings: xings + 1, pstart: nil}
	    {?7, ?F} -> %{state | pstart: nil}
	    {?F, nil} -> %{state | pstart: ?F}
	    {?L, nil} -> %{state | pstart: ?L}
	  end
	count_inside(state, loop_set, map)
      else
	state = if xings > 0 and rem(xings, 2) == 1 do
	  %{state | count: state.count + 1}
	else
	  state
	end
	count_inside(state, loop_set, map)
      end
    end
  end

  def refill_start(loop, map) do
    [{x0, y0}, {x1, y1} | _rest] = loop
    [{xt, yt}, {xn, yn} | _rest] = Enum.reverse(loop)
    if x0 != xt or y0 != yt do
      nil
    else
      deltas = [{xn - x0, yn - y0}, {x1 - x0, y1 - y0}] |> Enum.sort()
      v =
	case deltas do
	  [{-1, 0}, {0, -1}] -> ?J
	  [{-1, 0}, {0, 1}]  -> ?7
	  [{-1, 0}, {1, 0}]  -> ?-
	  [{0, -1}, {0, 1}]  -> ?|
	  [{0, -1}, {1, 0}]  -> ?L
	  [{0, 1}, {1, 0}]   -> ?F
	end
      Map.put(map, {x0, y0}, v)
    end
  end
end

case System.argv() do
  [stage, path] ->
    map = Pipes.parse_file(path)
    start = Pipes.start_pos(map)
    {x, y} = start
    loop = [{x+1, y}, {x-1, y}, {x, y+1}, {x, y-1}] |>
      Enum.find_value(fn candidate ->
	Pipes.follow_pipe(candidate, [start], map) end)
    case stage do
      "1" ->
	IO.inspect(div(length(loop) - 1, 2))
      "2" ->
	map2 = Pipes.refill_start(loop, map)
	loop_set = MapSet.new(loop)
	Pipes.left_edges(map2) |>
	  Enum.map(fn pos ->
	    Pipes.count_inside(
	      %{pos: pos, xings: 0, pstart: nil, count: 0},
	      loop_set, map2)
	  end) |>
	  Enum.sum() |>
	  IO.inspect()
    end
  _ ->
    :ok
end
