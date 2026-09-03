# frozen_string_literal: true

module P2m
  class OmsUpload < GsabssBase
    self.table_name = 'p2m_oms_uploads'

    REMOVABLE_STATUSES = %w[staging staged validating ready needs_attention failed removed].freeze

    class Removed < StandardError; end

    has_many :files, class_name: 'P2m::OmsUploadFile', inverse_of: :oms_upload,
                     dependent: :destroy
    has_many :findings, class_name: 'P2m::OmsUploadFinding', inverse_of: :oms_upload,
                        dependent: :destroy

    validates :oms_number, format: { with: /\A\d{8,9}\z/ }, uniqueness: { scope: :mailer_date }
    validates :mailer_date, :status, :validation_status, :import_status, :archive_status, presence: true

    scope :newest_first, -> { order(mailer_date: :desc, oms_number: :desc) }

    def removable?
      import_status == 'not_started' && REMOVABLE_STATUSES.include?(status)
    end

    def begin_import!
      with_lock do
        raise Removed, "OMS #{oms_number} was removed from staging" if status == 'removed'

        update!(status: 'importing', import_status: 'importing',
                import_started_at: Time.current, failure_message: nil)
      end
    end
  end
end
