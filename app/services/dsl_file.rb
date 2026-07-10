# frozen_string_literal: true

class DslFile
  def initialize(entry)
    @entry = entry
  end

  def read
    @entry.path.read
  end

  def write!(source)
    RubyVM::InstructionSequence.compile(source, @entry.path.to_s)
    temporary = @entry.path.sub_ext(".rb.tmp")
    temporary.write(source)
    File.rename(temporary, @entry.path)
    DslCatalog.reload!
  ensure
    temporary&.delete if temporary&.exist?
  end
end
