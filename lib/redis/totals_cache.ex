defmodule Castle.Redis.TotalsCache do
  alias Castle.Redis.Conn, as: Conn
  alias Castle.Redis.Increments, as: Increments
  alias Castle.Rollup.Query.Totals, as: Totals

  @incrs_exist_ttl 7200
  @no_incrs_ttl 300

  def podcast_totals(id, work_fn), do: podcast_totals(id, Timex.now, work_fn)
  def podcast_totals(id, now, work_fn) do
    case get_podcast_increments(id, now) do
      {nil, now} ->
        cache_or_work("totals.podcast.#{id}.now", now, @no_incrs_ttl, work_fn)
      {cached, cached_from} ->
        key("totals.podcast.#{id}", cached_from)
        |> cache_or_work(cached_from, @incrs_exist_ttl, work_fn)
        |> Totals.add_cached(cached)
    end
  end

  def episode_totals(guid, work_fn), do: episode_totals(guid, Timex.now, work_fn)
  def episode_totals(guid, now, work_fn) do
    case get_episode_increments(guid, now) do
      {nil, now} ->
        cache_or_work("totals.episode.#{guid}.now", now, @no_incrs_ttl, work_fn)
      {cached, cached_from} ->
        key("totals.episode.#{guid}", cached_from)
        |> cache_or_work(cached_from, @incrs_exist_ttl, work_fn)
        |> Totals.add_cached(cached)
    end
  end

  defp cache_or_work(key, dtim, ttl, work_fn) do
    case Conn.get(key) do
      nil ->
        val = work_fn.(dtim)
        Conn.set(key, ttl, val)
        val
      val ->
        val
    end
  end

  defp key(prefix, dtim) do
    {:ok, dtim_str} = Timex.format(dtim, "{ISO:Extended:Z}")
    "#{prefix}.#{dtim_str}"
  end

  defp get_podcast_increments(id, now) do
    intv = %{from: Timex.shift(now, days: -1), to: now}
    case Increments.get_podcast(id, intv, now) do
      {nil, _} -> {nil, now}
      {cached, new_intv} -> {cached, new_intv.to}
    end
  end

  defp get_episode_increments(guid, now) do
    intv = %{from: Timex.shift(now, days: -1), to: now}
    case Increments.get_episode(guid, intv, now) do
      {nil, _} -> {nil, now}
      {cached, new_intv} -> {cached, new_intv.to}
    end
  end
end
