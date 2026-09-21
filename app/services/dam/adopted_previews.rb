# frozen_string_literal: true

module Dam
  # Takes the preview images whatever wrote the share has already made, rather
  # than making them again.
  #
  # ResourceSpace keeps each resource in its own folder and writes the original
  # as <id>_<hash>.<ext> with five sized copies beside it — 811_ab.jpg next to
  # 811scr_cd.jpg, 811thm_ef.jpg and so on. Where those exist, ingest is a copy
  # of a couple of hundred kilobytes instead of a pass through ImageMagick, and
  # for 3,000 resources that is the difference between minutes and hours.
  #
  # The copies are taken rather than referenced, so the library still works
  # once ResourceSpace is switched off and its filestore goes away.
  class AdoptedPreviews
    # ResourceSpace's size codes, best first: scr is a screen-sized copy, pre a
    # preview, col a collection tile. thm is the small square one.
    PROXY_CODES = %w[scr pre col].freeze
    THUMBNAIL_CODES = %w[thm col pre].freeze

    # <id>_<hash>.<ext> — the original. A sized copy carries its code between
    # the id and the underscore, which is exactly what tells them apart.
    ORIGINAL_NAME = /\A(?<id>\d+)_(?<hash>[0-9a-f]+)\.(?<extension>[A-Za-z0-9]+)\z/

    def initialize(asset)
      @asset = asset
    end

    # True when at least a proxy was adopted, so the builder can stop.
    def call
      return false unless folder

      proxy = find(PROXY_CODES)
      return false if proxy.blank?

      attach(:proxy, proxy)
      thumbnail = find(THUMBNAIL_CODES)
      attach(:thumbnail, thumbnail) if thumbnail
      true
    end

    private

    def folder
      return nil unless @asset.referenced?

      path = @asset.original_path
      @match = path && ORIGINAL_NAME.match(path.basename.to_s)
      @match && path.dirname
    end

    # The first size that exists, at the resource id this original belongs to.
    # The hash differs per file, so the code and the id are all there is to
    # match on.
    def find(codes)
      candidates = codes.filter_map { |code| Dir.glob(folder.join("#{@match[:id]}#{code}_*.jpg")).min }
      candidates.map { |path| Pathname(path) }.find { |path| path.file? && path.size.positive? }
    end

    def attach(name, path)
      @asset.public_send(name).attach(io: File.open(path, 'rb'),
                                      filename: "#{@asset.id}-#{name}.jpg",
                                      content_type: 'image/jpeg')
    end
  end
end
