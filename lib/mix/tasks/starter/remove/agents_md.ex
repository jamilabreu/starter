defmodule Mix.Tasks.Starter.Remove.AgentsMd do
  @shortdoc "Removes the AGENTS.md file"
  @moduledoc "Removes the `AGENTS.md` file that `phx.new` generates."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    if Igniter.exists?(igniter, "AGENTS.md") do
      Igniter.rm(igniter, "AGENTS.md")
    else
      igniter
    end
  end
end
