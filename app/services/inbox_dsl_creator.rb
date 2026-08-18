# frozen_string_literal: true

require 'open3'

class InboxDslCreator
  Result = Data.define(:created_slugs, :output)

  def create!
    before = DslCatalog.entries.map(&:slug)
    output, status = Open3.capture2e(
      Gem.ruby,
      Rails.root.join('script/ruby/data_runner/commands/initial_dsl.rb').to_s,
      chdir: Rails.root.to_s
    )
    raise DslCreator::InvalidDsl, output unless status.success?

    DslCatalog.reload!
    Result.new(created_slugs: DslCatalog.entries.map(&:slug) - before, output: output)
  end
end
