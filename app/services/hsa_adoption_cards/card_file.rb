# frozen_string_literal: true

module HsaAdoptionCards
  # Turns a card's stored Filepath — a UNC path under the scanned-cards share,
  # as the Scan Center keys it — into a file this server can read.
  #
  # The share is mounted on the Paperboy servers (and mapped to a drive on a
  # workstation), so two variables describe the same folder twice:
  #
  #   HSA_ADOPT_WINDOWS_BASE_PATH  the root as the database spells it,
  #                                e.g. \\gsa-scan01\hsa\Adoption_Cards
  #   HSA_ADOPT_LINUX_BASE_PATH    where that root is mounted here, e.g. /mnt/g
  #
  # Only files inside that root are ever served. A path is refused outright
  # for anything other than a .pdf, for any ".." segment, and for resolving
  # anywhere but under the mount — so the PDF endpoint cannot be turned into
  # a read-any-file hole. Nothing here writes; the source scans stay as they
  # are.
  class CardFile
    WINDOWS_ENV = 'HSA_ADOPT_WINDOWS_BASE_PATH'
    LINUX_ENV = 'HSA_ADOPT_LINUX_BASE_PATH'

    attr_reader :unc_path

    def self.resolve(unc_path)
      new(unc_path).resolve
    end

    # Lenient: tells the page whether the viewer can work at all.
    def self.status
      root = ENV.fetch(LINUX_ENV, nil).presence
      return { connected: false, message: 'The scanned-cards share is not configured.' } if root.nil?
      return { connected: false, message: 'The scanned-cards share is not reachable.' } unless Dir.exist?(root)

      { connected: true, message: 'Connected.' }
    end

    def initialize(unc_path)
      @unc_path = unc_path.to_s
    end

    # => absolute path of an existing PDF under the mount, or raises
    #    FileUnavailable with a message for the screen.
    def resolve
      raise FileUnavailable, 'No file path supplied.' if unc_path.strip.empty?
      raise FileUnavailable, 'Only PDF files can be opened.' unless unc_path.match?(/\.pdf\z/i)
      raise FileUnavailable, 'Invalid file path.' if unc_path.include?('..')

      full = File.expand_path(translated)
      raise FileUnavailable, 'That file is outside the scanned-cards folder.' unless full.start_with?(mount_root)
      raise FileUnavailable, 'The scanned card was not found on the share. It may not be scanned yet.' unless File.file?(full)

      full
    end

    private

    def windows_base
      ENV.fetch(WINDOWS_ENV, nil).presence || raise(MissingConfiguration.for(WINDOWS_ENV, 'The scanned-cards share'))
    end

    def linux_base
      ENV.fetch(LINUX_ENV, nil).presence || raise(MissingConfiguration.for(LINUX_ENV, 'The scanned-cards mount'))
    end

    # Trailing separator on purpose: without it "<root>_old/x.pdf" would pass
    # a plain start_with? against "<root>".
    def mount_root
      File.join(File.expand_path(linux_base), '')
    end

    # Case-insensitive on the prefix, because Windows paths are; the rest of
    # the path keeps its case, because the mount may not be.
    def translated
      prefix = windows_base.tr('\\', '/').chomp('/')
      given = unc_path.tr('\\', '/')
      raise FileUnavailable, 'That file is outside the scanned-cards folder.' unless given.downcase.start_with?("#{prefix.downcase}/")

      File.join(linux_base, given[(prefix.length + 1)..])
    end
  end
end
