defmodule Mix.Tasks.Starter.Gen.GitignoreTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "appends to the default project .gitignore" do
    igniter =
      test_project()
      |> Igniter.compose_task(Mix.Tasks.Starter.Gen.Gitignore)

    assert diff(igniter, only: ".gitignore") =~ ".DS_Store"
  end

  test "appends to an existing .gitignore" do
    igniter =
      test_project(files: %{".gitignore" => "/_build/\n/deps/\n"})
      |> Igniter.compose_task(Mix.Tasks.Starter.Gen.Gitignore)

    assert diff(igniter, only: ".gitignore") =~ ".DS_Store"
  end

  test "is idempotent when .DS_Store is already ignored" do
    test_project(files: %{".gitignore" => ".DS_Store\n"})
    |> Igniter.compose_task(Mix.Tasks.Starter.Gen.Gitignore)
    |> assert_unchanged(".gitignore")
  end
end
