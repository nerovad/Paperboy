# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module HsaAdoptionCards
  # The PDF endpoint serves whatever CardFile resolves, so this is where the
  # confinement lives: a stored UNC path becomes a file under the mount or
  # nothing at all.
  class CardFileTest < ActiveSupport::TestCase
    MANAGED = [CardFile::WINDOWS_ENV, CardFile::LINUX_ENV].freeze

    setup do
      @old_env = MANAGED.to_h { |key| [key, ENV.fetch(key, nil)] }
      @mount = Dir.mktmpdir
      ENV[CardFile::WINDOWS_ENV] = '\\\\gsa-scan01\\hsa\\Adoption_Cards'
      ENV[CardFile::LINUX_ENV] = @mount
      FileUtils.mkdir_p(File.join(@mount, 'EXAMPLE FOLDER', 'Child'))
      @card = File.join(@mount, 'EXAMPLE FOLDER', 'Child', 'Child_56-93-013, 675-1.pdf')
      File.write(@card, '%PDF-1.7')
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@mount) if @mount && Dir.exist?(@mount)
    end

    test 'a stored UNC path resolves to the file under the mount' do
      assert_equal @card,
                   CardFile.resolve('\\\\gsa-scan01\\hsa\\Adoption_Cards\\EXAMPLE FOLDER\\Child\\Child_56-93-013, 675-1.pdf')
    end

    test 'the share prefix is matched without regard to case' do
      assert_equal @card,
                   CardFile.resolve('\\\\GSA-SCAN01\\HSA\\adoption_cards\\EXAMPLE FOLDER\\Child\\Child_56-93-013, 675-1.pdf')
    end

    test 'a path outside the share is refused' do
      error = assert_raises(FileUnavailable) { CardFile.resolve('\\\\gsa-scan01\\hsa\\Other\\x.pdf') }
      assert_match(/outside the scanned-cards folder/, error.message)
    end

    test 'a sibling folder sharing the root as a prefix is refused' do
      error = assert_raises(FileUnavailable) { CardFile.resolve('\\\\gsa-scan01\\hsa\\Adoption_Cards_old\\x.pdf') }
      assert_match(/outside the scanned-cards folder/, error.message)
    end

    test 'traversal is refused outright' do
      error = assert_raises(FileUnavailable) { CardFile.resolve('\\\\gsa-scan01\\hsa\\Adoption_Cards\\..\\..\\etc\\passwd.pdf') }
      assert_equal 'Invalid file path.', error.message
    end

    test 'only PDFs are served' do
      error = assert_raises(FileUnavailable) { CardFile.resolve('\\\\gsa-scan01\\hsa\\Adoption_Cards\\EXAMPLE FOLDER\\Child\\card.xml') }
      assert_equal 'Only PDF files can be opened.', error.message
    end

    test 'a blank path is refused' do
      assert_raises(FileUnavailable) { CardFile.resolve('') }
      assert_raises(FileUnavailable) { CardFile.resolve(nil) }
    end

    test 'a card not yet scanned is reported as such' do
      error = assert_raises(FileUnavailable) { CardFile.resolve('\\\\gsa-scan01\\hsa\\Adoption_Cards\\EXAMPLE FOLDER\\Child\\missing.pdf') }
      assert_match(/not found on the share/, error.message)
    end

    test 'a missing mount variable is loud and names itself' do
      ENV.delete(CardFile::LINUX_ENV)
      error = assert_raises(MissingConfiguration) { CardFile.resolve('\\\\gsa-scan01\\hsa\\Adoption_Cards\\x.pdf') }
      assert_includes error.message, CardFile::LINUX_ENV
    end

    test 'status reports an unconfigured, unreachable or connected share' do
      assert CardFile.status[:connected]

      ENV[CardFile::LINUX_ENV] = File.join(@mount, 'nope')
      refute CardFile.status[:connected]
      assert_match(/not reachable/, CardFile.status[:message])

      ENV.delete(CardFile::LINUX_ENV)
      refute CardFile.status[:connected]
      assert_match(/not configured/, CardFile.status[:message])
    end
  end
end
