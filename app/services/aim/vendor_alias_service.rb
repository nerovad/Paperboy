# frozen_string_literal: true

module Aim
  class VendorAliasService
    TABLE_NAME = 'Aim_Vendor_Aliases'
    NOTE_PREFIX = 'Learned from AIM vendor review'

    class << self
      def official_names
        rows = connection.exec_query(<<~SQL.squish)
          SELECT DISTINCT NormalizedName
          FROM #{quoted_table_name}
          WHERE NormalizedName IS NOT NULL
            AND LTRIM(RTRIM(NormalizedName)) <> ''
          ORDER BY NormalizedName
        SQL

        rows.rows.flatten.map { |name| name.to_s.squish }.reject(&:blank?).uniq.sort_by(&:downcase)
      end

      def learn!(extracted_name:, normalized_name:, learned_by:)
        extracted = normalize_vendor_text(extracted_name)
        normalized = normalize_vendor_text(normalized_name)
        raise ArgumentError, 'Extracted vendor name is required.' if extracted.blank?
        raise ArgumentError, 'Official vendor name is required.' if normalized.blank?

        connection.transaction do
          upsert_mapping(normalized, normalized, learned_by) unless extracted.casecmp?(normalized)
          upsert_mapping(extracted, normalized, learned_by)
        end
      end

      private

      def connection
        BillingBase.connection
      end

      def quoted_table_name
        connection.quote_table_name(TABLE_NAME)
      end

      def upsert_mapping(extracted, normalized, learned_by)
        now = Time.current
        note = vendor_alias_note(learned_by)

        connection.execute(<<~SQL.squish)
          UPDATE #{quoted_table_name}
          SET NormalizedName = #{connection.quote(normalized)},
              DateLearned = #{connection.quote(now)},
              Notes = #{connection.quote(note)}
          WHERE ExtractedName = #{connection.quote(extracted)}
          IF @@ROWCOUNT = 0
            INSERT INTO #{quoted_table_name} (ExtractedName, NormalizedName, DateLearned, Notes)
            VALUES (#{connection.quote(extracted)},
                    #{connection.quote(normalized)},
                    #{connection.quote(now)},
                    #{connection.quote(note)})
        SQL
      end

      def normalize_vendor_text(value)
        value.to_s.squish.presence
      end

      def vendor_alias_note(learned_by)
        user = learned_by.to_s.squish
        return NOTE_PREFIX if user.blank? || user == 'Unknown User'

        "#{NOTE_PREFIX} by #{user}"
      end
    end
  end
end
