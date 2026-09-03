# frozen_string_literal: true

require 'test_helper'

# Guards the CSS toolchain. Stylesheets are compiled by Dart Sass
# (dartsass-rails + sass-embedded), not libsass.
#
# libsass has been end-of-life since 2020 and parses `min()` / `max()` as Sass
# numeric functions, so it rejects `min(30.6rem, calc(100vh - 32rem))` outright.
# That is what broke the staging deploy on 2026-08-24. These assertions exist so
# the pipeline cannot quietly slide back, and so nobody reaches for the
# workarounds that libsass used to require.
class StylesheetConventionsTest < ActiveSupport::TestCase
  STYLESHEET_ROOT = Rails.root.join('app/assets/stylesheets')

  # sass-rails pulls in sassc-rails, which pulls in sassc, which is libsass.
  LIBSASS_GEMS = %w[sass-rails sassc-rails sassc].freeze

  # Removed in Dart Sass 3.0. Use the sass:color / sass:string modules instead.
  GLOBAL_BUILTINS = %w[
    darken lighten saturate desaturate adjust-hue
    opacify transparentize fade-in fade-out
    unquote quote
  ].freeze

  def scss_files
    @scss_files ||= Dir.glob(STYLESHEET_ROOT.join('**/*.scss'))
  end

  def offences_for(pattern)
    scss_files.flat_map do |path|
      File.readlines(path).filter_map.with_index(1) do |line, number|
        next if line.lstrip.start_with?('//')

        "#{Pathname.new(path).relative_path_from(Rails.root)}:#{number}: #{line.strip}" if line.match?(pattern)
      end
    end
  end

  test 'libsass is not in the bundle' do
    locked = File.read(Rails.root.join('Gemfile.lock'))

    LIBSASS_GEMS.each do |gem_name|
      refute_match(/^\s+#{Regexp.escape(gem_name)} \(/, locked,
                   "#{gem_name} reintroduces libsass, which cannot compile modern CSS " \
                   'such as min(), max() or nested calc(). Use dartsass-rails instead.')
    end
  end

  test 'dart sass is the configured compiler' do
    assert defined?(Dartsass::Engine), 'dartsass-rails must be loaded to compile stylesheets'
    assert_equal({ 'application.scss' => 'application.css' },
                 Rails.application.config.dartsass.builds)
  end

  test 'stylesheets do not use global built-in sass functions' do
    offences = offences_for(/(?<![\w-])(#{GLOBAL_BUILTINS.join('|')})\s*\(/)

    assert_empty offences,
                 'Global Sass built-ins are removed in Dart Sass 3.0. Load the module ' \
                 "instead — `@use \"sass:color\"` then color.adjust(...):\n#{offences.join("\n")}"
  end

  test 'stylesheets do not wrap modern css in unquote to appease the compiler' do
    offences = offences_for(/unquote\(/)

    assert_empty offences,
                 'Dart Sass emits min()/max()/clamp() verbatim, so the unquote() ' \
                 "workaround is no longer needed:\n#{offences.join("\n")}"
  end

  test 'stylesheets load dependencies with @use rather than @import' do
    offences = offences_for(/@import\s/)

    assert_empty offences,
                 '@import is deprecated and is removed in Dart Sass 3.0. Load the ' \
                 "partial with `@use \"base/tokens\" as *;` instead:\n#{offences.join("\n")}"
  end

  test 'application.scss is the only stylesheet entrypoint' do
    entrypoints = Dir.glob(STYLESHEET_ROOT.join('*.scss')).map { |f| File.basename(f) }

    assert_equal ['application.scss'], entrypoints,
                 'Add new stylesheets as partials imported by application.scss. A second ' \
                 'entrypoint also needs a config.dartsass.builds entry or it is never compiled.'
  end
end
