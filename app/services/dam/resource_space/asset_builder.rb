# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Turns one exported ResourceSpace resource into an asset.
    #
    # An original that lived inside ResourceSpace's own filestore exists
    # nowhere else, so the DAM stores it — once ResourceSpace goes, that copy is
    # the only one. An original on the graphics share stays where it is and is
    # referenced. Either way the previews ResourceSpace already made are
    # adopted rather than rebuilt.
    #
    # Gives back :adopted or :queued, so the import can say how much work it
    # saved, and so only the assets with nothing to adopt go near ffmpeg.
    class AssetBuilder
      Upload = Data.define(:original_filename, :content_type, :size)

      def initialize(asset, record:, original:, store:, previews:)
        @asset = asset
        @record = record
        @original = original
        @store = store
        @previews = previews
      end

      def call
        @store ? store_original : @asset.apply_reference_facts!(@original)
        @asset.title = title
        @asset.description = @record['description']
        @asset.uploaded_by_name = Import::UPLOADER_NAME
        @asset.ingested_at ||= parse_time(@record['created_at'])
        Dam::MetadataAssignment.apply(@asset, @record['metadata'])
        @asset.save!

        attach_previews
      end

      private

      # Attached once. A second import of the same resource finds the file
      # already there and leaves it, rather than storing a second copy and
      # purging the first.
      def store_original
        @asset.storage_kind = 'stored'
        @asset.source_path = nil
        @asset.source_key = nil
        return if @asset.file.attached?

        filename = @record['original_filename'].presence || @original.basename.to_s
        content_type = Marcel::MimeType.for(@original, name: filename)
        @asset.apply_file_facts!(Upload.new(filename, content_type, @original.size))
        @asset.file.attach(io: File.open(@original, 'rb'), filename: filename, content_type: content_type)
      end

      # ResourceSpace's title, else the name the file was uploaded under —
      # never the hashed name its filestore gave it.
      def title
        @record['title'].presence || @record['original_filename'].presence ||
          @original.basename(@original.extname).to_s
      end

      def attach_previews
        attach(:proxy, @previews[:proxy])
        attach(:thumbnail, @previews[:thumbnail])
        return queue_build unless @asset.proxy.attached?

        @asset.update_columns(derivative_state: 'ready', derivative_error: nil)
        :adopted
      end

      def attach(name, path)
        return if path.blank? || @asset.public_send(name).attached?

        @asset.public_send(name).attach(io: File.open(path, 'rb'), filename: "#{@asset.id}-#{name}.jpg",
                                        content_type: 'image/jpeg')
      end

      def queue_build
        Dam::BuildDerivativesJob.perform_later(@asset.id)
        :queued
      end

      def parse_time(value) = value.presence && Time.zone.parse(value.to_s)
    end
  end
end
