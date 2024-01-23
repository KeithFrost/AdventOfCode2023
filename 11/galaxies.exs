defmodule Galaxies do
  def parse_line(s) do
    String.trim(s) |> to_charlist() |> Enum.map(fn
      ?. -> 0
      ?# -> 1
    end)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.map(&parse_line/1)
  end
  def empty_cols(image) do
    Enum.reduce(image, fn(row, acc) ->
      Enum.zip_with(row, acc, fn(v, a) -> v + a end) end) |>
      Enum.with_index() |>
      Enum.filter(fn {sum, _x} -> sum == 0 end) |>
      Enum.map(fn {0, x} -> x end)
  end
  def empty_rows(image) do
    Enum.map(image, &Enum.sum/1) |>
      Enum.with_index() |>
      Enum.filter(fn {sum, _y} -> sum == 0 end) |>
      Enum.map(fn {0, y} -> y end)
  end
  def expand_list(l, iset) do
    Enum.with_index(l) |>
      Enum.flat_map(fn {v, i} ->
        if MapSet.member?(iset, i) do
          [v, v]
        else
          [v]
        end
      end)
  end
  def expand_space(image) do
    empty_cols = MapSet.new(empty_cols(image))
    empty_rows = MapSet.new(empty_rows(image))
    image_y = expand_list(image, empty_rows)
    Enum.map(image_y, fn row -> expand_list(row, empty_cols) end)
  end
  def positions(image) do
    Enum.with_index(image) |>
      Enum.flat_map(fn {row, y} ->
        Enum.with_index(row) |>
          Enum.filter(fn {v, _x} -> v > 0 end) |>
          Enum.map(fn {_v, x} -> {x, y} end)
      end)
  end
  def expand_coordinate(coord, factor, empties) do
    expand_count =
      Enum.filter(empties, fn empty -> empty < coord end) |>
      Enum.count()
    coord + expand_count * (factor - 1)
  end
  def expanded_positions(image, factor) do
    positions = positions(image)
    empty_rows = empty_rows(image)
    empty_cols = empty_cols(image)
    Enum.map(positions, fn {x, y} ->
      {expand_coordinate(x, factor, empty_cols),
       expand_coordinate(y, factor, empty_rows)} end)
  end
  def distances(positions, acc \\ []) do
    case positions do
      [] ->
        Enum.reverse(acc)
      [{x, y} | rest] ->
        distances(rest,
          [Enum.map(rest, fn {x2, y2} ->
              abs(x2 - x) + abs(y2 - y) end) | acc])
    end
  end
end

case System.argv() do
  [fstr, path] ->
    image = Galaxies.parse_file(path)
    factor = String.to_integer(fstr)
    positions = Galaxies.expanded_positions(image, factor)
    Galaxies.distances(positions) |> List.flatten() |> Enum.sum() |>
      IO.inspect()
  _ ->
    :ok
end
