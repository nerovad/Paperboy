# frozen_string_literal: true

require 'test_helper'

# Guards the Choices.js dropdown setup.
#
# Choices 10.2.0 reads an <option>'s label with `option.innerHTML` — the escaped
# source, "A &amp; B" — but with allowHTML: false writes it back with
# `innerText`, so the entity renders literally. app/javascript/choices_setup.js
# decodes the label just before render and pins allowHTML off.
#
# It only helps if every dropdown goes through it, so these assertions exist to
# stop a new one being built with a bare options object.
class ChoicesConventionsTest < ActiveSupport::TestCase
  JAVASCRIPT_ROOT = Rails.root.join('app/javascript')
  SETUP_MODULE    = 'choices_setup'

  # `new Choices(...)`, however the library got into scope — window.Choices, a
  # ChoicesLib alias, or the one-letter local nhtsa_vehicle uses. Deliberately
  # narrow: the loose version also matched setChoices() and _destroyMakeChoices().
  CONSTRUCTOR = /\bnew\s+(?:window\.)?(?:\w*Choices\w*|C)\s*\(/

  def javascript_files
    @javascript_files ||= Dir.glob(JAVASCRIPT_ROOT.join('**/*.js'))
  end

  def constructor_lines
    javascript_files.flat_map do |path|
      next [] if path.end_with?("#{SETUP_MODULE}.js")

      File.readlines(path).each_with_index.filter_map do |line, i|
        next unless line.match?(CONSTRUCTOR)

        ["#{Pathname.new(path).relative_path_from(Rails.root)}:#{i + 1}", line.strip]
      end
    end
  end

  test 'every Choices dropdown is built through choicesOptions' do
    offenders = constructor_lines.reject { |_where, line| line.include?('choicesOptions(') }

    assert_empty offenders.map(&:first),
                 "build these with choicesOptions(...) from #{SETUP_MODULE} so labels decode:\n" \
                 "#{offenders.map { |where, line| "  #{where}  #{line}" }.join("\n")}"
  end

  test 'no dropdown sets allowHTML for itself' do
    offenders = javascript_files.reject { |p| p.end_with?("#{SETUP_MODULE}.js") }.flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, i|
        next unless line =~ /allowHTML\s*:/

        "#{Pathname.new(path).relative_path_from(Rails.root)}:#{i + 1}"
      end
    end

    assert_empty offenders,
                 "allowHTML is pinned in #{SETUP_MODULE}.js and is not a caller's to set: #{offenders.join(', ')}"
  end

  test 'every file that builds a dropdown imports the shared setup' do
    users = constructor_lines.map { |where, _line| where.split(':').first }.uniq

    missing = users.reject { |path| File.read(Rails.root.join(path)).include?(%(from "#{SETUP_MODULE}")) }

    assert_empty missing, "missing `import { choicesOptions } from \"#{SETUP_MODULE}\"`: #{missing.join(', ')}"
  end

  test 'the shared setup is pinned in the importmap' do
    assert_includes File.read(Rails.root.join('config/importmap.rb')), "pin '#{SETUP_MODULE}'"
  end

  # Pinning alone is not enough: sprockets refuses to serve a module that no
  # manifest links, and every page carrying an importmap 500s rather than the
  # dropdown quietly degrading.
  test 'the shared setup is linked in the sprockets manifest' do
    assert_includes File.read(Rails.root.join('app/assets/config/manifest.js')),
                    "//= link #{SETUP_MODULE}.js"
  end
end
