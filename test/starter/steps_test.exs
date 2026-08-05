defmodule Starter.StepsTest do
  use ExUnit.Case, async: true

  alias Starter.Steps

  test "lists built-in steps by kind" do
    assert "pgvector" in Steps.names(:add)
    assert "credo" in Steps.names(:add)
    assert "daisy_ui" in Steps.names(:remove)
    assert "topbar" in Steps.names(:remove)
    assert "gitignore" in Steps.names(:gen)
  end

  test "does not ship steps for packages with their own igniter installers" do
    refute "oban" in Steps.names(:add)
    refute "oban_web" in Steps.names(:add)
    refute "tidewave" in Steps.names(:add)
  end

  test "resolves short names to modules" do
    assert {:ok, Mix.Tasks.Starter.Add.Pgvector} = Steps.resolve(:add, :pgvector)
    assert {:ok, Mix.Tasks.Starter.Remove.DaisyUi} = Steps.resolve(:remove, :daisy_ui)
  end

  test "resolution is forgiving about case, underscores, and dashes" do
    assert {:ok, Mix.Tasks.Starter.Remove.DaisyUi} = Steps.resolve(:remove, "daisyui")
    assert {:ok, Mix.Tasks.Starter.Remove.DaisyUi} = Steps.resolve(:remove, "daisy-ui")
    assert {:ok, Mix.Tasks.Starter.Remove.DaisyUi} = Steps.resolve(:remove, "DaisyUI")
  end

  test "unknown names return :error" do
    assert :error = Steps.resolve(:add, :nonexistent)
  end
end
