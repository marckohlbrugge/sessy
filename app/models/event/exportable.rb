require "csv"

module Event::Exportable
  extend ActiveSupport::Concern

  CSV_HEADERS = %w[ Event Recipient Subject BounceType Time ]

  # Excel only reads a UTF-8 file as UTF-8 when it starts with a byte-order mark.
  CSV_BYTE_ORDER_MARK = "\uFEFF"

  # Recipients and subjects come from outside. A spreadsheet runs a cell that
  # starts with one of these as a formula, so such cells get a leading quote.
  CSV_FORMULA_PREFIX = /\A[=+\-@\t\r]/

  class_methods do
    # Lazily yields the export line by line, so a large filtered set streams
    # to the client instead of being built in memory.
    def csv_lines
      # Captured now: the enumerator runs after the relation's scope is gone,
      # where a bare `find_each` would export every event of every source.
      events = includes(:message)

      Enumerator.new do |lines|
        lines << CSV_BYTE_ORDER_MARK + CSV.generate_line(CSV_HEADERS)
        events.find_each { |event| lines << CSV.generate_line(event.csv_row) }
      rescue => error
        # The response is already underway, so nothing else reports this.
        Rails.error.report(error, handled: false)
        raise
      end
    end
  end

  def csv_row
    [ event_type, csv_text(recipient_email), csv_text(message&.subject), bounce_type, event_at.iso8601 ]
  end

  private

  def csv_text(value)
    value.to_s.match?(CSV_FORMULA_PREFIX) ? "'#{value}" : value
  end
end
