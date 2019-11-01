defmodule Castle.RollupLogTest do
  use Castle.DataCase
  use Castle.TimeHelpers

  import Castle.RollupLog

  test "finds an entirely missing range" do
    result = find_missing_days("foobar", 4, "2018-04-25")
    assert length(result) == 4
    assert "#{Enum.at(result, 0).date}" == "2018-04-25"
    assert "#{Enum.at(result, 1).date}" == "2018-04-24"
    assert "#{Enum.at(result, 2).date}" == "2018-04-23"
    assert "#{Enum.at(result, 3).date}" == "2018-04-22"
  end

  test "finds partial missing range" do
    upsert!(build_log("foobar", 2018, 4, 24))
    upsert!(build_log("foobar2", 2018, 4, 23))
    upsert!(build_log("foobar", 2018, 4, 22))
    result = find_missing_days("foobar", 4, "2018-04-25")
    assert length(result) == 4
    assert "#{Enum.at(result, 0).date}" == "2018-04-25"
    assert "#{Enum.at(result, 1).date}" == "2018-04-23"
    assert "#{Enum.at(result, 2).date}" == "2018-04-21"
    assert "#{Enum.at(result, 3).date}" == "2018-04-20"
  end

  test "ignores incomplete logs" do
    upsert!(build_log("foobar", 2018, 4, 24))
    upsert!(build_log("foobar2", 2018, 4, 23, false))
    result = find_missing_days("foobar", 2, "2018-04-25")
    assert length(result) == 2
    assert "#{Enum.at(result, 0).date}" == "2018-04-25"
    assert "#{Enum.at(result, 1).date}" == "2018-04-23"
  end

  test "finds empty range" do
    result = find_missing_days("foobar", 100, "1995-01-01")
    assert length(result) == 0
  end

  test "finds weekly range" do
    upsert!(build_log("foobar", 2019, 10, 27))
    upsert!(build_log("foobar", 2019, 11, 3))
    result = find_missing_weeks("foobar", 4, get_dtim("2019-11-15"))
    assert length(result) == 4
    assert "#{Enum.at(result, 0).date}" == "2019-11-10"
    assert "#{Enum.at(result, 1).date}" == "2019-10-20"
    assert "#{Enum.at(result, 2).date}" == "2019-10-13"
    assert "#{Enum.at(result, 3).date}" == "2019-10-06"
  end

  test "finds monthly range" do
    upsert!(build_log("foobar", 2018, 3, 1))
    result = find_missing_months("foobar", 4, get_dtim("2018-04-25"))
    assert length(result) == 4
    assert "#{Enum.at(result, 0).date}" == "2018-04-01"
    assert "#{Enum.at(result, 1).date}" == "2018-02-01"
    assert "#{Enum.at(result, 2).date}" == "2018-01-01"
    assert "#{Enum.at(result, 3).date}" == "2017-12-01"
  end

  test "updates rows that have already been inserted" do
    {:ok, date} = Date.from_erl({2018, 4, 22})

    {1, [%{id: id}]} =
      Castle.Repo.insert_all(
        Castle.RollupLog,
        [
          %{
            table_name: "foobar",
            date: date,
            inserted_at: Timex.to_naive_datetime(get_dtim("2018-04-22T22:00:00Z")),
            updated_at: Timex.to_naive_datetime(get_dtim("2018-04-22T23:00:00Z"))
          }
        ],
        returning: [:id]
      )

    log1 = Castle.Repo.get(Castle.RollupLog, id)
    assert log1.table_name == "foobar"
    assert "#{log1.date}" == "2018-04-22"
    assert_time(log1.inserted_at, "2018-04-22T22:00:00Z")
    assert_time(log1.updated_at, "2018-04-22T23:00:00Z")

    log2 = upsert!(build_log("foobar", 2018, 4, 22))
    assert log2.id == id
    assert log2.table_name == "foobar"
    assert "#{log2.date}" == "2018-04-22"
    assert Timex.compare(log2.inserted_at, log1.inserted_at) > 0
    assert Timex.compare(log2.updated_at, log1.updated_at) > 0

    # neither is accurate now - refetch timestamps
    final = Castle.Repo.get(Castle.RollupLog, id)
    assert final.table_name == "foobar"
    assert "#{final.date}" == "2018-04-22"
    assert final.inserted_at == log1.inserted_at

    # updated is "manually" set on conflict, and ends up being just slightly
    # behind the one auto-generated by ecto
    assert Timex.diff(final.updated_at, log2.updated_at, :seconds) == 0
  end

  defp build_log(name, year, month, day, complete \\ true) do
    {:ok, date} = Date.from_erl({year, month, day})
    %Castle.RollupLog{table_name: name, date: date, complete: complete}
  end
end
