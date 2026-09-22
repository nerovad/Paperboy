# frozen_string_literal: true

module DigitalAssetManagement
  # Serves an asset's original, proxy or thumbnail to the person a page
  # issued the link to. See Dam::FileToken for why the DAM does not hand out
  # stock Active Storage URLs.
  #
  # Deliberately not a BaseController: it answers every <img> on a grid, and
  # the sidebar facets and ACL lookups that controller runs per request would
  # be paid once per thumbnail. The token already carries the answer.
  #
  # Anything wrong — no session, a token for someone else, a forged or
  # expired one, a copy that does not exist — is a plain 404.
  class FilesController < ApplicationController
    include ActiveStorage::SetCurrent

    # Long enough to start a video; Range requests for the rest of it go
    # straight to the service URL this redirects to.
    SERVICE_URL_LIFETIME = 5.minutes

    def show
      claims = Dam::FileToken.read(params[:token])
      return head :not_found unless claims && current_user
      return head :not_found unless claims['employee'] == current_user.employee_id.to_s

      attachment = Dam::Asset.find_by(id: claims['asset'])&.public_send(claims['variant'])
      return head :not_found unless attachment&.attached?

      redirect_to attachment.blob.url(expires_in: SERVICE_URL_LIFETIME, disposition: claims['disposition'].to_sym)
    end
  end
end
