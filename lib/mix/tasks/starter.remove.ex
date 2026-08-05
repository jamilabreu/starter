defmodule Mix.Tasks.Starter.Remove do
  @shortdoc "Removes phx.new defaults"

  @moduledoc """
  Runs one or more `:remove` steps by name.

  ## Usage

      mix starter.remove daisy_ui
      mix starter.remove daisy_ui,topbar

  Run `mix starter.remove --list` to see every available step.
  """

  use Igniter.Mix.Task

  @impl Mix.Task
  def run(argv) do
    if "--list" in argv or "-l" in argv do
      Starter.Steps.Dispatcher.list(:remove)
    else
      super(argv)
    end
  end

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :starter,
      example: "mix starter.remove daisy_ui",
      positional: [{:names, optional: true}]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Starter.Steps.Dispatcher.run(igniter, :remove, igniter.args.positional[:names])
  end
end
