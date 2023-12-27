defmodule Cal do
  @digits %{
    "0" => 0, "1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5,
    "6" => 6, "7" => 7, "8" => 8, "9" => 9,
    "one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
    "six" => 6, "seven" => 7, "eight" => 8, "nine" => 9}
  digits_rx = Enum.join(Map.keys(@digits), "|")
  @last_rx Regex.compile!(".*(#{digits_rx})")
  @first_rx Regex.compile!("(#{digits_rx})")
  def calibration(s) do
    first_digit_match = Regex.run(@first_rx, s)
    last_digit_match = Regex.run(@last_rx, s)
    case first_digit_match do
      nil -> 0
      _ ->
	first = @digits[List.last(first_digit_match)]
	last = @digits[List.last(last_digit_match)]
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
