defmodule Mix.Tasks.Starter.Add.TidewaveConfig do
  @shortdoc "Adds a Tidewave MCP server config"
  @moduledoc """
  Creates `.mcp.json` pointing at a local Tidewave MCP server.

  This only wires up the MCP config file; it does not add the `tidewave`
  dependency or plug. Use `{:install, :tidewave}` for the full upstream
  installer, or run this step afterward if you only need the MCP config.
  """
  use Igniter.Mix.Task

  @content """
  {
    "mcpServers": {
      "tidewave": {
        "type": "http",
        "url": "http://localhost:4000/tidewave/mcp"
      }
    }
  }
  """

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    if Igniter.exists?(igniter, ".mcp.json") do
      igniter
    else
      Igniter.create_new_file(igniter, ".mcp.json", @content)
    end
  end
end
