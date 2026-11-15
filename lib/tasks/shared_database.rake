# With a single DATABASE_URL (PostgreSQL), the queue, cache and cable
# databases are the primary one. db:prepare loads the primary schema first,
# then sees an initialized database for the others and never loads theirs,
# which leaves Solid Queue, Solid Cache and Solid Cable without tables.
# Load whichever schemas are missing.
namespace :db do
  task load_missing_schemas: :load_config do
    tasks = ActiveRecord::Tasks::DatabaseTasks

    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).reject { |config| config.name == "primary" }.each do |config|
      schema_file = tasks.schema_dump_path(config)
      next unless schema_file && File.exist?(schema_file)

      first_table = File.read(schema_file)[/create_table "(\w+)"/, 1]

      tasks.with_temporary_connection(config) do |connection|
        tasks.load_schema(config, config.schema_format, schema_file) unless connection.table_exists?(first_table)
      end
    end
  end
end

Rake::Task["db:prepare"].enhance do
  Rake::Task["db:load_missing_schemas"].invoke
end
