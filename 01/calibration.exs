defmodule Cal do
  def calibration(s) do
    all_digits = Regex.scan(~r/[0-9]/, s) |> List.flatten
    case all_digits do
      [] -> 0
      _ ->
	first = String.to_integer(List.first(all_digits))
	last = String.to_integer(List.last(all_digits))
	10 * first + last
    end
  end
end

[path] = System.argv()

calibration = File.stream!(path)
|> Stream.map(&String.trim/1)
|> Stream.map(&Cal.calibration/1)
|> Enum.sum

IO.puts(calibration)
