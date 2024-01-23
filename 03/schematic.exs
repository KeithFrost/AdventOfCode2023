defmodule Schematic do
  def parse_charlist(charlist, x, y, parts, symbols) do
    case charlist do
      [] ->
        {parts, symbols}
      [?. | tail] ->
        parse_charlist(tail, x+1, y, parts, symbols)
      [head | _tail] when head >= ?0 and head <= ?9 ->
        part = %{x0: x, y: y}
        {part, new_tail} = parse_part(charlist, part)
        parse_charlist(new_tail, part.x1, y, [part | parts], symbols)
      [symbol | tail] ->
        new_symbols = Map.put(symbols, {x, y}, symbol)
        parse_charlist(tail, x+1, y, parts, new_symbols)
    end
  end

  def parse_part(charlist, part) do
    case charlist do
      [head | tail] when head >= ?0 and head <= ?9 ->
        digit = head - ?0
        x0 = Map.get(part, :x0, 0)
        updated = part |>
          Map.update(:x1, x0+1, fn x -> x+1 end) |>
          Map.update(:id, digit, fn id -> 10 * id + digit end)
        parse_part(tail, updated)
      _ ->
        {part, charlist}
    end
  end

  def parse_file(path) do
    File.stream!(path) |>
      Stream.map(&String.trim/1) |>
      Stream.map(&Kernel.to_charlist/1) |>
      Enum.with_index(fn(charlist, y) ->
        Schematic.parse_charlist(charlist, 0, y, [], %{}) end) |>
      Enum.reduce({[], %{}},
        fn({parts, symbols}, {pparts, psymbols}) ->
          {parts ++ pparts, Map.merge(psymbols, symbols)} end)
  end

  def symbol_adjacent?(part, symbols) do
    %{x0: x0, x1: x1, y: y} = part
    Enum.any?((x0 - 1)..x1, fn x ->
      Map.has_key?(symbols, {x, y-1}) or
      Map.has_key?(symbols, {x, y+1}) end) or
    Map.has_key?(symbols, {x0-1, y}) or
    Map.has_key?(symbols, {x1, y})
  end

  def adjacent_symbols(part, symbols) do
    %{x0: x0, x1: x1, y: y} = part
    positions = [{x0-1, y}, {x1, y}] ++
      Enum.flat_map((x0 - 1)..x1, fn x -> [{x, y-1}, {x, y+1}] end)
    Enum.filter(positions, fn pos -> Map.has_key?(symbols, pos) end)
  end

  def adjacent_parts(parts, symbols) do
    Enum.reduce(parts, %{}, fn(part, adj) ->
      adj_symbols = adjacent_symbols(part, symbols)
      Enum.reduce(adj_symbols, adj, fn(loc, adj) ->
        Map.update(adj, loc, [part], fn(prev) -> [part | prev] end) end)
    end)
  end

  def gear_values(symbols, adj_parts) do
    Enum.filter(symbols, fn {loc, sym} ->
      sym == ?* and length(Map.get(adj_parts, loc, [])) == 2 end) |>
      Enum.map(fn {loc, ?*} ->
        [part1, part2] = Map.fetch!(adj_parts, loc)
        part1.id * part2.id end)
  end
end


[path] = System.argv()
{parts, symbols} = Schematic.parse_file(path)
# IO.inspect(parts)
# IO.inspect(symbols)

### Part One.
# sum = Enum.filter(parts, fn part -> Schematic.symbol_adjacent?(part, symbols) end)
# |> Enum.map(fn part -> part.id end)
# |> Enum.sum
# IO.puts(sum)
### End Part One.

### Part Two.
adj_parts = Schematic.adjacent_parts(parts, symbols)
gear_values = Schematic.gear_values(symbols, adj_parts)
IO.puts(Enum.sum(gear_values))
### End Part Two.
