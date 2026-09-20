# frozen_string_literal: true

module Dam
  # Turns what went wrong into a sentence somebody can act on.
  #
  # The raw text is an exception class and message, or a validation message,
  # and it is kept — the Storage screen offers it under Details, and it is what
  # anyone debugging actually needs. But "Errno::ENOENT: No such file or
  # directory - convert" tells an administrator nothing about the fact that a
  # server is missing ImageMagick, and that is the sentence worth leading with.
  #
  # Anything unrecognised falls through to a plain statement rather than a
  # guess, since a wrong explanation is worse than none.
  class FailureExplanation
    Rule = Struct.new(:pattern, :summary)

    RULES = [
      Rule.new(/Errno::ENOENT.*\b(convert|magick)\b/i,
               'ImageMagick is not installed on this server, so no still image can be made.'),
      Rule.new(/Errno::ENOENT.*\bffmpeg\b/i,
               'ffmpeg is not installed on this server, so no frame can be taken from a video.'),
      Rule.new(/Errno::ENOENT.*\bpdftoppm\b/i,
               'poppler-utils is not installed on this server, so no page of a PDF can be drawn.'),
      Rule.new(/no (decode|encode) delegate/i,
               "This server's ImageMagick was built without support for that format."),
      Rule.new(/not authorized|security policy/i,
               "This server's ImageMagick policy refuses that format. See /etc/ImageMagick-6/policy.xml."),
      Rule.new(/timed out/i,
               'The file took longer than ten minutes to process and was stopped.'),
      Rule.new(/Errno::EACCES|Permission denied/i,
               'The file could not be read. Check the permissions on the share.'),
      Rule.new(/Errno::EHOSTDOWN|Errno::ENOTCONN|Host is down|Errno::ESTALE/i,
               'The share was unreachable when this ran. It may simply need trying again.'),
      Rule.new(/Errno::ENOENT|No such file/i,
               'The file is no longer where the library expects it.'),
      Rule.new(/truncated|ValueTooLong/i,
               'A value from the source was too long for the column it was going into.'),
      Rule.new(/is not one of the formats/i,
               'This location does not take that format.'),
      Rule.new(/cannot take new uploads|at capacity|read-only|disabled/i,
               'The location was closed to new files at the time.'),
      Rule.new(/improper image header|Not a JPEG|corrupt|premature end/i,
               'The file is damaged, or is not the format its name claims.')
    ].freeze

    FALLBACK = 'It could not be processed. The details below say why.'

    def self.for(text)
      return nil if text.blank?

      RULES.find { |rule| rule.pattern.match?(text.to_s) }&.summary || FALLBACK
    end
  end
end
