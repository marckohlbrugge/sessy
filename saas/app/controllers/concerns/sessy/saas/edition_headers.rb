module Sessy::Saas::EditionHeaders
  extend ActiveSupport::Concern

  included do
    # Prepended so the header is stamped even when a later callback halts
    # the chain (e.g. HTTP Basic auth rejecting with a 401).
    prepend_before_action :set_edition_header
  end

  private
    def set_edition_header
      response.set_header "X-Sessy-Edition", "hosted"
    end
end
