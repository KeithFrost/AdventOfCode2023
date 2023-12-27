defmodule Rays do
  def parse_line(s, y) do
    String.trim(s) |> to_charlist() |> Enum.with_index(fn v, x ->
      {{x, y}, v} end)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.with_index() |> Enum.flat_map(fn {s, y} ->
      parse_line(s, y) end) |> Map.new()
  end
  def trace_ray({dir, x, y}, map, raymap) do
    m = Map.get(map, {x, y})
    r0 = Map.get(raymap, {x, y}, [])
    if m == nil or Enum.any?(r0, fn d -> d == dir end) do
      {raymap, []}
    else
      raymap = Map.put(raymap, {x, y}, [dir | r0])
      cond do
	m == ?| and (dir == ?< or dir == ?>) ->
	  {raymap, [{?v, x, y + 1}, {?^, x, y - 1}]}
	m == ?- and (dir == ?^ or dir == ?v) ->
	  {raymap, [{?<, x - 1, y}, {?>, x + 1, y}]}
	true ->
	  ndir =
	    case {dir, m} do
	      {?>, ?.} -> ?>
	      {?>, ?-} -> ?>
	      {?>, ?\\} -> ?v
	      {?>, ?/} -> ?^
	      {?<, ?.} -> ?<
	      {?<, ?-} -> ?<
	      {?<, ?\\} -> ?^
	      {?<, ?/} -> ?v
	      {?^, ?.} -> ?^
	      {?^, ?|} -> ?^
	      {?^, ?\\} -> ?<
	      {?^, ?/} -> ?>
	      {?v, ?.} -> ?v
	      {?v, ?|} -> ?v
	      {?v, ?\\} -> ?>
	      {?v, ?/} -> ?<
	    end
	  {xn, yn} =
	    case ndir do
	      ?> -> {x + 1, y}
	      ?< -> {x - 1, y}
	      ?^ -> {x, y - 1}
	      ?v -> {x, y + 1}
	    end
	  trace_ray({ndir, xn, yn}, map, raymap)
      end
    end
  end
  def gen_raymap(starts, map, raymap \\ %{}) do
    case starts do
      [] ->
	raymap
      [start | rstarts] ->
	{raymap, nstarts} = trace_ray(start, map, raymap)
	gen_raymap(nstarts ++ rstarts, map, raymap)
    end
  end
  def count_energized(raymap) do
    Enum.reduce(raymap, 0, fn {{_x, _y}, dirs}, sum ->
      if length(dirs) > 0 do
	sum + 1
      else
	sum
      end
    end)
  end
  def possible_starts(map) do
    {x_max, y_max} = Enum.reduce(map, {0, 0}, fn {{x, y}, _}, {xm, ym} ->
      {max(x, xm), max(y, ym)} end)
    Enum.flat_map(0..y_max, fn y -> [{?>, 0, y}, {?<, x_max, y}] end) ++
      Enum.flat_map(0..x_max, fn x -> [{?v, x, 0}, {?^, x, y_max}] end)
  end
end


case System.argv() do
  ["1", path] ->
    map = Rays.parse_file(path)
    raymap = Rays.gen_raymap([{?>, 0, 0}], map)
    IO.inspect(Rays.count_energized(raymap))
  ["2", path] ->
    map = Rays.parse_file(path)
    max_energized = Rays.possible_starts(map) |> Enum.map(fn start ->
      Rays.count_energized(Rays.gen_raymap([start], map)) end) |>
      Enum.max()
    IO.inspect(max_energized)
  [] ->
    :ok
end
