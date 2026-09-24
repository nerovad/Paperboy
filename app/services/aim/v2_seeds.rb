# frozen_string_literal: true

module Aim
  # Reads the v1 JSON files into the v2 tables. Used by lib/tasks/aim_v2.rake.
  module V2Seeds
    module_function

    # A bare file name lives in the worker install folder.
    def resolve(configured)
      service = Aim::InvoiceDirectoryService.instance
      translated = service.translate_path(configured.to_s)
      return translated if translated.include?('/')

      File.join(service.program_dir, translated)
    end

    # vendor_aliases.json: {"AS READ": "Official Name", ...}
    def seed_aliases(path)
      data = JSON.parse(File.read(path))
      raise ArgumentError, "#{path} is not an object of extracted => normalized names" unless data.is_a?(Hash)

      added = kept = 0
      data.each do |extracted, normalized|
        next if extracted.to_s.squish.blank? || normalized.to_s.squish.blank?

        if Aim::VendorAlias.where('LOWER(extracted_name) = ?', extracted.to_s.squish.downcase).exists?
          kept += 1
        else
          Aim::VendorAlias.create!(extracted_name: extracted, normalized_name: normalized, learned_by: 'seed',
                                   note: "seeded from #{File.basename(path)}")
          added += 1
        end
      end
      [added, kept]
    end

    # vendor_rules.json: {"Official Name": ["rule", "rule"], ...}
    def seed_rules(path)
      data = JSON.parse(File.read(path))
      raise ArgumentError, "#{path} is not an object of vendor => rules" unless data.is_a?(Hash)

      added = kept = 0
      data.each do |vendor, rules|
        lines = Array(rules).map { |rule| rule.to_s.strip }.compact_blank
        next if vendor.to_s.squish.blank? || lines.empty?

        if Aim::VendorRule.for_vendor(vendor)
          kept += 1
        else
          Aim::VendorRule.create!(vendor_name: vendor, rules: lines.join("\n"), updated_by: 'seed')
          added += 1
        end
      end
      [added, kept]
    end

    # Cutover: a row v1 left open has its PDF in one of v1's queue folders,
    # `_BACK_END/<queue>/<batch_id>/` (rejected ones one level deeper), and v2
    # looks only in the store. Each such PDF is copied -- not moved -- into
    # `_STORE/<batch_id>/`, so v1's folders are left as they were. Returns
    # [adopted, missing]: a missing PDF is named, and its row left alone.
    def adopt_v1_pdfs(backend_dir)
      adopted = missing = 0
      Aim::Invoice.where.not(state: Aim::Invoice::TERMINAL_STATES).find_each do |invoice|
        next if File.exist?(invoice.pdf_path)

        source = v1_pdf_for(backend_dir, invoice.batch_id)
        if source
          FileUtils.mkdir_p(invoice.store_dir)
          FileUtils.cp(source, invoice.pdf_path)
          adopted += 1
        else
          missing += 1
          puts "  no PDF found for #{invoice.batch_id} (#{invoice.state})"
        end
      end
      [adopted, missing]
    end

    # Looked up by walking, not Dir.glob: a batch id holds [ and ], which
    # glob reads as a character class. A batch folder sits directly in a
    # queue, or one level down in a grouping folder (v1's rejected queue
    # grouped by submitter and BU).
    def v1_pdf_for(backend_dir, batch_id)
      return unless Dir.exist?(backend_dir)

      Dir.children(backend_dir).sort.each do |queue|
        queue_dir = File.join(backend_dir, queue)
        next unless File.directory?(queue_dir)

        groups = Dir.children(queue_dir).sort.select { |name| File.directory?(File.join(queue_dir, name)) }
        candidates = [File.join(queue_dir, batch_id)] + groups.map { |group| File.join(queue_dir, group, batch_id) }
        pdf = candidates.filter_map { |folder| pdf_in(folder) }.first
        return pdf if pdf
      end
      nil
    end

    # Cutover, the other way: rows v1 left open that are not worth carrying
    # over are closed as deleted, in the caller's name, so the v2 queues show
    # only what v2 has taken. Rows created at or after `before` are untouched.
    def clear_v1_leftovers(before, actor:)
      closed = 0
      Aim::Invoice.where(created_at: ...before).where.not(state: Aim::Invoice::TERMINAL_STATES).find_each do |invoice|
        invoice.transition_to!('deleted', actor: actor, note: 'v1 leftover closed at the v2 cutover')
        closed += 1
      rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
        puts "  left #{invoice.batch_id} (#{invoice.state}): #{e.message}"
      end
      closed
    end

    # Test data from before the cutover goes altogether: finished rows created
    # before `before`, with their events. An open row is never purged.
    def purge_before(before)
      rows = Aim::Invoice.where(created_at: ...before).where(state: Aim::Invoice::TERMINAL_STATES)
      ids = rows.pluck(:id)
      events = Aim::InvoiceEvent.where(invoice_id: ids).delete_all
      [rows.delete_all, events]
    end

    def pdf_in(folder)
      return unless File.directory?(folder)

      pdf = Dir.children(folder).sort.find { |name| name.downcase.end_with?('.pdf') }
      File.join(folder, pdf) if pdf
    end
  end
end
