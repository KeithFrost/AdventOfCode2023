defmodule HeatPath do
  @moduledoc """
  Documentation for `HeatPath`.
  """
  def parse_line(s, y) do
    String.trim(s) |> to_charlist() |>
      Enum.with_index(fn c, x ->
        if c < ?0 or c > ?9 do
          {{x, y}, 0}
        else
          {{x, y}, c - ?0}
        end
      end)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.with_index() |>
      Enum.flat_map(fn {s, y} -> parse_line(s, y) end) |>
      Map.new()
  end
  def pos_delta_reps(path, maxlen) do
    deltas = Enum.take(path, maxlen + 1) |>
      Enum.chunk_every(2, 1, :discard) |>
      Enum.map(fn [{x, y}, {xp, yp}] ->
        {x - xp, y - yp} end)
    {delta, reps} =
      case deltas do
        [] ->
          {{0, 0}, 0}
        [delta | rest] ->
          case Enum.find_index(rest, fn d -> d != delta end) do
            nil -> {delta, 1 + length(rest)}
            index -> {delta, 1 + index}
          end
      end
    {List.first(path), delta, reps}
  end
  def extend_paths(paths, map, rmin, rmax) do
    {{least, path},  rest} = Heap.split(paths)
    {{x, y}, delta, reps} = pos_delta_reps(path, rmax)
    next_deltas =
      case {delta, reps} do
        {{0, 0}, 0} ->
          [{0, 1}, {0, -1}, {1, 0}, {-1, 0}]
        {d, r} when r < rmin ->
          [d]
        {{0, _}, r} when r == rmax ->
          [{-1, 0}, {1, 0}]
        {{_, 0}, r} when r == rmax ->
          [{0, -1}, {0, 1}]
        {{0, 1}, _} ->
          [{0, 1}, {1, 0}, {-1, 0}]
        {{0, -1}, _} ->
          [{0, -1}, {1, 0}, {-1, 0}]
        {{1, 0}, _} ->
          [{1, 0}, {0, -1}, {0, 1}]
        {{-1, 0}, _} ->
          [{-1, 0}, {0, -1}, {0, 1}]
      end
    new_paths = Enum.map(next_deltas, fn {dx, dy} -> {x + dx, y + dy} end) |>
      Enum.filter(fn pos -> Map.has_key?(map, pos) end) |>
      Enum.map(fn pos -> {map[pos] + least, [pos | path]} end)
    Enum.reduce(new_paths, rest, fn path, heap -> Heap.push(heap, path) end)
  end
  def min_loss_path(paths, settings, map, mc_map \\ %{}) do
    {goal, rmin, rmax} = settings
    {least, path} = Heap.root(paths)
    pdr = pos_delta_reps(path, rmax)
    prevc = Map.get(mc_map, pdr)
    if prevc != nil and prevc <= least do
      min_loss_path(Heap.pop(paths), settings, map, mc_map)
    else
      mc_map = Map.put(mc_map, pdr, least)
      {pos, delta, reps} = pdr
      if rem(least, 100) == 0 do
        IO.inspect({least, pos, delta, reps})
      end
      if pos == goal do
        {least, path}
      else
        paths = extend_paths(paths, map, rmin, rmax)
        min_loss_path(paths, settings, map, mc_map)
      end
    end
  end
  def max_pos(map) do
    Enum.reduce(map, {0, 0}, fn {{x, y}, _}, {mx, my} ->
      {max(x, mx), max(y, my)}
    end)
  end
end

defmodule HeatPath.CLI do
  def main(args \\ []) do
    case args do
      ["1", path] ->
        map = HeatPath.parse_file(path)
        HeatPath.min_loss_path(
          Heap.push(Heap.min(), {0, [{0, 0}]}),
          {HeatPath.max_pos(map), 1, 3},
          map) |>
          IO.inspect()
      ["2", path] ->
        map = HeatPath.parse_file(path)
        HeatPath.min_loss_path(
          Heap.push(Heap.min(), {0, [{0, 0}]}),
          {HeatPath.max_pos(map), 4, 10},
          map) |>
          IO.inspect()
      [] ->
        IO.puts("Hello World")
        :ok
    end
  end
end
