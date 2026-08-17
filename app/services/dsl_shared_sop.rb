# frozen_string_literal: true

class DslSharedSop
  ROOT = Rails.root.join('config/data_runner/dsl/shared')
  NAME_PATTERN = /\A[a-z0-9_]+\z/

  def self.fetch!(name)
    key = name.to_s
    raise KeyError, "Unknown shared SOP: #{key}" unless NAME_PATTERN.match?(key)

    path = ROOT.join("#{key}.rb")
    raise KeyError, "Unknown shared SOP: #{key}" unless path.file?

    value = TOPLEVEL_BINDING.eval(path.read, path.to_s)
    raise TypeError, "Shared SOP #{key} must return a Hash" unless value.is_a?(Hash)

    value
  end
end
