defmodule Castle.Redis.Api do
  @behaviour Castle.Redis

  defdelegate cached(key, ttl, work_fn),
    to: Castle.Redis.ResponseCache,
    as: :cached

  defdelegate interval(key_prefix, from, to, interval, work_fn),
    to: Castle.Redis.IntervalCache,
    as: :interval
end