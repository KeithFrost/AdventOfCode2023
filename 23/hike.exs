defmodule Hike do
  def parse_line(s, y) do
    String.trim(s) |>
      to_charlist() |>
      Enum.with_index(fn c, x ->
        cc =
          case c do
            ?. -> ?.
            ?^ -> ?^
            ?v -> ?v
            ?> -> ?>
            ?< -> ?<
            ?# -> ?+
          end
        {{x, y}, cc}
      end)
  end
  def parse_file(path) do
    File.stream!(path) |>
      Enum.with_index(&parse_line/2) |>
      List.flatten() |>
      Map.new()
  end
  def bounds(map) do
    posns = Map.keys(map)
    {x1, y1} =
      Enum.reduce(posns, fn {x, y}, {x1, y1} ->
        {max(x, x1), max(y, y1)} end)
    {x0, y0} =
      Enum.reduce(posns, fn {x, y}, {x1, y1} ->
        {min(x, x1), min(y, y1)} end)
    {x0, x1, y0, y1}
  end
  def terminals(map, bounds) do
    {x0, x1, y0, y1} = bounds
    xa = Enum.find(x0..x1, fn x ->
      Map.get(map, {x, y0}, ?+) == ?. end)
    xz = Enum.find(x0..x1, fn x ->
      Map.get(map, {x, y1}, ?+) == ?. end)
    {{xa, y0}, {xz, y1}}
  end
  def allow_uphills(map, bounds) do
    {x0, x1, y0, y1} = bounds
    Enum.reduce(x0..x1, map, fn x, m ->
      Enum.reduce(y0..y1, m, fn y, mm ->
        if Map.has_key?(mm, {x, y}) do
          Map.update!(mm, {x, y}, fn c ->
            if c == ?^ or c == ?v or c == ?> or c == ?< do
              ?.
            else
              c
            end
          end)
        else
          mm
        end
      end)
    end)
  end
  def longest_path(pos, goal, map, taken \\ MapSet.new()) do
    taken = MapSet.put(taken, pos)
    if pos == goal do
      taken
    else
      {x, y} = pos
      steps =
        [{1, 0}, {-1, 0}, {0, 1}, {0, -1}] |>
        Enum.filter(fn diff ->
          {dx, dy} = diff
          npos = {x + dx, y + dy}
          mapv = Map.get(map, npos, ?+)
          map_okay =
            case mapv do
              ?+ -> false
              ?. -> true
              ?v -> diff == {0, 1}
              ?^ -> diff == {0, -1}
              ?> -> diff == {1, 0}
              ?< -> diff == {-1, 0}
            end
          (map_okay and not
            MapSet.member?(taken, {x + dx, y + dy}))
        end)
      case steps do
        [] ->
          MapSet.new()
        [{dx, dy}] ->
          longest_path({x + dx, y + dy}, goal, map, taken)
        _ ->
          # IO.puts("#{length(steps)} {#{x}, #{y}} #{MapSet.size(taken)}")
          paths =
            Enum.map(steps, fn {dx, dy} ->
              longest_path({x + dx, y + dy}, goal, map, taken)
              end)
          Enum.max_by(paths, fn t -> MapSet.size(t) end)
      end
    end
  end
  def show_path(path, bounds, map) do
    {x0, x1, y0, y1} = bounds
    Enum.each(y0..y1, fn y ->
      row =
        Enum.map(x0..x1, fn x ->
          pos = {x, y}
          c = Map.get(map, pos, ?+)
          if MapSet.member?(path, pos) do
            ?@
          else
            c
          end
        end)
      IO.puts(row)
    end)
  end
  def allowed_deltas(pos, map, excluded) do
    {x, y} = pos
    [{1, 0}, {-1, 0}, {0, 1}, {0, -1}] |>
      Enum.filter(fn {dx, dy} ->
        npos = {x + dx, y + dy}
        Map.get(map, npos) == ?. and not MapSet.member?(excluded, npos)
      end)
  end
  def follow_trail(pos, delta, map, taken, trail) do
    {dx, dy} = delta
    {x, y} = pos
    npos = {x + dx, y + dy}
    trail = MapSet.put(trail, npos)
    if MapSet.member?(taken, npos) do
      {npos, trail}
    else
      case allowed_deltas(npos, map, trail) do
        [] ->
          {npos, trail}
        [delta] ->
          follow_trail(npos, delta, map, taken, trail)
        _ ->
          {npos, trail}
      end
    end
  end
  def to_graph(starts, map, taken \\ MapSet.new(), edges \\ []) do
    case starts do
      [] ->
        edges
      [spos | rest] ->
        trail0 = MapSet.new([spos])
        {taken, new_edges, new_starts} =
          allowed_deltas(spos, map, taken) |>
          Enum.reduce({taken, [], []}, fn delta, {tkn, nedges, nstarts} ->
            {epos, trail} = follow_trail(spos, delta, map, tkn, trail0)
            tkn = MapSet.union(tkn, trail)
            if epos == spos do   # Loop trail, ignore
              {tkn, nedges, nstarts}
            else
              edge = {spos, epos, MapSet.size(trail) - 1}
              {tkn, [edge | nedges], [epos | nstarts]}
            end
          end)
        to_graph(new_starts ++ rest, map, taken, new_edges ++ edges)
    end
  end
  def edge_map(edges) do
    Enum.reduce(edges, %{}, fn {pos1, pos2, steps}, em ->
      l1 = [{pos2, steps} | Map.get(em, pos1, [])]
      l2 = [{pos1, steps} | Map.get(em, pos2, [])]
      Map.put(em, pos1, l1) |> Map.put(pos2, l2)
    end)
  end
  def longest_path_em(start, goal, emap, visited \\ MapSet.new()) do
    visited = MapSet.put(visited, start)
    if start == goal do
      0
    else
      edges = Map.get(emap, start, []) |>
        Enum.filter(fn {node, _w} ->
          not MapSet.member?(visited, node)
        end)
      lengths = Enum.map(edges, fn {node, w} ->
        w + longest_path_em(node, goal, emap, visited)
      end)
      Enum.max([-1000000 | lengths])
    end
  end
end

case System.argv() do
  ["1", path] ->
    map = Hike.parse_file(path)
    bounds = Hike.bounds(map)
    {start, goal} = Hike.terminals(map, bounds)
    path = Hike.longest_path(start, goal, map)
    Hike.show_path(path, bounds, map)
    IO.inspect(MapSet.size(path) - 1)
  ["2", path] ->
    map = Hike.parse_file(path)
    bounds = Hike.bounds(map)
    map = Hike.allow_uphills(map, bounds)
    Hike.show_path(MapSet.new(), bounds, map)
    {start, goal} = Hike.terminals(map, bounds)
    edges = Hike.to_graph([start, goal], map)
    emap = Hike.edge_map(edges)
    longest = Hike.longest_path_em(start, goal, emap)
    IO.inspect(longest)
  [] ->
    :ok
end
