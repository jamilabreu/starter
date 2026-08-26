defmodule Mix.Tasks.Starter.Add.ObanPro do
  @shortdoc "Adds Oban Pro extensions"
  @moduledoc "Adds `oban_pro` for advanced background job processing features. Requires an Oban Pro license."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    if oban_configured?(igniter) do
      igniter
      |> add_dep()
      |> add_migration()
      |> edit_config()
      |> Igniter.Project.Formatter.import_dep(:oban_pro)
    else
      Igniter.add_warning(igniter, """
      oban_pro extends an Oban setup that isn't here yet: no `config :app, \
      Oban` was found. Put {:add, :oban} before this step in your starter \
      so Oban's own installer runs first, or run `mix igniter.install oban` \
      and re-run this step.
      """)
    end
  end

  # Deliberately checks for Oban's *config*, not its dependency. Packages a
  # starter installs are added to mix.exs before any step runs, so a dep
  # check would pass while `oban.install` has yet to compose — it answers
  # "will oban be a dep?" rather than "is Oban set up?". Its config is what
  # oban.install writes, so this stays honest about ordering.
  defp oban_configured?(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    Igniter.Project.Config.configures_key?(igniter, "config.exs", app_name, [Oban])
  end

  defp add_dep(igniter) do
    requirement =
      case Starter.Versions.fetch_oban_pro_version() do
        nil -> "~> 1.8"
        version -> Starter.Versions.requirement(version)
      end

    Igniter.Project.Deps.add_dep(igniter, {:oban_pro, requirement, repo: "oban"})
  end

  # Unversioned `up/0` runs every Pro migration through the current release,
  # including v1.8's `oban_jobs_archive` table.
  defp add_migration(igniter) do
    repo = Helpers.repo(igniter)

    migration_body = """
    def up, do: Oban.Pro.Migration.up()
    def down, do: Oban.Pro.Migration.down()
    """

    Helpers.gen_migration(igniter, repo, "add_oban_pro", body: migration_body)
  end

  # Oban 2.24 promoted cron, lifeline, pruner, and queues to top-level config
  # keys, and Oban Pro 1.8 ships them as `Oban.Pro.Cron`, `.Lifeline`,
  # `.Pruner`, and `.Queues` (the former Dynamic* plugins) plus
  # `Oban.Pro.Engine` (formerly `Engines.Smart`). Each key is set on its own
  # so what `oban.install` already wrote — the repo, and the lifeline/pruner
  # defaults this overrides — is layered on rather than replaced wholesale.
  # DynamicPrioritizer wasn't promoted and stays a plugin.
  defp edit_config(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    settings = [
      engine: "Oban.Pro.Engine",
      notifier: "Oban.Notifiers.PG",
      cron: "{Oban.Pro.Cron, crontab: []}",
      lifeline: "Oban.Pro.Lifeline",
      pruner: "Oban.Pro.Pruner",
      queues: "{Oban.Pro.Queues, sync_mode: :automatic, queues: [default: 10, webhooks: 20]}",
      plugins: "[Oban.Pro.Plugins.DynamicPrioritizer]"
    ]

    Enum.reduce(settings, igniter, fn {key, source}, igniter ->
      code = Sourceror.parse_string!(source)

      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        app_name,
        [Oban, key],
        {:code, code}
      )
    end)
  end
end
