# frozen_string_literal: true

module HsaAdoptionCards
  # Runs one HSA_Adopt_usp_* stored procedure and returns its rows.
  #
  # +mapping+ says which key from the page becomes which procedure parameter.
  # A key not in the mapping is dropped, so the page can never smuggle in a
  # parameter of its own; a key whose value is blank is left out so the
  # procedure's own default applies. Who ran it always travels along as
  # @AppUser, which is what the search log records.
  #
  # Values are bound with sanitize_sql_array rather than interpolated, the
  # same way Billing calls its export procedures.
  class Procedure
    # SQL Server error numbers for "you may not", turned into plain language.
    # Everything else is passed through verbatim: when something is actually
    # broken, the real message is what is needed.
    ACCESS_ERRORS = {
      229 => 'Your account is not authorised to search adoption records. ' \
             'Access is granted by membership of the HSA_Adopt_Searchers role — ' \
             'contact the Scan Center to request it.',
      916 => 'Your account does not have access to the GSA_Scan database.',
      4060 => 'Your account does not have access to the GSA_Scan database.'
    }.freeze

    def initialize(name, mapping)
      @name = name
      @mapping = mapping
    end

    # => Array of Hashes keyed by the procedure's column names, dates as
    #    ISO strings, SQL Server's blank-date placeholder (1900-01-01) as nil.
    def call(params, app_user:)
      sql = statement(params, app_user)
      Connection.open { |client| client.execute(sql).map { |row| normalize(row) } }
    rescue StandardError => e
      raise e if e.is_a?(HsaAdoptionCards::Error)

      raise translate(e)
    end

    # The exact SQL that would be sent, for the caller and the tests.
    def statement(params, app_user)
      bindings = bindings_for(params, app_user)
      sql = "EXEC #{@name} #{bindings.keys.map { |param| "#{param} = ?" }.join(', ')}"
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, *bindings.values])
    end

    private

    def bindings_for(params, app_user)
      bound = @mapping.each_with_object({}) do |(key, param), acc|
        value = params[key]
        acc[param] = value unless value.nil? || value.to_s.strip.empty?
      end
      bound['@AppUser'] = app_user
      bound
    end

    def normalize(row)
      row.to_h.transform_values do |value|
        case value
        when Date, Time, DateTime
          value.year == 1900 ? nil : value.to_date.iso8601
        else
          value
        end
      end
    end

    def translate(error)
      number = sql_error_number(error)
      return AccessDenied.new(ACCESS_ERRORS.fetch(number), detail: error.message) if ACCESS_ERRORS.key?(number)

      Error.new(error.message)
    end

    def sql_error_number(error)
      return error.db_error_number if error.respond_to?(:db_error_number)

      error.message[/\bError (\d+)\b/, 1].to_i
    end
  end
end
