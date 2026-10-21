# frozen_string_literal: true

require 'zip'

# Bates stamping (#230): named counters, each with its next number (zeros
# included, which set the width) and stamp layout, designed with the shared stamp designer. Upload
# PDFs, check one, then stamp them all: the files come back numbered
# continuously from the counter's next number, which moves on, and the run is
# logged. Uploaded files are read from their temporary copies and kept
# nowhere. Everything here is the `paperboy:bates_stamp` feature grant.
class BatesCountersController < ApplicationController
  FEATURE = 'bates_stamp'
  UPLOAD_LIMIT = 25.megabytes

  before_action :require_bates_stamp
  before_action :set_counter, except: %i[index create]

  def index
    @counters = BatesCounter.by_name.to_a
    @last_runs = BatesRun.where(bates_counter_id: @counters.map(&:id)).group(:bates_counter_id).maximum(:id)
                         .then { |ids| BatesRun.where(id: ids.values).index_by(&:bates_counter_id) }
  end

  def create
    counter = BatesCounter.create!(counter_params.merge(created_by: actor))
    redirect_to edit_bates_counter_path(counter), notice: "#{counter.name} created. Upload PDFs to stamp."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to bates_counters_path, alert: e.record.errors.full_messages.to_sentence
  end

  def edit
    @runs = @counter.runs.limit(20).to_a
  end

  # The layout and the next number, as set on the page.
  def update
    @counter.assign_attributes(counter_params.merge(area_list: submitted_areas, page_shrink: params[:page_shrink].presence&.to_i,
                                                    page_position: params[:page_position].presence, updated_by: actor))
    @counter.save!
    redirect_to edit_bates_counter_path(@counter), notice: 'Saved.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_bates_counter_path(@counter), alert: e.record.errors.full_messages.to_sentence
  end

  # The first uploaded PDF stamped with the layout and numbers as they stand
  # on the page, unsaved; no number is taken.
  def preview
    upload = params[:file]
    return head :unprocessable_content unless pdf?(upload)

    trial = @counter.dup.tap do |counter|
      counter.assign_attributes(counter_params.merge(area_list: submitted_areas, page_shrink: params[:page_shrink].presence&.to_i,
                                                     page_position: params[:page_position].presence))
    end
    result = trial.preview([upload.path])
    send_data result.files.first, type: 'application/pdf', disposition: 'inline', filename: 'bates-check.pdf'
  rescue Paperboy::Pdf::Unwritable => e
    render plain: "This PDF cannot be stamped: #{e.message}", status: :unprocessable_content
  end

  # Every uploaded PDF stamped from the counter's next number, in upload
  # order; one file comes back as itself, several as a zip.
  def stamp
    files = Array(params[:files]).first(BatesCounter::MAX_FILES)
    return refuse('Upload one or more PDFs, each up to 25 MB.') if files.empty? || !files.all? { |file| pdf?(file) }

    result, run = @counter.run!(files.map(&:path), names: files.map(&:original_filename), by: actor)
    response.headers['X-Bates-Range'] = run.range
    send_stamped(files, result, run)
  rescue Paperboy::Pdf::Unwritable => e
    refuse("A PDF cannot be stamped (#{e.message}); no numbers were used.")
  end

  private

  def require_bates_stamp
    return if helpers.can_use_app_feature?('paperboy', FEATURE)

    redirect_to root_path, alert: 'Access denied.'
  end

  def set_counter = (@counter = BatesCounter.find(params[:id]))

  def actor = current_user&.email.presence || 'Unknown User'

  # The name, and the next number as written with its zeros ("000123": six
  # digits, from 123); each only when given.
  def counter_params
    given = params.permit(:name, :start).to_h.compact_blank
    { name: given['name'], start_text: given['start'] }.compact
  end

  def submitted_areas
    list = JSON.parse(params[:areas].to_s)
    list.is_a?(Array) ? list.grep(Hash).first(BatesCounter::MAX_AREAS + 1) : @counter.area_list
  rescue JSON::ParserError
    @counter.area_list
  end

  def pdf?(upload)
    upload.respond_to?(:path) && upload.size <= UPLOAD_LIMIT && File.binread(upload.path, 5) == '%PDF-'
  end

  def refuse(message)
    response.headers['X-Bates-Error'] = message
    head :unprocessable_content
  end

  def send_stamped(files, result, run)
    first = Paperboy::Pdf::Bates.build(prefix: '', digits: run.digits, start: run.first_number).label(run.first_number)
    return send_data(result.files.first, type: 'application/pdf', filename: "#{first}_#{files.first.original_filename}") if files.one?

    zip = Zip::OutputStream.write_buffer do |out|
      files.zip(result.files).each_with_index do |(file, bytes), index|
        out.put_next_entry("#{(index + 1).to_s.rjust(2, '0')}_#{File.basename(file.original_filename)}")
        out.write(bytes)
      end
    end
    send_data zip.string, type: 'application/zip', filename: "Bates_#{run.range.delete(' ')}.zip"
  end
end
