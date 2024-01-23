defmodule RangeMap do
  def parse_range(s) do
    case String.split(s) do
      [] ->
        nil
      l ->
        [dest, src, len] = Enum.map(l, &String.to_integer/1)
        %{dest: dest, src: src, len: len}
    end
  end
  def parse_seeds(s) do
    case String.split(s, ":") do
      [] ->
        nil
      ["seeds", seeds_str] ->
        String.split(seeds_str) |> Enum.map(&String.to_integer/1)
    end
  end
  def parse_map_header(s) do
    case String.split(s) do
      [] ->
        nil
      [map_name, "map:"] ->
        [src, "to", dest] = String.split(map_name, "-")
        {src, dest}
    end
  end
  def parse_line(line, state) do
    case state.parsing do
      :seeds ->
        seeds = parse_seeds(line)
        if seeds != nil do
          %{state | parsing: :maps, seeds: seeds}
        else
          state
        end
      :maps ->
        header = parse_map_header(line)
        if header != nil do
          {src, dest} = header
          new_src_map = Map.get(state.maps, src, %{}) |> Map.put(dest, [])
          new_maps = Map.put(state.maps, src, new_src_map)
          %{state | parsing: {:ranges, header}, maps: new_maps}
        else
          state
        end
      {:ranges, {src, dest}} ->
        range = parse_range(line)
        if range != nil do
          new_src_map = Map.update!(
            state.maps[src], dest, fn l -> [range | l] end)
          new_maps = Map.put(state.maps, src, new_src_map)
          %{state | maps: new_maps}
        else
          %{state | parsing: :maps}
        end
    end
  end

  def parse_file(path) do
    %{seeds: seeds, maps: maps} = File.stream!(path) |>
      Enum.reduce(%{parsing: :seeds, maps: %{}, seeds: []}, &parse_line/2)
    {seeds, maps}
  end

  def map_range(range, {src, dest}, inputs) do
    %{src: src0, dest: dest0, len: len} = range
    Enum.flat_map(inputs, fn input ->
      {key, first, count} = input
      cond do
        key != src ->
          [input]
        first > src0 + len - 1 or first + count - 1 < src0 ->
          [input]
        first < src0 ->
          if (first + count <= src0 + len) do
            [{key, first, src0 - first},
             {dest, dest0, first + count - src0}]
          else
            [{key, first, src0 - first},
             {dest, dest0, len},
             {key, src0 + len, first + count - src0 - len}]
          end
        true ->
          if (first + count <= src0 + len) do
            [{dest, dest0 + first - src0, count}]
          else
            [{dest, dest0 + first - src0, src0 - first + len},
             {key, src0 + len, first + count - src0 - len}]
          end
      end
    end)
  end

  def map_ranges(ranges, {src, dest}, inputs) do
    Enum.reduce(ranges, inputs, fn(range, inputs) ->
      map_range(range, {src, dest}, inputs) end) |>
      Enum.map(fn {key, first, count} ->
        cond do
          key == src ->
            {dest, first, count}
          true ->
            {key, first, count}
        end
      end)
  end

  def map_value(input, ranges) do
    case ranges do
      [] ->
        input
      [range | rest] ->
        if (input >= range.src and input < (range.src + range.len)) do
          range.dest + input - range.src
        else
          map_value(input, rest)
        end
    end
  end

  def all_mappings(values, maps, mappings \\ %{}) do
    case values do
      [] ->
        mappings
      [{key, vs} | rest] ->
        cond do
          Map.has_key?(mappings, key) ->
            all_mappings(rest, maps, mappings)
          not Map.has_key?(maps, key) ->
            all_mappings(rest, maps, Map.put(mappings, key, vs))
          true ->
            new_values = Enum.map(maps[key], fn {new_key, ranges} ->
            {new_key, Enum.map(vs, fn v -> map_value(v, ranges) end)} end)
            all_mappings(new_values ++ rest, maps, Map.put(mappings, key, vs))
        end
    end
  end

  def all_mappings_ranged(value_ranges, maps, mappings \\ %{}) do
    case value_ranges do
      [] ->
        mappings
      [{key, ranges} | rest] ->
        cond do
          Map.has_key?(mappings, key) ->
            all_mappings_ranged(rest, maps, mappings)
          not Map.has_key?(maps, key) ->
            all_mappings_ranged(rest, maps, Map.put(mappings, key, ranges))
          true ->
            new_values = Enum.map(maps[key], fn {dest, mranges} ->
            {dest, map_ranges(mranges, {key, dest}, ranges)} end)
            all_mappings_ranged(
              new_values ++ rest, maps, Map.put(mappings, key, ranges))
        end
    end
  end

  def range_seeds(ss) do
    Enum.chunk_every(ss, 2) |>
      Enum.map(fn [from, len] -> {"seed", from, len} end)
  end
end


case System.argv() do
  [step, path] ->
    {ss, maps} = RangeMap.parse_file(path)
    mappings =
      case step do
        "1" ->
          RangeMap.all_mappings([{"seed", ss}], maps)
        "2" ->
          RangeMap.all_mappings_ranged(
            [{"seed", RangeMap.range_seeds(ss)}], maps)
      end
    IO.inspect(Enum.min(mappings["location"]))
  _ ->
    :ok
end
