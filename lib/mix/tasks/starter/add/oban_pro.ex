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
      Oban` was found. Put {:add, :oban} before this step in your workflow \
      so Oban's own installer runs first, or run `mix igniter.install oban` \
      and re-run this step.
      """)
    end
  end

  # Deliberately checks for Oban's *config*, not its dependency. Packages a
  # workflow installs are added to mix.exs before any step runs, so a dep
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
        nil -> "~> 1.7"
        version -> Starter.Versions.requirement(version)
      end

    Igniter.Project.Deps.add_dep(igniter, {:oban_pro, requirement, repo: "oban"})
  end

  defp add_migration(igniter) do
    repo = Helpers.repo(igniter)

    migration_body = """
    def up, do: Oban.Pro.Migration.up()
    def down, do: Oban.Pro.Migration.down()
    """

    Helpers.gen_migration(igniter, repo, "add_oban_pro", body: migration_body)
  end

  defp edit_config(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)

    opts =
      {:code,
       quote(
         do: [
           engine: Oban.Pro.Engines.Smart,
           notifier: Oban.Notifiers.PG,
           plugins: [
             {Oban.Pro.Plugins.DynamicCron, [crontab: []]},
             Oban.Pro.Plugins.DynamicLifeline,
             Oban.Pro.Plugins.DynamicPrioritizer,
             Oban.Pro.Plugins.DynamicPruner,
             {Oban.Pro.Plugins.DynamicQueues,
              [queues: [default: 10, webhooks: 20], sync_mode: :automatic]}
           ],
           repo: unquote(repo)
         ]
       )}

    Igniter.Project.Config.configure(igniter, "config.exs", app_name, [Oban], opts)
  end
end
