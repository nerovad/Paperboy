# frozen_string_literal: true

# The one way an asset's bytes leave this app without a sign-in.
#
# Instagram — and any custom endpoint configured to be handed a link rather
# than a file — will not accept an upload; it fetches what it is pointed at.
# So a publication in flight carries a single-use token, and this serves that
# one asset for as long as that one publish is running, plus an hour's grace
# for a provider fetching slowly.
#
# Deliberately narrow: the token names a publication, the publication names an
# asset, and nothing else here is reachable. An unknown, spent or expired
# token is a plain 404 — saying which it was would be a way of testing them.
class DamMediaController < ApplicationController
  def show
    publication = Dam::Publication.find_by(public_token: params[:token])
    return head :not_found unless publication&.public_link_live?

    serve(publication.asset)
  end

  private

  def serve(asset)
    return head :not_found if asset.nil?
    return send_original(asset.original_path, asset) if asset.referenced?
    return head :not_found unless asset.file.attached?

    path = local_path(asset.file.blob)
    return send_original(path, asset) if path

    # Nothing local to send: hand out a signed link to the service instead,
    # rather than reading a two-gigabyte master through this process.
    redirect_to asset.file.blob.url(expires_in: 15.minutes, disposition: :inline), allow_other_host: true
  end

  def send_original(path, asset)
    return head :not_found if path.nil? || !File.file?(path.to_s)

    send_file path.to_s, filename: asset.filename, type: asset.content_type, disposition: 'inline'
  end

  # Disk services — which is what every storage location here uses — can say
  # where a blob actually is, so it streams off the filesystem.
  def local_path(blob)
    service = blob.service
    return nil unless service.respond_to?(:path_for)

    Pathname(service.path_for(blob.key))
  end
end
