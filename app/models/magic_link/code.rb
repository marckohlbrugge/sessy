module MagicLink::Code
  # Crockford-style base32: excludes I, L, O, U so codes stay unambiguous when
  # read aloud or typed. The substitutions below fold the excluded letters onto
  # their look-alike digits.
  ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".chars.freeze
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  class << self
    def generate(length)
      Array.new(length) { ALPHABET.sample(random: SecureRandom) }.join
    end

    def sanitize(code)
      if code.present?
        normalize_code(code)
          .then { apply_substitutions(it) }
          .then { remove_invalid_characters(it) }
      end
    end

    private

    def normalize_code(code)
      code.to_s.upcase
    end

    def apply_substitutions(code)
      CODE_SUBSTITUTIONS.reduce(code) { |result, (from, to)| result.gsub(from, to) }
    end

    def remove_invalid_characters(code)
      code.gsub(/[^#{ALPHABET.join}]/, "")
    end
  end
end
