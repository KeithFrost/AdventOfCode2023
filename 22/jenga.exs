defmodule Jenga do
  def parse_line(s) do
    case Regex.run(~r/^\s*(\d+),(\d+),(\d+)~(\d+),(\d+),(\d+)\s*$/, s) do
      [_ | coord_strs] ->
        coords = Enum.map(coord_strs, &String.to_integer/1)
        [x0, y0, z0, x1, y1, z1] = coords
        {x0, y0, z0, x1, y1, z1}
    end
  end
  def parse_file(path) do
    File.stream!(path) |>
      Enum.map(&parse_line/1) |>
      Enum.with_index(fn coords, i -> {i + 1, coords} end) |>
      Map.new()
  end
  def zsorted(bricks) do
    Enum.map(bricks, fn {i, coords} ->
      {_, _, z0, _, _, z1} = coords
      {zmin, zmax} = if z0 > z1 do
        {z1, z0}
      else
        {z0, z1}
      end
      {zmin, zmax, i, coords}
    end) |>
      Enum.sort()
  end
  def xy_line(x0, y0, x1, y1) do
    cond do
      x0 == x1 ->
        y0..y1 |> Enum.map(fn y -> {x0, y} end)
      y0 == y1 ->
        x0..x1 |> Enum.map(fn x -> {x, y0} end)
    end
  end
  def stack_zs_bricks(zs_bricks, zmap \\ %{}, stacked \\ %{}, supports \\ %{}) do
    case zs_bricks do
      [{zmin, zmax, i, coords} | zrest] ->
        {x0, y0, z0, x1, y1, z1} = coords
        xys = xy_line(x0, y0, x1, y1)
        zis = xys |>
          Enum.map(fn xy -> Map.get(zmap, xy, {0, 0}) end)
        zh = Enum.map(zis, fn {z, _j} -> z end) |>
          Enum.max()
        sups = Enum.filter(zis, fn {z, _j} -> z == zh end) |>
          Enum.map(fn {_z, j} -> j end) |>
          MapSet.new() |>
          MapSet.to_list()
        delta = zmin - zh - 1
        ncoords = {x0, y0, z0 - delta, x1, y1, z1 - delta}
        stacked = Map.put(stacked, i, ncoords)
        supports = Map.put(supports, i, sups)
        zmap = Enum.reduce(xys, zmap, fn {x, y}, zm ->
          Map.put(zm, {x, y}, {zmax - delta, i}) end)
        stack_zs_bricks(zrest, zmap, stacked, supports)
      [] ->
        {stacked, supports}
    end
  end
  def essential_bricks(supports) do
    Enum.reduce(supports, MapSet.new(), fn {_i, sups}, ess ->
      case sups do
        [j] when j != 0 ->
          MapSet.put(ess, j)
        _ ->
          ess
      end
    end)
  end
  def brick_cascade(falling, supports) do
    add = Enum.filter(supports, fn {i, sups} ->
      (not MapSet.member?(falling, i)) and
      Enum.all?(sups, fn sup -> MapSet.member?(falling, sup) end)
    end) |>
      Enum.map(fn {i, _} -> i end)
    if length(add) == 0 do
      falling
    else
      falling = Enum.reduce(add, falling, fn i, f -> MapSet.put(f, i) end)
      brick_cascade(falling, supports)
    end
  end
end

case System.argv() do
  ["1", path] ->
    bricks = Jenga.parse_file(path)
    zs_bricks = Jenga.zsorted(bricks)
    {stacked, supports} = Jenga.stack_zs_bricks(zs_bricks)
    essential = Jenga.essential_bricks(supports)
    ess_count = MapSet.size(essential)
    total_count = map_size(stacked)
    non_ess_count = total_count - ess_count
    IO.puts("#{total_count} #{ess_count} #{non_ess_count}")
  ["2", path] ->
    bricks = Jenga.parse_file(path)
    zs_bricks = Jenga.zsorted(bricks)
    {stacked, supports} = Jenga.stack_zs_bricks(zs_bricks)
    total = map_size(stacked)
    cascade_sum = Enum.reduce(1..total, 0, fn i, sum ->
      falling = Jenga.brick_cascade(MapSet.new([i]), supports)
      sum + MapSet.size(falling) - 1
    end)
    IO.inspect(cascade_sum)
  [] ->
    :ok
end
