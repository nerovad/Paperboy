# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Writes everything the DAM needs from ResourceSpace into one folder that
    # can be copied to another server and imported there — so the server the
    # DAM runs on never has to reach ResourceSpace's database, and nothing is
    # lost once ResourceSpace is switched off.
    #
    #   catalog.json             every live resource, field and collection
    #   previews/<ref>-*.jpg     the one proxy and one thumbnail it had made
    #   originals/<ref>/<name>   originals that lived inside its own filestore
    #
    # Originals on the graphics share are not copied: the DAM goes on reading
    # them where they are. The ones inside the filestore exist nowhere else,
    # and are the one thing that would be lost with ResourceSpace.
    #
    # Safe to run again: a file already in the bundle at the same size is not
    # copied twice, so an export interrupted halfway picks up where it was.
    class Export
      FORMAT = 1

      Stats = Struct.new(:resources, :previews, :originals, :bytes, keyword_init: true) do
        def to_s
          "#{resources} resources, #{previews} previews, #{originals} originals " \
            "(#{ActiveSupport::NumberHelper.number_to_human_size(bytes)} copied)"
        end
      end

      def initialize(out:, catalog: Catalog.new, filestore_root: nil, limit: nil, progress: nil)
        @out = Pathname(out)
        @catalog = catalog
        @filestore_root = filestore_root || ENV.fetch('RS_FILESTORE', '/var/www/html/resourcespace/filestore')
        @limit = limit
        @progress = progress
        @stats = Stats.new(resources: 0, previews: 0, originals: 0, bytes: 0)
      end

      def call
        FileUtils.mkdir_p([@out.join('previews'), @out.join('originals')])
        index = FilestoreIndex.new(@filestore_root).build
        fields = @catalog.fields_in_use
        resources = each_resource.map { |row, metadata| record(row, metadata, index[row['ref'].to_i]) }

        write_catalog(fields, resources)
        @stats
      end

      private

      def each_resource
        Enumerator.new do |yielder|
          after = 0
          loop do
            page = @catalog.resources(after_ref: after, limit: 500)
            page = page.first(@limit - @stats.resources) if @limit
            break if page.empty?

            metadata = @catalog.metadata_for(page.map { |row| row['ref'].to_i })
            page.each { |row| yielder << [row, metadata.fetch(row['ref'].to_i, {})] }
            after = page.last['ref'].to_i
          end
        end
      end

      def record(row, metadata, entry)
        ref = row['ref'].to_i
        @stats.resources += 1
        @progress&.call(@stats) if (@stats.resources % 500).zero?

        { 'ref' => ref, 'title' => metadata[FieldMap::TITLE].presence || row['title'].presence,
          'description' => metadata[FieldMap::DESCRIPTION].presence,
          'file_extension' => row['file_extension'], 'file_path' => row['file_path'].presence,
          'created_at' => row['creation_date']&.to_s,
          'original_filename' => metadata['originalfilename'].presence,
          'original' => copy_original(ref, entry, metadata),
          'proxy' => copy_preview(ref, entry&.proxy, 'proxy'),
          'thumbnail' => copy_preview(ref, entry&.thumbnail, 'thumbnail'),
          'metadata' => dam_metadata(metadata) }
      end

      def dam_metadata(metadata)
        metadata.select { |name, _| FieldMap.metadata?(name) }
                .transform_keys { |name| FieldMap.key_for(name) }
      end

      def copy_original(ref, entry, metadata)
        return nil unless entry&.original

        name = metadata['originalfilename'].presence || entry.original.basename.to_s
        copy(entry.original, "originals/#{ref}/#{File.basename(name)}", :originals)
      end

      def copy_preview(ref, source, kind)
        source && copy(source, "previews/#{ref}-#{kind}.jpg", :previews)
      end

      def copy(source, relative, counter)
        target = @out.join(relative)
        unless target.file? && target.size == source.size
          FileUtils.mkdir_p(target.dirname)
          FileUtils.cp(source, target)
          @stats.bytes += target.size
        end
        @stats[counter] += 1
        relative
      end

      def write_catalog(fields, resources)
        document = {
          'format' => FORMAT, 'exported_at' => Time.current.iso8601,
          'fields' => fields.select { |field| FieldMap.metadata?(field['name']) }.map { |field| FieldMap.dam_field(field) },
          'collections' => @catalog.collections, 'resources' => resources
        }
        File.write(@out.join('catalog.json'), JSON.pretty_generate(document))
      end
    end
  end
end
