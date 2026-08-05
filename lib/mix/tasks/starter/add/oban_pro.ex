defmodule Mix.Tasks.Starter.Add.ObanPro do
  @shortdoc "Adds Oban Pro extensions"
  @moduledoc "Adds `oban_pro` for advanced background job processing features. Requires an Oban Pro license."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    if Igniter.Project.Deps.has_dep?(igniter, :oban) do
      igniter
      |> add_dep()
      |> add_migration()
      |> edit_config()
      |> Igniter.Project.Formatter.import_dep(:oban_pro)
    else
      Igniter.add_warning(igniter, """
      oban_pro requires oban, which is not a dependency yet. Install Oban \
      first — {:install, :oban} in your workflow, or `mix igniter.install \
      oban` — then re-run this step. In a workflow, queue it after the \
      installs: {:queue, "starter.add", ["oban_pro"], if: :oban_pro}
      """)
    end
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
