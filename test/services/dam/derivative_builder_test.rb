# frozen_string_literal: true

require 'test_helper'

module Dam
  # The proxy and thumbnail are the only bytes the library keeps for a file it
  # references, so these cover both ways of getting them: adopting what is
  # already on the share, and building one when there is nothing to adopt.
  class DerivativeBuilderTest < ActiveSupport::TestCase
    setup do
      skip 'ImageMagick is not installed' unless system('which convert > /dev/null 2>&1')

      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Dam::Job.delete_all
      Dam::Asset.delete_all
      Dam::StorageLocation.delete_all
      @allowed = Pathname(Dir.mktmpdir('dam-roots'))
      @previous_roots = ENV.fetch('PAPERBOY_DAM_ROOTS', nil)
      ENV['PAPERBOY_DAM_ROOTS'] = @allowed.realpath.to_s
      @location = Dam::StorageLocation.create!(label: 'Share', kind: 'disk',
                                               root: @allowed.join('library').to_s,
                                               watch_path: @allowed.join('share').to_s,
                                               ingest_mode: 'reference')
      @share = Pathname(@location.watch_path)
      FileUtils.mkdir_p(@share)
    end

    teardown do
      ENV['PAPERBOY_DAM_ROOTS'] = @previous_roots
      FileUtils.rm_rf(@allowed)
    end

    test 'builds a proxy and a thumbnail from the referenced original' do
      asset = reference(image('wide.jpg', '2400x1200'))

      assert_equal 'ready', Dam::DerivativeBuilder.new(asset).call, asset.reload.derivative_error

      assert_predicate asset.proxy, :attached?
      assert_predicate asset.thumbnail, :attached?
      assert_operator asset.proxy.blob.byte_size, :<, asset.byte_size
      assert_equal [1600, 800], dimensions(asset.proxy)
      assert_equal [400, 200], dimensions(asset.thumbnail)
    end

    test 'a small original is not blown up into a larger proxy' do
      asset = reference(image('small.jpg', '120x60'))

      Dam::DerivativeBuilder.new(asset).call

      assert_equal [120, 60], dimensions(asset.proxy)
    end

    test 'adopts the previews ResourceSpace already made instead of building' do
      original = image('811_0cc6af587abbbc0.jpg', '2400x1200')
      image('811scr_a8869a6bfe3681c.jpg', '1400x700')
      image('811thm_a384db14dd8e6ac.jpg', '150x75')
      asset = reference(original)

      # Nothing may shell out: adoption is a copy, and that is the point of it.
      Dam::DerivativeBuilder.stub(:new, ->(*) { raise 'should not build' }) do
        assert Dam::AdoptedPreviews.new(asset).call
      end

      assert_equal [1400, 700], dimensions(asset.proxy)
      assert_equal [150, 75], dimensions(asset.thumbnail)
    end

    test 'previews belonging to another resource are not adopted' do
      asset = reference(image('811_0cc6af587abbbc0.jpg', '800x400'))
      image('922scr_a8869a6bfe3681c.jpg', '1400x700')

      assert_not Dam::AdoptedPreviews.new(asset).call
      assert_not asset.proxy.attached?
    end

    test 'a file that is not an image at all is recorded as failed, not raised' do
      broken = @share.join('broken.jpg')
      File.write(broken, 'this is not a jpeg')
      asset = reference(broken)

      assert_equal 'failed', Dam::DerivativeBuilder.new(asset).call
      assert_equal 'failed', asset.reload.derivative_state
      assert_match(/convert/, asset.derivative_error)
    end

    test 'a format nothing can draw is left alone rather than failed' do
      notes = @share.join('notes.txt')
      File.write(notes, 'nothing to see')
      asset = reference(notes)

      assert_equal 'none', Dam::DerivativeBuilder.new(asset).call
      assert_not asset.proxy.attached?
    end

    private

    def image(name, size)
      path = @share.join(name)
      system('convert', '-size', size, 'xc:red', path.to_s, exception: true)
      path
    end

    def reference(path)
      asset = Dam::Asset.new(storage_location: @location, uploaded_by_name: 'Test')
      asset.apply_reference_facts!(path)
      asset.save!
      asset
    end

    def dimensions(attachment)
      attachment.open do |file|
        output = `identify -format '%w %h' #{Shellwords.escape(file.path)}`
        output.split.map(&:to_i)
      end
    end
  end
end
