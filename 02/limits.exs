defmodule Game do
  def parse_count_color(s) do
    [count_str, color] = String.split(String.trim(s), " ", parts: 2, trim: true)
    {color, String.to_integer(count_str)}
  end

  def parse_grab(gst) do
    String.split(gst, ",", trim: true)
    |> Enum.map(&Game.parse_count_color/1)
    |> Map.new
  end

  def parse_game(st) do
    [game_tag, grabs_str] = String.split(st, ":", parts: 2)
    [_, id_str] = String.split(game_tag, " ", parts: 2, trim: true)
    id = String.to_integer(id_str)
    grabs = String.split(String.trim(grabs_str), ";")
    |> Enum.map(&Game.parse_grab/1)
    {id, grabs}
  end

  def grab_possible?(grab, counts) do
    Enum.all?(
      grab,
      fn {color, gcount} -> gcount <= Map.get(counts, color, 0) end
    )
  end

  def game_possible?(game, counts) do
    min_set = Game.min_set(game)
    Game.grab_possible?(min_set, counts)
  end

  def max_grabs(grab, accum) do
    Map.merge(accum, grab, fn(_k, v1, v2) -> max(v1, v2) end)
  end

  def min_set(game) do
    {_id, grabs} = game
    Enum.reduce(grabs, %{}, &Game.max_grabs/2)
  end

  def set_power(grab) do
    Enum.reduce(grab, 1, fn({_color, count}, acc) -> acc * count end)
  end
end

### Part One.
# limits = %{"red" => 12, "green" => 13, "blue" => 14}
### End Part One.

[path] = System.argv()

sum = File.stream!(path)
|> Stream.map(&Game.parse_game/1)
### Part One.
# |> Stream.filter(fn(game) -> Game.game_possible?(game, limits) end)
# |> Stream.map(fn(game) -> elem(game, 0) end)
### End Part One.
### Part Two.
|> Stream.map(fn(game) -> Game.set_power(Game.min_set(game)) end)
### End Part Two.
|> Enum.sum

IO.puts(sum)
