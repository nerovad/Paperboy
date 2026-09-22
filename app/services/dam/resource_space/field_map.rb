# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Where each ResourceSpace field lands in the DAM.
    #
    # Two of them are not metadata at all: the title and the description are
    # columns on the asset. The description is ResourceSpace's Caption, the
    # field people wrote sentences in — not its "Asset Description", which on
    # this library holds the top-level folder a file was synced from, and is
    # far more useful as a Category to filter by. The rest become Dam::MetadataField rows — named
    # here where ResourceSpace's own name would read badly ("ownerdepartment",
    # "text"), and otherwise kept as ResourceSpace had them, so a field that
    # appears after this was written still comes across rather than being
    # dropped.
    module FieldMap
      TITLE = 'title'
      DESCRIPTION = 'caption'
      ASSET_COLUMNS = [TITLE, DESCRIPTION].freeze

      RENAMED = {
        'originalfilename' => { key: 'original_filename', label: 'Original filename' },
        'assetdescription' => { key: 'category', label: 'Category' },
        'owneragency' => { key: 'agency', label: 'Agency' },
        'ownerdivision' => { key: 'division', label: 'Division' },
        'ownerdepartment' => { key: 'department', label: 'Department' },
        'ownerunit' => { key: 'unit', label: 'Unit' },
        'folderpath' => { key: 'folder_path', label: 'Folder path' },
        'date' => { key: 'captured_on', label: 'Captured on' },
        'text' => { key: 'extracted_text', label: 'Extracted text' },
        'extract' => { key: 'document_extract', label: 'Document extract' }
      }.freeze

      # ResourceSpace field types that hold a date: 4 is a date, 6 an expiry
      # date. Everything else is text as far as a filter is concerned.
      DATE_TYPES = [4, 6].freeze

      module_function

      def metadata?(name) = ASSET_COLUMNS.exclude?(name.to_s)

      def key_for(name)
        RENAMED.dig(name.to_s, :key) || name.to_s.parameterize(separator: '_')
      end

      # The Dam::MetadataField a ResourceSpace field becomes, given the row
      # Catalog#fields_in_use returned for it.
      def dam_field(field)
        name = field['name'].to_s
        {
          key: key_for(name),
          label: RENAMED.dig(name, :label) || field['title'].presence || name.titleize,
          field_type: DATE_TYPES.include?(field['type'].to_i) ? 'date' : 'text'
        }
      end
    end
  end
end
