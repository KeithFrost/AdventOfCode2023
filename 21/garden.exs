defmodule Garden do
  def parse_line(s) do
    String.trim(s) |> to_charlist() |> Enum.map(fn c ->
      case c do
        ?. -> ?.
        ?S -> ?O
        ?# -> ?X
      end
    end)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.map(&parse_line/1)
  end
  def expand_3x3(grid) do
    empty_grid = Enum.map(grid, fn row ->
      Enum.map(row, fn v ->
        case v do
          ?. -> ?.
          ?O -> ?.
          ?X -> ?X
        end
      end)
    end)
    expandx_empty = Enum.map(empty_grid, fn row ->
      row ++ row ++ row end)
    expandx_mid = Enum.zip_with(empty_grid, grid, fn erow, row ->
      erow ++ row ++ erow end)
    expandx_empty ++ expandx_mid ++ expandx_empty
  end
  def step_xform(grid) do
    rock_row = List.duplicate(?X, length(List.first(grid)))
    ngrid = Enum.chunk_every([rock_row | grid], 3, 1, [rock_row, rock_row]) |>
      Enum.map(fn [up, row, down] ->
        trios = Enum.zip([up, row, down])
        step_xform_row(trios)
      end)
    Enum.take(ngrid, length(grid))
  end
  def step_xform_row(trios, acc \\ []) do
    if acc == [] do
      case trios do
        [{c0, c1, c2}, {_, r1, _} | _rest] ->
          v = if (c0 ==?O or c2 == ?O or r1 == ?O) and
          (c1 == ?O or c1 == ?.) do
            ?O
          else
            if c1 == ?O do ?. else c1 end
          end
          step_xform_row(trios, [v])
        [] ->
          []
      end
    else
      case trios do
        [{_, l, _}, {c0, c1, c2}, {r0, r1, r2} | rest] ->
          v = if (l == ?O or c0 == ?O or c2 == ?O or r1 == ?O) and
          (c1 == ?O or c1 == ?.) do
            ?O
          else
            if c1 == ?O do ?. else c1 end
          end
          step_xform_row([{c0, c1, c2}, {r0, r1, r2} | rest], [v | acc])
        [{_, l, _}, {c0, c1, c2}] ->
          v = if (l == ?O or c0 == ?O or c2 == ?O) and
          (c1 == ?O or c1 == ?.) do
            ?O
          else
            if c1 == ?O do ?. else c1 end
          end
          Enum.reverse([v | acc])
      end
    end
  end
  def step_xforms(grid, steps \\ 1, step \\ 0) do
    IO.puts("#{step} #{count_plots(grid)}")
    if step >= steps do
      grid
    else
      ngrid = step_xform(grid)
      step_xforms(ngrid, steps, step + 1)
    end
  end
  def count_plots(grid) do
    Enum.reduce(List.flatten(grid), 0, fn c, s ->
      if c == ?O do s + 1 else s end
    end)
  end
  def rock_set(grid) do
    gridloc = Enum.with_index(grid, fn row, y ->
      Enum.with_index(row, fn v, x ->
        {{x, y}, v}
      end)
    end) |> List.flatten()
    Enum.flat_map(gridloc, fn {pos,  v} ->
      if v == ?X do
        [pos]
      else
        []
      end
    end) |>
      MapSet.new()
  end
  def start_pos(grid, y \\ 0) do
    case grid do
      [] ->
        nil
      [row | rest] ->
        case Enum.find_index(row, fn v -> v == ?O end) do
          nil ->
            start_pos(rest, y + 1)
          x ->
            {x, y}
        end
    end
  end
  def reduce_pos({x, y}, {width, height}) do
    nx = rem(x, width)
    nx = if nx < 0 do nx + width else nx end
    ny = rem(y, height)
    ny = if ny < 0 do ny + height else ny end
    {nx, ny}
  end
  def positions(starts, rocks, dims, steps \\ 1, step \\ 0, acc \\ nil) do
    IO.puts("#{step} #{MapSet.size(starts)}")
    if step >= steps do
      {starts, Enum.reverse(acc)}
    else
      nstarts = Enum.reduce(starts, MapSet.new(), fn {x, y}, set ->
        Enum.reduce(
          [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}],
          set,
          fn pos, set ->
            if MapSet.member?(rocks, reduce_pos(pos, dims)) do
              set
            else
              MapSet.put(set, pos)
            end
          end)
      end)
      acc =
        case acc do
          nil -> [MapSet.size(nstarts), MapSet.size(starts)]
          _ -> [MapSet.size(nstarts) | acc]
        end
      positions(nstarts, rocks, dims, steps, step + 1, acc)
    end
  end
  def show_grid(grid) do
    Enum.each(grid, fn row ->
      IO.puts(to_string(row))
    end)
  end
  def plot_3x3_posns(posns, rocks, dims) do
    {width, height} = dims
    (-height)..(2 * height - 1) |>
      Enum.each(fn y ->
        chars = (-width)..(2 * width - 1) |>
          Enum.map(fn x ->
            cond do
              MapSet.member?(posns, {x, y}) ->
                ?O
              MapSet.member?(rocks, reduce_pos({x, y}, dims)) ->
                ?X
              true ->
                ?.
            end
          end)
        IO.puts(to_string(chars))
      end)
  end
end


case System.argv() do
  ["1", steps_str, path] ->
    steps = String.to_integer(steps_str)
    grid = Garden.expand_3x3(Garden.parse_file(path))
    final = Garden.step_xforms(grid, steps)
    Garden.show_grid(final)
  ["2", steps_str, path] ->
    steps = String.to_integer(steps_str)
    grid = Garden.parse_file(path)
    width = length(List.first(grid))
    height = length(grid)
    dims = {width, height}
    rocks = Garden.rock_set(grid)
    start = Garden.start_pos(grid)
    posns = MapSet.new([start])
    {_final, counts} = Garden.positions(posns, rocks, dims, steps)
    counts_262 = Enum.drop(counts, 262)
    d1s = Enum.zip_with(counts_262, counts, fn (c, p) -> c - p end)
    d1s_262 = Enum.drop(d1s, 262)
    d2s = Enum.zip_with(d1s_262, d1s, fn (d, p) -> d - p end)
    counts_524 = Enum.drop(counts_262, 262)
    table = Enum.zip([counts_524, d1s_262, d2s])
    Enum.with_index(table, 524) |>
      Enum.each(fn {{c, d1, d2}, i} ->
        IO.puts("#{i} #{c} #{d1} #{d2}")
      end)
  ["2x", steps_str] ->
    steps = String.to_integer(steps_str)
    case rem(steps, 262) do
      0 ->
        IO.puts("... Xmas Miracle Occurs...")
        n = div(steps, 262) - 2
        count = 243629 + n * 243198 + n * n * 60692
        IO.puts("Count = #{count}")
      65 ->
        IO.puts("... Xmas Miracle Occurs...")
        n = div(steps - 65, 262) - 2
        count = 307795 + n * 273352 + n * n * 60692
        IO.puts("Count = #{count}")
      x ->
        IO.puts("#{x} WHO THE FRACK KNOWS???!")
    end
  [] ->
    :ok
end
