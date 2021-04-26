#  * EML format parser. EML is raw e-mail message header + body as returned by POP3 protocol.
#  * RFC 822: http://www.ietf.org/rfc/rfc0822.txt
#  * RFC 1521: https://www.ietf.org/rfc/rfc1521.txt
require 'securerandom'

module RubyEML
  class BuildEML
    def initialize
      @default_char_set = 'utf-8'
    end

    # Gets the character encoding name for iconv, e.g. 'iso-8859-2' -> 'iso88592'
    def get_charset_name(charset)
      charset.downcase.gsub(/[^0-9a-z]/, "")
    end

    # Generates a random id
    def guid
      SecureRandom.uuid
    end

    # Word-wrap the string 's' to 'i' chars per row
    def wrap(s, i)
      a = [ ]
      until ((s = s[i..s.length]) != "") do
        a.push(s[0..i])
      end
    end

    # Overridable properties and functions
    eml_format = {
      
    }

    attr_accessor :default_char_set
  end
end
