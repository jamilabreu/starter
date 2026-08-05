defmodule Mix.Tasks.Starter.Add.Libcluster do
  @shortdoc "Adds libcluster for node clustering"
  @moduledoc """
  Adds `libcluster` for clustering Elixir nodes.

  Note: `phx.new` already ships `dns_cluster` for DNS-based clustering.
  Use libcluster when you need other strategies (Gossip, Kubernetes, etc.).
  """
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> add_app_child()
    |> edit_config_dev()
  end

  defp add_dep(igniter) do
    Igniter.Project.Deps.add_dep(igniter, Starter.Versions.latest_hex_dep(:libcluster))
  end

  defp add_app_child(igniter) do
    app_module = Helpers.app_module(igniter)
    supervisor = Module.concat([app_module, "ClusterSupervisor"])
    repo = Helpers.repo(igniter)

    child =
      {Cluster.Supervisor,
       {:code,
        quote(
          do: [Application.get_env(:libcluster, :topologies) || [], [name: unquote(supervisor)]]
        )}}

    Igniter.Project.Application.add_new_child(igniter, child, after: [repo])
  end

  defp edit_config_dev(igniter) do
    opts = {:code, quote(do: [gossip: [strategy: Cluster.Strategy.Gossip]])}

    Igniter.Project.Config.configure(igniter, "dev.exs", :libcluster, [:topologies], opts)
  end
end
