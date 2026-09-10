# frozen_string_literal: true

module HsaAdoptionCards
  # The Maintenance screen: one button that rebuilds every case group after
  # a batch of cards has been keyed in. Its own ACL feature, because it
  # rewrites the links every searcher relies on and only the people keying
  # cards need it.
  class MaintenanceController < BaseController
    before_action { require_feature('maintenance') }

    def index
      @margin = CaseGroupRebuild::DEFAULT_MARGIN
    end

    # An ordinary form post rather than JSON: the result is a small table,
    # and a full page render keeps the confirm modal and flash in play.
    def rebuild
      @margin = params[:ambiguity_margin]
      @result = CaseGroupRebuild.call(margin: @margin)
      Rails.logger.info "HSA Adoption Card Search: #{app_user} rebuilt case groups " \
                        "(margin #{@result.margin}): #{@result.counts.inspect}"
      flash.now[:notice] = "Case groups rebuilt: #{@result.total} #{'group'.pluralize(@result.total)}."
      render :index
    rescue HsaAdoptionCards::Error => e
      Rails.logger.warn "HSA Adoption Card Search: rebuild by #{app_user} failed: #{e.message}"
      @error = e
      render :index, status: :unprocessable_entity
    end
  end
end
