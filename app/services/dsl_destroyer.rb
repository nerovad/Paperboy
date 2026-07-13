# frozen_string_literal: true

class DslDestroyer
  def initialize(entry, root: Rails.root)
    @entry = entry
    @root = Pathname(root)
  end

  def destroy!
    workflow_files = WorkflowOutputs.new(@entry, root: @root).files
    workflow_files.each(&:delete)
    @entry.path.delete
    DslCatalog.reload! if @root == Rails.root
    workflow_files
  end
end
