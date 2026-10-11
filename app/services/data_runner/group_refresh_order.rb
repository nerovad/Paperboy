# frozen_string_literal: true

module DataRunner
  # Places each DSL after the dependencies that are in this same refresh.
  # Workers claim from the front of the queue and inject waits inside the
  # worker, so a child claimed before its parent can occupy every worker.
  class GroupRefreshOrder
    class Error < StandardError; end

    def self.entries(entries)
      new(entries).entries
    end

    def initialize(entries)
      @entries = entries
    end

    def entries
      names = @entries.map { |entry| entry.key.to_s }
      duplicates = names.tally.select { |_name, count| count > 1 }.keys
      raise Error, "duplicate refresh DSL: #{duplicates.join(', ')}" if duplicates.any?

      dependencies = @entries.to_h { |entry| [entry.key.to_s, dependencies_for(entry)] }
      require_scheduled!(dependencies)
      place(@entries.dup, dependencies)
    end

    private

    def dependencies_for(entry)
      config = entry.respond_to?(:config) ? entry.config : nil
      raw = config.is_a?(Hash) ? config[:dependency] : nil
      Array(raw).map(&:to_s).reject(&:empty?).uniq
    end

    def require_scheduled!(dependencies)
      scheduled = dependencies.keys
      dependencies.each do |name, parents|
        parents.each do |parent|
          next if scheduled.include?(parent)

          raise Error, "#{name}: dependency #{parent} is not scheduled in this run"
        end
      end
    end

    def place(pending, dependencies)
      ordered = []
      while pending.any?
        placed = ordered.map { |entry| entry.key.to_s }
        ready = pending.select { |entry| (dependencies.fetch(entry.key.to_s) - placed).empty? }
        raise Error, "circular refresh dependency: #{pending.map(&:key).join(', ')}" if ready.empty?

        ordered.concat(ready)
        pending -= ready
      end
      ordered
    end
  end
end
