# frozen_string_literal: true

require 'test_helper'

# Turns rules that AGENTS.md states in words into failures, so a change that
# breaks one is caught in the pull request instead of in review. Each message
# names the helper to use instead.
class AgentsRulesConventionsTest < ActiveSupport::TestCase
  DAM_CONTROLLERS = %w[
    app/controllers/digital_asset_management/**/*.rb
    app/controllers/concerns/digital_asset_management/**/*.rb
    app/controllers/concerns/dam_*.rb
    app/controllers/dam_*.rb
  ].freeze
  DAM_FILES = (%w[app/views/digital_asset_management/**/* app/views/dam_access_rules/**/*] + DAM_CONTROLLERS).freeze

  # Stock Active Storage links never expire and check nobody.
  UNCHECKED_FILE_LINK = /rails_blob_(?:path|url)|url_for\(\s*[\w@.]+\.(?:file|proxy|thumbnail)\b/

  def lines_matching(globs, pattern)
    Array(globs).flat_map { |glob| Rails.root.glob(glob) }.select(&:file?).sort.flat_map do |path|
      path.each_line.with_index(1).filter_map do |line, number|
        "#{path.relative_path_from(Rails.root)}:#{number}: #{line.strip}" if line.match?(pattern)
      end
    end
  end

  test 'production is never offered as a test environment' do
    offered = EnvironmentAccess::ENVIRONMENTS.flat_map { |env| env.values_at(:key, :rails_env) }

    assert_empty offered.grep(/\Aprod/i),
                 'Production is never gated by EnvironmentAccess; only dev and stage are test environments.'
  end

  test 'edit history and comments are not configurable inbox buttons' do
    configurable = Forms::Template::INBOX_BUTTON_TYPES.keys & %w[edit_history comments]

    assert_empty configurable,
                 "#{configurable.join(', ')} ride along with Edit and every inbox panel; " \
                 'listing them in INBOX_BUTTON_TYPES would make them opt-in again.'
  end

  test 'submission comment files are linked through the checked download path' do
    offences = lines_matching(%w[app/views/submission_comments/**/* app/controllers/submission_comments_controller.rb],
                              UNCHECKED_FILE_LINK)

    assert_empty offences, 'Use submission_comment_attachment_path, which checks the viewer.'
  end

  test 'DAM files are linked through a per-user token' do
    offences = lines_matching(DAM_FILES, UNCHECKED_FILE_LINK)

    assert_empty offences, 'Use dam_file_path, dam_thumbnail_url, dam_preview_url or dam_original_url.'
  end

  test 'DAM controllers find a single asset through find_viewable_asset' do
    offences = lines_matching(DAM_CONTROLLERS, /Dam::Asset\.find\(/)

    assert_empty offences, 'Use find_viewable_asset(id) so the access rules apply.'
  end

  test 'every modal in a view carries role="dialog"' do
    missing = Rails.root.glob('app/views/**/*.erb').select do |path|
      text = path.read
      text.include?('pb-modal-backdrop') && !text.include?('role="dialog"')
    end

    assert_empty missing.map { |path| path.relative_path_from(Rails.root).to_s },
                 'A modal needs role="dialog", aria-modal="true" and a label (see Modals in AGENTS.md).'
  end
end
