class ConvertPostgresTypesForSqliteCompatibility < ActiveRecord::Migration[8.1]
  def up
    convert_jsonb_to_json
    convert_enum_to_string
    convert_uuid_to_string
  end

  def down
    revert_json_to_jsonb
    revert_string_to_enum
    revert_string_to_uuid
  end

  private

  def convert_jsonb_to_json
    return unless column_type(:events, :event_data) == :jsonb

    change_column :webhooks, :raw_payload, :json, null: false, default: {}
    change_column :messages, :mail_metadata, :json, default: {}
    change_column :events, :event_data, :json, default: {}
    change_column :events, :raw_payload, :json, default: {}
  end

  def convert_enum_to_string
    return unless enum_type_exists?(:event_type)

    change_column :events, :event_type, :string, null: false
    execute "DROP TYPE IF EXISTS event_type"
  end

  def convert_uuid_to_string
    return unless column_type(:sources, :token) == :uuid

    change_column :sources, :token, :string, null: false, default: nil
  end

  def revert_json_to_jsonb
    return unless column_type(:events, :event_data) == :json && postgresql?

    change_column :webhooks, :raw_payload, :jsonb, null: false, default: {}
    change_column :messages, :mail_metadata, :jsonb, default: {}
    change_column :events, :event_data, :jsonb, default: {}
    change_column :events, :raw_payload, :jsonb, default: {}
  end

  def revert_string_to_enum
    return unless postgresql? && !enum_type_exists?(:event_type)

    execute <<-SQL
      CREATE TYPE event_type AS ENUM (
        'Send', 'Delivery', 'Bounce', 'Complaint', 'Reject',
        'DeliveryDelay', 'RenderingFailure', 'Subscription', 'Open', 'Click'
      )
    SQL
    execute "ALTER TABLE events ALTER COLUMN event_type TYPE event_type USING event_type::event_type"
  end

  def revert_string_to_uuid
    return unless column_type(:sources, :token) == :string && postgresql?

    execute "ALTER TABLE sources ALTER COLUMN token TYPE uuid USING token::uuid"
    execute "ALTER TABLE sources ALTER COLUMN token SET DEFAULT gen_random_uuid()"
    execute "ALTER TABLE sources ALTER COLUMN token SET NOT NULL"
  end

  def column_type(table, column)
    connection.columns(table).find { |c| c.name == column.to_s }&.type
  end

  def enum_type_exists?(name)
    return false unless postgresql?

    query = "SELECT 1 FROM pg_type WHERE typname = '#{name}'"
    connection.select_value(query).present?
  end

  def postgresql?
    connection.adapter_name.downcase.include?("postgresql")
  end
end
