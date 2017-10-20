defmodule Castle.BigQueryTimestampRollupsMonthlyTest do
  use Castle.BigQueryCase, async: true

  import BigQuery.TimestampRollups.Monthly

  defp format_floor(str), do: mutate_dtim(str, &floor/1)
  defp format_ceiling(str), do: mutate_dtim(str, &ceiling/1)
  defp format_range(s1, s2), do: mutate_dtims(s1, s2, &range/2)

  test "has basic data" do
    assert name() == "MONTH"
    assert rollup() == "TIMESTAMP_TRUNC(timestamp, MONTH)"
    assert is_a?("1M") == true
    assert is_a?("MONTH") == true
    assert is_a?("1w") == false
    assert is_a?("foo") == false
  end

  test "floors" do
    assert format_floor("2017-03-22T01:15:00Z") == "2017-03-01T00:00:00Z"
    assert format_floor("2017-03-01T00:00:00Z") == "2017-03-01T00:00:00Z"
    assert format_floor("2017-03-31T23:59:59Z") == "2017-03-01T00:00:00Z"
  end

  test "ceilings" do
    assert format_ceiling("2017-03-22T01:15:00Z") == "2017-04-01T00:00:00Z"
    assert format_ceiling("2017-03-01T00:00:00Z") == "2017-03-01T00:00:00Z"
    assert format_ceiling("2017-04-01T00:00:01Z") == "2017-05-01T00:00:00Z"
  end

  test "range" do
    range = format_range("2017-03-22T01:15:00Z", "2017-05-01T12:00:00Z")
    assert length(range) == 3
    assert Enum.at(range, 0) == "2017-03-01T00:00:00Z"
    assert Enum.at(range, 1) == "2017-04-01T00:00:00Z"
    assert Enum.at(range, 2) == "2017-05-01T00:00:00Z"

    range = format_range("2017-03-01T00:00:00Z", "2017-05-01T00:00:00Z")
    assert length(range) == 2
    assert Enum.at(range, 0) == "2017-03-01T00:00:00Z"
    assert Enum.at(range, 1) == "2017-04-01T00:00:00Z"
  end
end
