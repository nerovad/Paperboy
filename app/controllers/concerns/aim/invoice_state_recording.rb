# frozen_string_literal: true

module Aim
  # Keeps the invoice's row in step with what a person does on the queue
  # screens: every move in their name, every claim, and a document type they
  # correct. The files still move -- the workers find their work by folder --
  # so nothing here may stop a move a person has already made. Plan step 5.7b.
  module InvoiceStateRecording
    extend ActiveSupport::Concern

    private

    # The row follows every move a person makes here, in their name. The files
    # have already moved when this runs, and the workers still find their work
    # by folder, so a failure to record is logged rather than undoing the move:
    # Aim::QueueSync puts the row right afterwards. Plan step 5.7b.
    def record_move(state, note: nil)
      Aim::Invoice.record_move!(@invoice_id, state, actor: current_user_email, note: note)
    rescue StandardError => e
      Rails.logger.error "AIM could not record #{@invoice_id.inspect} moving to #{state}: #{e.class}: #{e.message}"
    end

    # Claims are written to the row as well as the folder until 5.7c retires
    # .claim.json; the folder stays the one that is read until then.
    def mirror_claim(email)
      Aim::Invoice.find_by(batch_id: @invoice_id)&.claim!(email)
    rescue StandardError => e
      Rails.logger.error "AIM could not record the claim on #{@invoice_id.inspect}: #{e.class}: #{e.message}"
    end

    def mirror_release
      Aim::Invoice.find_by(batch_id: @invoice_id)&.release_claim!
    rescue StandardError => e
      Rails.logger.error "AIM could not release the claim on #{@invoice_id.inspect}: #{e.class}: #{e.message}"
    end

    # A reviewer may correct the document type in the metadata grid. The row
    # takes it, so the rule that an Unknown invoice cannot reach a user judges
    # what the reviewer just set, not what the AI first said.
    def settle_document_type_from(metadata)
      typed = metadata.to_h.find { |key, _| key.to_s.casecmp?('DocumentType') }&.last
      known = Aim::Invoice::DOCUMENT_TYPES.find { |type| type.casecmp?(typed.to_s.strip) }
      return if known.nil?

      Aim::Invoice.find_by(batch_id: @invoice_id)&.update_columns(document_type: known, updated_at: Time.current)
    end

    def unsettled_document_type?
      Aim::Invoice.find_by(batch_id: @invoice_id)&.document_type == Aim::Invoice::UNSETTLED_DOCUMENT_TYPE
    end

    # The email is the claim's identity key — locking compares it against the
    # signed-in user — and the display name rides alongside it so queues never
    # have to show an address. Claims written before the name was recorded
    # return no name and are labelled from the mailbox instead.
    def claim_details_for(folder_path)
      claim_path = File.join(folder_path, '.claim.json')
      return [nil, nil] unless File.exist?(claim_path)

      claim_data = JSON.parse(File.read(claim_path))
      [claim_data['user'] || claim_data['employee_id'] || 'Someone', claim_data['name'].presence]
    rescue JSON::ParserError
      ['Unknown', nil]
    end

    def current_user_email
      session.dig(:user, 'email') || session.dig('user', 'email') || 'Unknown User'
    end

    def current_user_name
      user = session[:user] || session['user'] || {}
      [user['first_name'], user['last_name']].compact_blank.join(' ').presence
    end

    # An invoice nobody has typed is not ready for the person who has to act
    # on it. Checked before anything moves, so the files stay where they are.
    def refuse_unsettled_type
      redirect_to aim_invoice_path(@invoice_id, queue: @queue),
                  alert: 'This invoice is still typed Unknown. Set its document type before sending it to a user.'
    end
  end
end
