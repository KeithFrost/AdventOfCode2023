defmodule Lagoon do
  def parse_line(s) do
    case Regex.run(~r/^\s*([LRUD])\s+(\d+)\s+\((#[0-9a-f]+)\)\s*$/, s) do
      [_, dir, steps, color] ->
        {String.to_atom(dir), String.to_integer(steps), color}
    end
  end
  def fix_parse({_dir, _steps, color}) do
    case Regex.run(~r/^#([0-9a-f]+)([0-3])$/, color) do
      [_, steps_str, dir_digit] ->
        ndir = case dir_digit do
                 "0" -> :R
                 "1" -> :D
                 "2" -> :L
                 "3" -> :U
               end
        {ndir, String.to_integer(steps_str, 16)}
    end
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.map(&parse_line/1)
  end
  def boundary_poly(plan) do
    Enum.reduce(plan, [{0, 0}], fn {dir, steps}, path ->
      {x, y} = List.first(path)
      next =
        case dir do
          :L -> {x - steps, y}
          :R -> {x + steps, y}
          :U -> {x, y - steps}
          :D -> {x, y + steps}
        end
      [next | path]
    end) |> Enum.reverse()
  end
  def shoelace_area2(polygon) do
    sum = Enum.chunk_every(polygon, 2, 1, :discard) |>
      Enum.reduce(0, fn [{x, y}, {xn, yn}], s ->
        s + (y + yn) * (x - xn)
      end)
    abs(sum)
  end
  def edge_length(plan) do
    Enum.reduce(plan, 0, fn {_dir, steps}, s ->
      s + steps
    end)
  end
  def boundary(plan) do
    Enum.reduce(plan, [{{0, 0}, "#000000"}], fn {dir, steps, color}, path ->
      {{x, y}, _} = List.first(path)
      extend =
        case dir do
          :L ->
          (x - steps)..(x - 1) |> Enum.map(fn xx -> {{xx, y}, color} end)
          :R ->
          (x + steps)..(x + 1) |> Enum.map(fn xx -> {{xx, y}, color} end)
          :U ->
          (y - steps)..(y - 1) |> Enum.map(fn yy -> {{x, yy}, color} end)
          :D ->
          (y + steps)..(y + 1) |> Enum.map(fn yy -> {{x, yy}, color} end)
        end
      extend ++ path
    end) |> Enum.reverse()
  end
  def bound_rect(boundary) do
    {{xmax, ymax}, _} = Enum.reduce(boundary, fn {{x, y}, _}, {{xm, ym}, c} ->
      {{max(x, xm), max(y, ym)}, c} end)
    {{xmin, ymin}, _} = Enum.reduce(boundary, fn {{x, y}, _}, {{xm, ym}, c} ->
      {{min(x, xm), min(y, ym)}, c} end)
    {xmin, xmax, ymin, ymax}
  end
  def fill({x, y}, filled, exclude, bounds) do
    {xmin, xmax, ymin, ymax} = bounds
    cond do
      x < xmin or x > xmax or y < ymin or y > ymax ->
        filled
      MapSet.member?(exclude, {x, y}) ->
        filled
      MapSet.member?(filled, {x, y}) ->
        filled
      true ->
        filled = MapSet.put(filled, {x, y})
        [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}] |>
          Enum.reduce(filled, fn pos, f -> fill(pos, f, exclude, bounds) end)
    end
  end
  def fill_area(boundary) do
    bounds = bound_rect(boundary)
    {xmin, xmax, ymin, ymax} = bounds
    brect =
      Enum.flat_map(xmin..xmax, fn x -> [{x, ymin}, {x, ymax}] end) ++
      Enum.flat_map(ymin..ymax, fn y -> [{xmin, y}, {xmax, y}] end)
    bset = Enum.map(boundary, fn {{x, y}, _} -> {x, y} end) |> MapSet.new()
    outside = Enum.reduce(brect, MapSet.new(), fn pos, filled ->
      fill(pos, filled, bset, bounds) end)
    (ymax - ymin + 1) * (xmax - xmin + 1) - MapSet.size(outside)
  end
end


case System.argv() do
  ["1", path] ->
    plan = Lagoon.parse_file(path)
    plan2 = Enum.map(plan, fn {x, y, _color} -> {x, y} end)
    bpoly = Lagoon.boundary_poly(plan2)
    shoelace2 = Lagoon.shoelace_area2(bpoly)
    IO.inspect(shoelace2)
    edge_len = Lagoon.edge_length(plan2)
    IO.inspect(edge_len)
    IO.inspect(div(edge_len + shoelace2, 2) + 1)
    boundary = Lagoon.boundary(plan)
    IO.inspect(Lagoon.fill_area(boundary))
  ["2", path] ->
    plan2 = Lagoon.parse_file(path) |> Enum.map(&Lagoon.fix_parse/1)
    bpoly = Lagoon.boundary_poly(plan2)
    shoelace2 = Lagoon.shoelace_area2(bpoly)
    IO.inspect(shoelace2)
    edge_len = Lagoon.edge_length(plan2)
    IO.inspect(edge_len)
    IO.inspect(div(edge_len + shoelace2, 2) + 1)
  [] ->
    :ok
end
