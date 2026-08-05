defmodule Mix.Tasks.Starter.Gen.GigalixirLibcluster do
  @shortdoc "Generates Gigalixir libcluster configuration"
  @moduledoc "Configures libcluster's Kubernetes strategy for clustering on Gigalixir."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts =
      {:code,
       quote(
         do: [
           gigalixir: [
             strategy: Cluster.Strategy.Kubernetes,
             config: [
               kubernetes_selector: System.get_env("LIBCLUSTER_KUBERNETES_SELECTOR"),
               kubernetes_node_basename: System.get_env("LIBCLUSTER_KUBERNETES_NODE_BASENAME")
             ]
           ]
         ]
       )}

    Igniter.Project.Config.configure(igniter, "prod.exs", :libcluster, [:topologies], opts)
  end
end
