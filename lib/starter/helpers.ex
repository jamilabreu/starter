defmodule Starter.Helpers do
  @moduledoc """
  Conveniences for writing steps.
  """

  @doc "Returns the camelized app module name (e.g. `\"MyApp\"`)."
  def app_module(igniter) do
    Igniter.Project.Application.app_name(igniter) |> to_string() |> Macro.camelize()
  end

  @doc "Returns the app's Repo module (e.g. `MyApp.Repo`)."
  def repo(igniter) do
    Module.concat([app_module(igniter), "Repo"])
  end

  @doc "Returns the app's web module name (e.g. `\"MyAppWeb\"`)."
  def app_web_module(igniter) do
    app_module(igniter) <> "Web"
  end

  @doc "Updates a file's raw content with a transformation function."
  def update_file_content(igniter, path, transform) do
    Igniter.update_file(igniter, path, fn source ->
      source
      |> Rewrite.Source.get(:content)
      |> transform.()
      |> then(&Rewrite.Source.update(source, :content, &1))
    end)
  end

  @doc """
  Updates a file's content, adding a loud warning instead of silently
  no-oping when the transformation changes nothing or the file is missing.

  Steps that pattern-match against `phx.new` output should use this so that
  drift in Phoenix's generators surfaces as a warning instead of silence.
  """
  def update_file_checked(igniter, path, transform, warning) do
    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)
      source = Rewrite.source!(igniter.rewrite, path)
      content = Rewrite.Source.get(source, :content)

      if transform.(content) == content do
        Igniter.add_warning(igniter, warning)
      else
        update_file_content(igniter, path, transform)
      end
    else
      Igniter.add_warning(igniter, "#{path} not found — #{warning}")
    end
  end

  @doc """
  Generates a migration with a unique timestamp.

  Tracks timestamps in igniter assigns to avoid duplicates when multiple
  migrations are created within the same second.
  """
  def gen_migration(igniter, repo, name, opts \\ []) do
    {igniter, timestamp} = next_migration_timestamp(igniter)
    Igniter.Libs.Ecto.gen_migration(igniter, repo, name, Keyword.put(opts, :timestamp, timestamp))
  end

  defp next_migration_timestamp(igniter) do
    current = migration_timestamp()
    last_used = igniter.assigns[:starter_last_migration_timestamp] || 0

    timestamp = max(current, last_used + 1)
    igniter = Igniter.assign(igniter, :starter_last_migration_timestamp, timestamp)

    {igniter, timestamp}
  end

  defp migration_timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    String.to_integer("#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}")
  end

  defp pad(i) when i < 10, do: "0#{i}"
  defp pad(i), do: "#{i}"
end
