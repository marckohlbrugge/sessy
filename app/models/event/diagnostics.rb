# What the receiving mail server said. SES attaches the SMTP status and
# diagnostic text per recipient to bounce and delay notifications; events are
# already per recipient, so these pick out the entry for this one.
module Event::Diagnostics
  # SES's own classification of why the event happened: the bounce subtype
  # (MailboxFull, General, Suppressed…), delay type, complaint feedback type,
  # reject reason, or rendering error.
  def reason
    case event_type
    when "bounce" then bounce_subtype
    when "delivery_delay" then event_data["delayType"]
    when "complaint" then event_data["complaintFeedbackType"] || event_data["complaintSubType"]
    when "reject" then event_data["reason"]
    when "rendering_failure" then event_data["errorMessage"]
    end
  end

  # Enhanced status code, e.g. "5.1.1" (no such user) or "4.2.2" (over quota).
  def smtp_status
    recipient_details&.dig("status")
  end

  # The remote server's response text. SES prefixes it with "smtp;" and
  # flattens line breaks into "<CRLF>"; both are stripped for display.
  def diagnostic_code
    code = recipient_details&.dig("diagnosticCode").presence
    code&.sub(/\Asmtp;\s*/i, "")&.gsub(/<CRLF>|\s+/, " ")&.strip
  end

  def diagnostics?
    reason.present? || diagnostic_code.present?
  end

  private

  def recipient_details
    recipients = event_data["bouncedRecipients"] || event_data["delayedRecipients"] || []
    recipients.find { |r| r["emailAddress"].to_s.casecmp?(recipient_email.to_s) } || recipients.first
  end
end
