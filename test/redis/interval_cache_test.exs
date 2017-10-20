defmodule Castle.RedisIntervalCacheTest do
  use Castle.RedisCase, async: true

  @moduletag :redis

  import Castle.Redis.IntervalCache
  alias BigQuery.TimestampRollups.{Daily, Hourly, Monthly, QuarterHourly, Weekly}

  @prefix "interval.cache.test"

  setup do
    redis_clear("#{@prefix}*")
    [
      from:       get_dtim("2017-03-22T01:15:00Z"),
      partial_to: get_dtim("2017-03-22T02:00:00Z"),
      to:         get_dtim("2017-03-22T02:45:00Z"),
    ]
  end

  test "assembles keys for timestamps", %{from: from, to: to} do
    keys = interval_keys(@prefix, from, to, QuarterHourly)
    assert length(keys) == 6
    assert hd(keys) == "#{@prefix}.15MIN.2017-03-22T01:15:00Z"
    assert List.last(keys) == "#{@prefix}.15MIN.2017-03-22T02:30:00Z"
  end

  test "sets a separate ttl for current intervals" do
    now = Timex.now
    past = Timex.shift(now, seconds: -7200)
    later = Timex.shift(now, seconds: 901)

    assert interval_ttls(past, now, QuarterHourly) == [2592000, 2592000, 2592000, 2592000, 300, 300, 300, 300, 300]
    assert interval_ttls(past, now, Hourly) == [2592000, 300, 300]
    assert interval_ttls(past, now, Daily) == [300]
    assert interval_ttls(past, now, Weekly) == [300]
    assert interval_ttls(past, now, Monthly) == [300]

    assert interval_ttls(past, later, QuarterHourly) == [2592000, 2592000, 2592000, 2592000, 300, 300, 300, 300, 300, 300]
    assert interval_ttls(past, later, Hourly) == [2592000, 300, 300]
    assert interval_ttls(past, later, Daily) == [300]
  end

  test "gets an entire time interval", %{from: from, to: to} do
    Castle.Redis.Conn.set(%{
      "#{@prefix}.15MIN.2017-03-22T01:15:00Z" => 10,
      "#{@prefix}.15MIN.2017-03-22T01:30:00Z" => 9,
      "#{@prefix}.15MIN.2017-03-22T01:45:00Z" => 8,
      "#{@prefix}.15MIN.2017-03-22T02:00:00Z" => 7,
      "#{@prefix}.15MIN.2017-03-22T02:15:00Z" => 6,
      "#{@prefix}.15MIN.2017-03-22T02:30:00Z" => 5,
    })
    {hits, new_from} = interval_get(@prefix, from, to, QuarterHourly)

    assert length(hits) == 6
    assert hd(hits).count == 10
    assert format_dtim(hd(hits).time) == "2017-03-22T01:15:00Z"
    assert format_dtim(List.last(hits).time) == "2017-03-22T02:30:00Z"
    assert is_nil(new_from)
  end

  test "gets a partial time interval", %{from: from, to: to} do
    Castle.Redis.Conn.set(%{
      "#{@prefix}.15MIN.2017-03-22T01:15:00Z" => 10,
      "#{@prefix}.15MIN.2017-03-22T01:30:00Z" => 9,
      "#{@prefix}.15MIN.2017-03-22T02:00:00Z" => 7,
      "#{@prefix}.15MIN.2017-03-22T02:15:00Z" => 6,
    })
    {hits, new_from} = interval_get(@prefix, from, to, QuarterHourly)

    assert length(hits) == 2
    assert hd(hits).count == 10
    assert List.last(hits).count == 9
    refute is_nil(new_from)
    assert format_dtim(new_from) == "2017-03-22T01:45:00Z"
  end

  test "misses the whole time interval", %{from: from, to: to} do
    Castle.Redis.Conn.set(%{
      "#{@prefix}.15MIN.2017-03-22T01:30:00Z" => 9,
      "#{@prefix}.15MIN.2017-03-22T01:45:00Z" => 8,
    })
    {hits, new_from} = interval_get(@prefix, from, to, QuarterHourly)

    assert length(hits) == 0
    refute is_nil(new_from)
    assert format_dtim(new_from) == "2017-03-22T01:15:00Z"
  end

  test "sets the time interval", %{from: from, partial_to: partial_to} do
    interval_set(@prefix, from, partial_to, QuarterHourly, [55, 66, 77])

    assert redis_count("#{@prefix}*") == 3
    assert Enum.member? redis_keys("#{@prefix}*"), "#{@prefix}.15MIN.2017-03-22T01:15:00Z"
    assert Enum.member? redis_keys("#{@prefix}*"), "#{@prefix}.15MIN.2017-03-22T01:30:00Z"
    assert Enum.member? redis_keys("#{@prefix}*"), "#{@prefix}.15MIN.2017-03-22T01:45:00Z"
  end

  test "handles blank responses", %{from: from, to: to} do
    {data, meta} = interval @prefix, from, to, QuarterHourly, fn(new_from) ->
      assert format_dtim(new_from) == "2017-03-22T01:15:00Z"
      {[], %{meta: "data"}}
    end
    assert redis_count("#{@prefix}*") == 6
    assert Enum.uniq(Enum.map(data, &(&1.count))) == [0]
    assert meta.meta == "data"
    assert meta.cache_hits == 0
  end

  test "caches response intervals", %{from: from, partial_to: partial_to, to: to} do
    data1 = [
      %{count: 55, time: get_dtim("2017-03-22T01:15:00Z")},
      %{count: 66, time: get_dtim("2017-03-22T01:30:00Z")},
      %{count: 77, time: get_dtim("2017-03-22T01:45:00Z")},
    ]
    data2 = [
      %{count: 88, time: get_dtim("2017-03-22T02:00:00Z")},
      %{count: 99, time: get_dtim("2017-03-22T02:15:00Z")},
      %{count: 111, time: get_dtim("2017-03-22T02:30:00Z")},
    ]

    {data, meta} = interval @prefix, from, partial_to, QuarterHourly, fn(new_from) ->
      assert format_dtim(new_from) == "2017-03-22T01:15:00Z"
      {data1, %{meta: "data"}}
    end
    assert redis_count("#{@prefix}*") == 3
    assert Enum.map(data, &(&1.count)) == [55, 66, 77]
    assert format_dtim(hd(data).time) == "2017-03-22T01:15:00Z"
    assert meta.meta == "data"
    assert meta.cache_hits == 0

    {data, meta} = interval @prefix, from, to, QuarterHourly, fn(new_from) ->
      assert format_dtim(new_from) == "2017-03-22T02:00:00Z"
      {data2, %{meta: "stuff"}}
    end
    assert redis_count("#{@prefix}*") == 6
    assert Enum.map(data, &(&1.count)) == [55, 66, 77, 88, 99, 111]
    assert format_dtim(hd(data).time) == "2017-03-22T01:15:00Z"
    assert meta.meta == "stuff"
    assert meta.cache_hits == 3

    {data, meta} = interval @prefix, from, to, QuarterHourly, fn(_new_from) ->
      raise "should not have called this"
    end
    assert Enum.map(data, &(&1.count)) == [55, 66, 77, 88, 99, 111]
    assert format_dtim(hd(data).time) == "2017-03-22T01:15:00Z"
    assert meta.cached == true
    assert meta.cache_hits == 6
  end

  test "fills zeros into results", %{from: from, to: to} do
    result = [
      %{count: 11, time: get_dtim("2017-03-22T01:45:00Z")},
      %{count: 22, time: get_dtim("2017-03-22T02:15:00Z")},
    ]
    {data, _} = interval_fill_zeros({result, %{}}, from, to, QuarterHourly)
    assert Enum.map(data, &(&1.time)) == QuarterHourly.range(from, to)
    assert Enum.map(data, &(&1.count)) == [0, 0, 11, 0, 22, 0]
  end

  test "caches empty response intervals", %{from: from, partial_to: partial_to, to: to} do
    data1 = [
      %{count: 66, time: get_dtim("2017-03-22T01:30:00Z")},
    ]
    data2 = [
      %{count: 88, time: get_dtim("2017-03-22T02:00:00Z")},
      %{count: 111, time: get_dtim("2017-03-22T02:30:00Z")},
    ]

    {data, _} = interval @prefix, from, partial_to, QuarterHourly, fn(_) -> {data1, %{}} end
    assert redis_count("#{@prefix}*") == 3
    assert Enum.map(data, &(&1.count)) == [0, 66, 0]
    assert format_dtim(hd(data).time) == "2017-03-22T01:15:00Z"

    {data, _} = interval @prefix, from, to, QuarterHourly, fn(_) -> {data2, %{}} end
    assert redis_count("#{@prefix}*") == 6
    assert Enum.map(data, &(&1.count)) == [0, 66, 0, 88, 0, 111]
    assert format_dtim(hd(data).time) == "2017-03-22T01:15:00Z"
  end

  def get_dtim(dtim_str) do
    {:ok, dtim, _} = DateTime.from_iso8601(dtim_str)
    dtim
  end

  def format_dtim(dtim) do
    {:ok, formatted} = Timex.format(dtim, "{ISO:Extended:Z}")
    formatted
  end
end
