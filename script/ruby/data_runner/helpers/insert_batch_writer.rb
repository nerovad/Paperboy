# frozen_string_literal: true

module DataRunner
  class InsertBatchWriter
    DEFAULT_MAX_ROWS = 50
    DEFAULT_MAX_BYTES = 512 * 1024

    def initialize(client:, prefix:, max_rows: DEFAULT_MAX_ROWS, max_bytes: DEFAULT_MAX_BYTES)
      @client = client
      @prefix = prefix
      @max_rows = max_rows
      @max_bytes = max_bytes
      @values = []
      @bytes = 0
      @inserted = 0
    end

    def add(tuple)
      flush if full_with?(tuple)
      @values << tuple
      @bytes += tuple.bytesize
    end

    def finish
      flush
      @inserted
    end

    private

    def full_with?(tuple)
      @values.length >= @max_rows || (!@values.empty? && @bytes + tuple.bytesize > @max_bytes)
    end

    def flush
      return if @values.empty?

      @client.execute("#{@prefix}#{@values.join(', ')}").do
      @inserted += @values.length
      @values = []
      @bytes = 0
    end
  end
end
