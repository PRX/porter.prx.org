defmodule CastleWeb.API.EpisodeView do
  use CastleWeb, :view

  def render("index.json", %{conn: conn, episodes: episodes, paging: paging}) do
    %{
      count: length(episodes),
      total: Map.get(paging, :total),
      _embedded: %{
        "prx:items": Enum.map(episodes, &(episode_json(&1, nil, conn)))
      },
      _links: case Map.get(paging, :podcast_id) do
        nil -> paging_links(api_episode_path(conn, :index), paging)
        pid -> paging_links(api_podcast_episode_path(conn, :index, pid), paging)
      end
    }
  end

  def render("show.json", %{conn: conn, episode: episode, trends: trends}) do
    episode_json(episode, trends, conn)
  end

  defp episode_json(episode, nil, conn) do
    %{
      id: episode.id,
      title: episode.title,
      subtitle: episode.subtitle,
      publishedAt: format_dtim(episode.published_at),
      _links: episode_links(conn, episode),
    }
  end
  defp episode_json(episode, trends, conn) do
    episode_json(episode, nil, conn) |> Map.put(:downloads, trends)
  end

  defp episode_links(conn, episode) do
    %{
      self: %{
        href: api_episode_path(conn, :show, episode.id),
      },
      alternate: %{
        href: "https://feeder.prx.org/api/v1/episodes/#{episode.id}",
      },
      "prx:podcast": %{
        href: api_podcast_path(conn, :show, episode.podcast_id),
      },
      "prx:downloads": %{
        href: api_episode_download_path(conn, :index, episode.id) <> "{?interval,from,to}",
        templated: true,
      },
      "prx:ranks": %{
        href: api_episode_rank_path(conn, :index, episode.id) <> "{?interval,from,to,group,limit,filters}",
       templated: true,
      },
      "prx:totals": %{
        href: api_episode_total_path(conn, :index, episode.id) <> "{?from,to,group,filters}",
        templated: true,
      },
    } |> episode_image_link(episode.image_url)
  end

  defp episode_image_link(links, nil), do: links
  defp episode_image_link(links, url), do: Map.put(links, "prx:image", %{href: url})

  defp format_dtim(nil), do: nil
  defp format_dtim(dtim) do
    {:ok, formatted} = Timex.format(dtim, "{ISO:Extended:Z}")
    formatted
  end
end
