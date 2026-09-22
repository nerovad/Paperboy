# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Writes a bundle the way Dam::ResourceSpace::Export would, from a few
    # hashes, so the import can be tested against the folder it will actually
    # be handed.
    module BundleBuilder
      def build_bundle(root, resources: [], fields: [], collections: [], files: {})
        files.each do |relative, body|
          path = Pathname(root).join(relative)
          FileUtils.mkdir_p(path.dirname)
          File.write(path, body)
        end
        FileUtils.mkdir_p(root)
        File.write(Pathname(root).join('catalog.json'),
                   JSON.generate('format' => Export::FORMAT, 'exported_at' => '2026-09-22T09:00:00Z',
                                 'fields' => fields, 'collections' => collections, 'resources' => resources))
        Bundle.new(root)
      end

      def exported_resource(ref, **attributes)
        { 'ref' => ref, 'title' => "Resource #{ref}", 'description' => nil, 'file_extension' => 'jpg',
          'file_path' => nil, 'created_at' => '2024-03-01 10:00:00', 'original_filename' => nil,
          'original' => nil, 'proxy' => nil, 'thumbnail' => nil, 'metadata' => {} }
          .merge(attributes.transform_keys(&:to_s))
      end
    end
  end
end
