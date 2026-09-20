# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Turns one ResourceSpace resource into a referenced asset: its title and
    # metadata from the catalogue, its original left where it stands, and the
    # previews it already has adopted rather than rebuilt.
    #
    # Gives back :adopted or :queued, so the caller can tell how much work the
    # import saved — and so the assets with nothing to adopt are the only ones
    # that go near ffmpeg.
    class AssetBuilder
      def initialize(asset, row:, path:, metadata:, entry:)
        @asset = asset
        @row = row
        @path = path
        @metadata = metadata
        @entry = entry
      end

      def call
        @asset.apply_reference_facts!(@path)
        @asset.title = title
        @asset.description = @metadata['caption'].presence || @metadata['notes'].presence
        @asset.uploaded_by_name = Import::UPLOADER_NAME
        @asset.ingested_at ||= parse_time(@row['creation_date'])
        Dam::MetadataAssignment.apply(@asset, metadata_values)
        @asset.save!

        attach_previews
      end

      private

      # A title from ResourceSpace, else the original's filename — never the
      # hashed name, which is what made a filename-only import useless.
      def title
        @metadata[Catalog::TITLE_FIELD].presence ||
          @row['title'].presence ||
          @metadata['original_filename'].presence ||
          @path.basename(@path.extname).to_s
      end

      def metadata_values
        Catalog::FIELDS.values.index_with { |key| @metadata[key] }.compact_blank
      end

      # :adopted when a proxy came off the share; :queued when there was
      # nothing to adopt and the builder will make one.
      def attach_previews
        return queue_build unless @entry

        attach(:proxy, @entry.proxy)
        attach(:thumbnail, @entry.thumbnail)
        return queue_build unless @asset.proxy.attached?

        @asset.update_columns(derivative_state: 'ready', derivative_error: nil)
        :adopted
      end

      def attach(name, path)
        return if path.blank?

        @asset.public_send(name).attach(io: File.open(path, 'rb'),
                                        filename: "#{@asset.id}-#{name}.jpg",
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
