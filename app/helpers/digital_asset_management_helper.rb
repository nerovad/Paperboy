# frozen_string_literal: true

# View helpers shared across the DAM screens.
module DigitalAssetManagementHelper
  # Emoji stand in for real thumbnails on anything we cannot draw inline.
  # Active Storage variants would need image_processing, which is not in the
  # Gemfile — until it is, images render their original blob and everything
  # else gets a glyph.
  MEDIA_GLYPHS = {
    'image' => '🖼️',
    'video' => '🎬',
    'audio' => '🎧',
    'document' => '📄',
    'other' => '📦'
  }.freeze

  STATE_VARIANTS = {
    'queued' => 'dam-pill--queued',
    'running' => 'dam-pill--running',
    'succeeded' => 'dam-pill--ok',
    'active' => 'dam-pill--ok',
    'failed' => 'dam-pill--bad',
    'cancelled' => 'dam-pill--muted',
    'revoked' => 'dam-pill--bad',
    'expired' => 'dam-pill--muted',
    'archived' => 'dam-pill--muted'
  }.freeze

  def dam_media_glyph(media_type)
    MEDIA_GLYPHS.fetch(media_type, MEDIA_GLYPHS['other'])
  end

  def dam_pill(state, label = nil)
    tag.span(label || state.to_s.titleize,
             class: "dam-pill #{STATE_VARIANTS.fetch(state.to_s, 'dam-pill--muted')}")
  end

  # A link a publishing service came back with, or nil when it is not one.
  # These are strings from somebody else's API, and they end up in an href, so
  # anything that is not plain http(s) is not offered as a link at all.
  def dam_published_url(url)
    parsed = URI.parse(url.to_s)
    parsed.is_a?(URI::HTTP) && parsed.host.present? ? parsed.to_s : nil
  rescue URI::InvalidURIError
    nil
  end

  # The thumbnail for an asset card, or nil when there is nothing to draw.
  # The built thumbnail first, whatever the media type — a video's poster
  # frame is a picture even though the video is not — then the stored original
  # for an image the builder has not reached yet.
  def dam_thumbnail_url(asset)
    return url_for(asset.thumbnail) if asset.thumbnail.attached?
    return url_for(asset.proxy) if asset.proxy.attached?
    return url_for(asset.file) if asset.image? && asset.file.attached?

    nil
  end

  # The largest copy worth putting on the detail page.
  def dam_preview_url(asset)
    return url_for(asset.proxy) if asset.proxy.attached?
    return url_for(asset.file) if asset.image? && asset.file.attached?

    dam_thumbnail_url(asset)
  end

  # Where "Download" goes: a referenced asset's original is streamed from the
  # share it lives on, a stored one straight off its service.
  def dam_original_url(asset)
    return original_digital_asset_management_asset_path(asset) if asset.referenced?

    asset.file.attached? ? url_for(asset.file) : nil
  end

  PREVIEW_STATE_LABELS = { 'ready' => 'ready', 'pending' => 'waiting',
                           'failed' => 'failed', 'none' => 'no preview possible' }.freeze

  def dam_preview_state_label(state) = PREVIEW_STATE_LABELS.fetch(state, state.to_s)

  # The sentence an administrator can act on. The raw text stays available
  # under Details, and is the only thing that helps when the sentence does not.
  def dam_failure_explanation(text) = Dam::FailureExplanation.for(text) || 'No reason was recorded.'

  # Everything the app actually knows, folded away until somebody asks — a
  # class name and a backtrace line are noise on a page about a library, and
  # the first thing wanted when the plain sentence is not enough.
  def dam_failure_details(text, path: nil)
    return nil if text.blank?

    tag.details(class: 'dam-failure-details') do
      concat tag.summary('Details')
      concat tag.pre([path.presence, text].compact.join("\n\n"))
    end
  end

  def dam_star_button(subject, favorited:, label: nil)
    type = subject.is_a?(Dam::Collection) ? 'collection' : 'asset'
    button_to digital_asset_management_favorites_path,
              method: :post,
              params: { subject_type: type, subject_id: subject.id },
              class: "btn compact dam-star#{' is-starred' if favorited}",
              form: { class: 'dam-star-form' },
              title: favorited ? 'Remove from favorites' : 'Add to favorites' do
      concat(favorited ? '★' : '☆')
      concat(" #{label}") if label
    end
  end

  # Whether a storage location is taking uploads, and if not, why. Reads the
  # reason off the model so the pill cannot drift from what the ingest form
  # offers or what the asset validation allows.
  def dam_storage_state_pill(location, used_bytes = nil)
    case location.refusal_reason(used_bytes || location.used_bytes)
    when nil then dam_pill('active', 'Accepting uploads')
    when 'disabled' then dam_pill('cancelled', 'Disabled')
    when 'read-only' then dam_pill('archived', 'Read-only')
    else dam_pill('failed', 'At capacity')
    end
  end

  # Capacity bar for a location that has a quota. Nil percent means no quota
  # is set, and a location with no quota draws no bar rather than an empty one
  # — "not measured" and "empty" are different facts.
  def dam_usage_meter(percent)
    return nil if percent.nil?

    variant = if percent >= 100 then ' dam-progress--full'
              elsif percent >= 80 then ' dam-progress--warn'
              else ''
              end

    tag.div(tag.span(style: "width: #{percent}%"),
            class: "dam-progress#{variant}", role: 'img',
            aria: { label: "#{percent} percent of capacity used" })
  end

  def dam_duration(seconds)
    return nil if seconds.blank? || seconds.to_i.zero?

    Time.at(seconds.to_i).utc.strftime(seconds.to_i >= 3600 ? '%H:%M:%S' : '%M:%S')
  end
end
