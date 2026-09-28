module Event::Searchable
  extend ActiveSupport::Concern

  included do
    # Substring match on recipient email or message subject.
    #
    # Written as a UNION ALL subquery standing in for the events table rather
    # than an OR across a LEFT JOIN. Postgres can't index an OR that spans two
    # tables, so the join form walks every event in the date window and looks
    # up its message (30s+ on million-row sources). With two independent
    # branches the planner picks per branch: the trigram indexes on
    # events.recipient_email and messages.subject for rare terms, an ordered
    # scan that stops at the page limit for dense ones. Outer filters (source,
    # date range, event type) and ORDER BY are pushed down into the branches.
    # The subject branch excludes recipient matches so no row appears twice.
    scope :search, ->(term) {
      pattern = "%#{sanitize_sql_like(term)}%"
      recipient_matches = arel_table[:recipient_email].matches(pattern, "\\")
      subject_matches = Message.arel_table[:subject].matches(pattern, "\\")

      by_recipient = unscoped.where(recipient_matches)
      by_subject = unscoped.joins(:message).where(subject_matches).where.not(recipient_matches)

      from("(#{by_recipient.to_sql} UNION ALL #{by_subject.to_sql}) AS #{quoted_table_name}")
    }
  end
end
