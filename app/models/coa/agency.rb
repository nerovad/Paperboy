# frozen_string_literal: true

module Coa
  class Agency < BaseRecord
    self.table_name = 'agencies'
    self.primary_key = :agency_id

    has_many :activities, foreign_key: :agency_id, inverse_of: :agency
    has_many :departments, foreign_key: :agency_id, inverse_of: :agency
    has_many :divisions, foreign_key: :agency_id, inverse_of: :agency
    has_many :functions, foreign_key: :agency_id, inverse_of: :agency
    has_many :major_programs, foreign_key: :agency_id, inverse_of: :agency
    has_many :phases, foreign_key: :agency_id, inverse_of: :agency
    has_many :programs, foreign_key: :agency_id, inverse_of: :agency
    has_many :object_inferences, foreign_key: :agency_id, inverse_of: :agency
    has_many :sub_units, foreign_key: :agency_id, inverse_of: :agency
    has_many :tasks, foreign_key: :agency_id, inverse_of: :agency
    has_many :units, foreign_key: :agency_id, inverse_of: :agency

    # Employee records sometimes carry a four-character personnel-system
    # variant (for example, HCAV) while the organization and account tables
    # use the three-character agency id (HCA).
    def self.normalize_id(code)
      key = code.to_s.strip.upcase
      return nil if key.blank?
      return key if stored_id?(key)

      trimmed = key.sub(/V\z/, '')
      trimmed != key && stored_id?(trimmed) ? trimmed : key
    end

    # Whether the agencies table holds this id exactly.
    #
    # Deliberately not +exists?+. agencies.agency_id is nvarchar(3), and SQL
    # Server casts a bound parameter to the column type before comparing, so
    # a four-character id is truncated first and +exists?(agency_id: 'GSAV')+
    # answers true against the 'GSA' row. That happens wherever prepared
    # statements are on -- staging and production -- while development leaves
    # them off (query log tags append a comment to every statement), so the
    # suffix was trimmed in development and kept everywhere else. The chain
    # built in ApplicationController#current_user_org_chain then carried
    # 'GSAV', which matches no org_permissions row, and every org-level grant
    # was silently skipped for those employees on stage and prod.
    #
    # Comparing the id the database actually returns gives the same answer on
    # either kind of connection.
    def self.stored_id?(key)
      where(agency_id: key).pick(:agency_id) == key
    end
    private_class_method :stored_id?
  end
end
