# frozen_string_literal: true

require 'test_helper'

module Dam
  module ResourceSpace
    # Collections are the one part of ResourceSpace that people built by hand,
    # so they come across with their order, their nesting, and their
    # identity — two of them share a name.
    class CollectionImportTest < ActiveSupport::TestCase
      setup do
        Dam::CollectionAsset.delete_all
        Dam::Collection.delete_all
        Dam::Asset.delete_all
        Dam::StorageLocation.delete_all
        @location = Dam::StorageLocation.create!(label: 'ResourceSpace', kind: 'disk')
        @assets = (1..4).to_h { |ref| [ref, asset(ref)] }
      end

      test 'two collections with the same name stay two collections' do
        run_import([source(28, 'Murals', [1, 2]), source(21, 'Murals', [3])])

        murals = Dam::Collection.where(name: 'Murals').order(:external_ref)

        assert_equal 2, murals.count
        members = murals.map { |collection| collection.ordered_assets.map(&:id) }

        assert_equal [[@assets[3].id], [@assets[1].id, @assets[2].id]], members
      end

      test 'members keep the order they had' do
        run_import([source(5, 'Picks', [3, 1, 2])])

        assert_equal [3, 1, 2].map { |ref| @assets[ref].id },
                     Dam::Collection.sole.ordered_assets.map(&:id)
      end

      test 'a nested collection keeps its parent, even when it comes first' do
        run_import([source(9, 'Child', [1], parent: 8), source(8, 'Parent', [2])])

        child = Dam::Collection.find_by!(name: 'Child')

        assert_equal 'Parent', child.parent.name
      end

      test 'a resource that did not come across is left out rather than failing' do
        run_import([source(5, 'Picks', [1, 999])])

        assert_equal [@assets[1].id], Dam::Collection.sole.ordered_assets.map(&:id)
      end

      test 'running it twice adds nothing the first run added' do
        sources = [source(5, 'Picks', [1, 2])]

        run_import(sources)
        run_import(sources)

        assert_equal 1, Dam::Collection.count
        assert_equal 2, Dam::CollectionAsset.count
      end

      private

      def source(ref, name, resources, parent: nil)
        { 'ref' => ref, 'name' => name, 'description' => '', 'parent' => parent, 'resources' => resources }
      end

      def run_import(sources) = CollectionImport.new(location: @location, collections: sources).call

      def asset(ref)
        Dam::Asset.create!(title: "Asset #{ref}", media_type: 'image', storage_location: @location,
                           external_ref: ref.to_s)
      end
    end
  end
end
