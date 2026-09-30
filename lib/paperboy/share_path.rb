# frozen_string_literal: true

module Paperboy
  # Translates between a Windows share path (as a database or LockBox spells
  # it, e.g. \\gsa-scan01\hsa\Adoption_Cards\x.pdf) and where that share is
  # mounted on this server (e.g. /mnt/a/HSA_Adoption_Cards/x.pdf).
  #
  #   share = Paperboy::SharePath.new(windows_base: '\\\\server\\share', linux_base: '/mnt/share')
  #   share.to_linux('\\\\SERVER\\Share\\a\\b.pdf')  # => "/mnt/share/a/b.pdf"
  #   share.to_linux('\\\\other\\x.pdf')             # => nil (not under the share)
  #   share.to_windows('/mnt/share/a/b.pdf')       # => "\\\\server\\share\\a\\b.pdf"
  #
  # Only a leading base is replaced, never the same text further along the
  # path. The Windows side matches case-insensitively, as Windows does, and
  # either slash; the Linux side matches exactly, as Linux does. The part of
  # the path after the base keeps its case, because the mount may not be
  # case-insensitive. A base must be followed by a separator (or end the
  # path), so \\server\share_old never passes for \\server\share.
  class SharePath
    attr_reader :windows_base, :linux_base

    def initialize(windows_base:, linux_base:)
      @windows_base = windows_base.to_s.tr('\\', '/').chomp('/')
      @linux_base = linux_base.to_s.chomp('/')
    end

    # The mounted path for a share path, with forward slashes, or nil when the
    # path is not under the Windows base.
    def to_linux(path)
      rest = remainder(path.to_s.tr('\\', '/'), windows_base, case_sensitive: false)
      rest && join(linux_base, rest)
    end

    # The share path for a mounted path, with backslashes, or nil when the
    # path is not under the Linux base.
    def to_windows(path)
      rest = remainder(path.to_s, linux_base, case_sensitive: true)
      rest && join(windows_base, rest).tr('/', '\\')
    end

    def under_windows_base?(path) = !to_linux(path).nil?

    private

    # What follows +base+ in +path+ ("" for the base itself), or nil when the
    # path does not start with the base.
    def remainder(path, base, case_sensitive:)
      return nil if base.empty?

      head = path[0, base.length]
      return nil unless case_sensitive ? head == base : head.casecmp?(base)

      rest = path[base.length..]
      return '' if rest.empty?

      rest.start_with?('/') ? rest.sub(%r{\A/+}, '') : nil
    end

    def join(base, rest) = rest.empty? ? base : "#{base}/#{rest}"
  end
end
