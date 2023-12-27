defmodule BoatRace do
  def parse_line(s) do
    [key, values_str] = String.split(s, ":")
    values = String.split(values_str) |> Enum.map(&String.to_integer/1)
    {String.trim(key), values}
  end
  def parse_file(path) do
    File.stream!(path) |>
      Stream.map(&parse_line/1) |> Map.new
  end
  def distance(charged, time) do
    charged * (time - charged)
  end
  def brute_ways_to_beat(time, record) do
    Enum.reduce(1..(time-1)//1, 0, fn(charge, acc) ->
      if distance(charge, time) > record do
	  acc + 1
      else
	acc
      end
    end)
  end
  def ways_to_beat(time, record) do
    if time * time < 4 * record do
      0
    else
      delta = :math.sqrt(time * time - 4 * record)
      min_charge = ceil(0.5 * (time - delta))
      min_charge = Enum.find(min_charge..(min_charge + 1), fn c ->
	distance(c, time) > record end)
      max_charge = trunc(0.5 * (time + delta))
      max_charge = Enum.find(max_charge..(max_charge - 1), fn c ->
	distance(c, time) > record end)
      case {min_charge, max_charge} do
	{nil, _} -> 0
	{_, nil} -> 0
	{a, b} -> b - a + 1
      end
    end
  end
  def reparse(ints) do
    Enum.map(ints, &to_string/1) |> Enum.join("") |> String.to_integer()
  end
end


case System.argv() do
  ["1", method, path] ->
    %{"Time" => times, "Distance" => records} = BoatRace.parse_file(path)
    ways =
      case method do
	"b" ->
	  Enum.zip_with(times, records, &BoatRace.brute_ways_to_beat/2)
	"a" ->
	  Enum.zip_with(times, records, &BoatRace.ways_to_beat/2)
      end
    Enum.reduce(ways, fn(w, acc) -> w * acc end) |> IO.inspect
  ["2", method, path] ->
    %{"Time" => times, "Distance" => records} = BoatRace.parse_file(path)
    time = BoatRace.reparse(times)
    record = BoatRace.reparse(records)
    ways =
      case method do
	"b" -> BoatRace.brute_ways_to_beat(time, record)
	"a" -> BoatRace.ways_to_beat(time, record)
      end
    IO.inspect(ways)
  _ ->
    :ok
end
