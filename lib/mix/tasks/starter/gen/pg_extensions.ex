defmodule Mix.Tasks.Starter.Gen.PgExtensions do
  @shortdoc "Generates a PostgreSQL extensions migration"
  @moduledoc "Generates a migration enabling common PostgreSQL extensions (citext, pg_trgm, unaccent, vector)."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    repo = Helpers.repo(igniter)

    migration_body = """
    def up do
      execute "CREATE EXTENSION IF NOT EXISTS citext"
      execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
      execute "CREATE EXTENSION IF NOT EXISTS unaccent"
      execute "CREATE EXTENSION IF NOT EXISTS vector"

      execute \"""
      CREATE OR REPLACE FUNCTION public.f_unaccent(text)
        RETURNS text
        LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
      $func$
        SELECT public.unaccent('public.unaccent', $1)
      $func$;
      \"""
    end

    def down do
      execute "DROP FUNCTION IF EXISTS public.f_unaccent(text);"
      execute "DROP EXTENSION IF EXISTS vector"
      execute "DROP EXTENSION IF EXISTS unaccent"
      execute "DROP EXTENSION IF EXISTS pg_trgm"
      execute "DROP EXTENSION IF EXISTS citext"
    end
    """

    Helpers.gen_migration(igniter, repo, "add_extensions", body: migration_body)
  end
end
