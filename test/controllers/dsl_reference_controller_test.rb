# frozen_string_literal: true

require 'test_helper'

class DslReferenceControllerTest < ActionController::TestCase
  tests DataRunner::DslReferencesController

  test 'renders the configured reference folder contents' do
    sign_in
    entries = [DirectoryListing::Entry.new(name: 'ovs-1.xml', directory: false,
                                           size: 12, modified: Time.zone.local(2026, 8, 17))]
    listing = Object.new
    listing.define_singleton_method(:call) { entries }

    DirectoryListing.stub(:new, listing) do
      get :show, params: { name: 'oversized' }
    end

    assert_response :success
    assert_select 'h2', text: 'Monthly Exports'
    assert_select 'td', text: 'ovs-1.xml'
    assert_select 'td', text: '12 Bytes'
  end

  test 'reports when the reference folder is unavailable' do
    sign_in
    listing = Object.new
    listing.define_singleton_method(:call) do
      raise DirectoryListing::Unavailable, 'The folder is currently unavailable.'
    end

    DirectoryListing.stub(:new, listing) do
      get :show, params: { name: 'oversized' }
    end

    assert_response :service_unavailable
    assert_select 'p', text: 'The folder is currently unavailable.'
  end

  private

  def sign_in
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
  end
end
