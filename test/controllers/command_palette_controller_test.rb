# frozen_string_literal: true

require 'test_helper'

# The palette's contents — what ":" puts on screen. The keyboard that opens it
# is command_palette_controller.js; what matters here is that the response is a
# bare frame carrying the search box, the commands and the viewer's own forms.
class CommandPaletteControllerTest < ActionController::TestCase
  tests CommandPaletteController

  setup do
    session[:user] = {
      'employee_id' => 102_989,
      'email' => 'maria.acosta@example.com',
      'first_name' => 'Maria',
      'last_name' => 'Acosta'
    }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  def show_palette
    relation = Minitest::Mock.new
    relation.expect(:includes, [], [:form_fields])

    Forms::Template.stub(:active, relation) { get :show }
  end

  test 'show renders the palette frame with its search box' do
    show_palette

    assert_response :success
    assert_select 'turbo-frame#command_palette', count: 1
    assert_select 'input.pb-palette__input[data-sidebar-search-target=?]', 'input', count: 1
  end

  test 'show offers every search command' do
    show_palette

    assert_select '[data-sidebar-search-target=?]', 'command', count: SearchCommands::ALL.size
    assert_select '[data-command-event=?]', 'who-am-i:open', count: 1
  end

  # The palette is rendered by the layout on every page, and that copy already
  # holds a frame of this name. Sending the layout back would hand Turbo two
  # and it would fill the placeholder with itself.
  test 'show renders without the layout' do
    show_palette

    assert_select 'div.sidebar', count: 0
    assert_select '.pb-palette-backdrop', count: 0
  end

  test 'show lists the forms the viewer may open' do
    show_palette

    assert_select "a.pb-palette__row[data-sidebar-search-target='formLink']",
                  text: 'Leave of Absence', count: 1
  end

  test 'show refuses signed-out visitors' do
    session.delete(:user)

    get :show

    assert_response :forbidden
  end
end
