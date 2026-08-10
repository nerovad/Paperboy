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

  # The thumbnail for an asset card, or nil when there is nothing to draw.
  def dam_thumbnail_url(asset)
    return nil unless asset.image? && asset.file.attached?

    url_for(asset.file)
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
