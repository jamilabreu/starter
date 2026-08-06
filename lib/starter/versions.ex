defmodule Starter.Versions do
  @moduledoc """
  Fetches latest package versions from Hex, npm, GitHub, and the Oban Pro
  docs site so generated dependencies start current instead of pinned to
  whatever Starter shipped with.

  Lookups are cached per-run via `:persistent_term` and degrade gracefully:
  when the network is unavailable (or `config :starter, fetch_versions: false`
  is set, as in tests), version requirements fall back to permissive ranges.
  """

  @doc ~S(Returns a dep tuple for the latest Hex version, e.g. `{:oban, "~> 2.19"}`.)
  def latest_hex_dep(package) when is_atom(package) do
    case fetch_hex_version(Atom.to_string(package)) do
      nil -> {package, ">= 0.0.0"}
      version -> {package, requirement(version)}
    end
  end

  @doc ~S"""
  Builds a safe `~>` requirement for a version.

  Pre-1.0 versions keep all three segments (`"0.3.1"` → `"~> 0.3.1"`) because
  0.x minor bumps are breaking under SemVer convention; stable versions pin
  to the minor series (`"2.19.4"` → `"~> 2.19"`).
  """
  def requirement("0." <> _ = version), do: "~> #{version}"
  def requirement(version), do: "~> #{major_minor(version)}"

  @doc "Fetches the latest stable version string of a Hex package, or nil."
  def fetch_hex_version(package) do
    cached(:hex, package, fn ->
      case get_json("https://hex.pm/api/packages/#{package}") do
        %{"latest_stable_version" => version} -> version
        _ -> nil
      end
    end)
  end

  @doc "Fetches the latest version string of an npm package, or nil."
  def fetch_npm_version(package) do
    cached(:npm, package, fn ->
      url =
        case String.split(package, "/", parts: 2) do
          ["@" <> scope, name] -> "https://registry.npmjs.org/@#{scope}%2F#{name}"
          [name] -> "https://registry.npmjs.org/#{name}"
        end

      case get_json(url) do
        %{"dist-tags" => %{"latest" => version}} -> version
        _ -> nil
      end
    end)
  end

  @doc """
  Fetches latest npm versions for multiple packages in parallel.

  Packages whose lookup fails or times out map to nil — a hung registry can
  never crash the caller.
  """
  def fetch_npm_versions(packages) do
    tasks = Enum.map(packages, fn pkg -> Task.async(fn -> fetch_npm_version(pkg) end) end)

    packages
    |> Enum.zip(Task.yield_many(tasks, 10_000))
    |> Map.new(fn
      {pkg, {_task, {:ok, version}}} ->
        {pkg, version}

      {pkg, {task, _timeout_or_exit}} ->
        Task.shutdown(task, :brutal_kill)
        {pkg, nil}
    end)
  end

  @doc """
  Fetches the latest Oban Pro version, or nil.

  Oban Pro lives on a private Hex repo, so hex.pm knows nothing about it —
  but the public docs site embeds the version it was built from.
  """
  def fetch_oban_pro_version do
    cached(:docs, "oban_pro", fn ->
      with body when is_binary(body) <- get_body("https://oban.pro/docs/pro/overview.html"),
           [_, version] <- Regex.run(~r/<meta name="project" content="Oban Pro v([\d.]+)"/, body) do
        version
      else
        _ -> nil
      end
    end)
  end

  @doc ~S(Fetches the latest release tag of a GitHub repo, e.g. `"v4.8.0"`, or nil.)
  def fetch_github_tag(owner, repo) do
    cached(:github, "#{owner}/#{repo}", fn ->
      case get_json("https://api.github.com/repos/#{owner}/#{repo}/releases/latest") do
        %{"tag_name" => tag} -> tag
        _ -> nil
      end
    end)
  end

  defp cached(registry, package, fun) do
    if enabled?() do
      cache_key = {:starter_version, registry, package}

      case :persistent_term.get(cache_key, :not_cached) do
        :not_cached ->
          version = fun.()
          :persistent_term.put(cache_key, version)
          version

        cached_version ->
          cached_version
      end
    else
      nil
    end
  end

  defp get_json(url), do: get_body(url)

  defp get_body(url) do
    Application.ensure_all_started(:req)

    req_opts = [
      receive_timeout: 5_000,
      connect_options: [timeout: 5_000],
      retry: false
    ]

    case Req.get(url, req_opts) do
      {:ok, %{status: 200, body: body}} -> body
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp enabled? do
    Application.get_env(:starter, :fetch_versions, true)
  end

  defp major_minor(version) do
    version |> String.split(".") |> Enum.take(2) |> Enum.join(".")
  end
end
