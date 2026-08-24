# frozen_string_literal: true

module P2m
  class OmsUploadsController < ApplicationController
    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }

    def index
      @uploads = OmsUpload.includes(:files).newest_first
    end
  end
end
