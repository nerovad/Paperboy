# frozen_string_literal: true

require 'test_helper'

# The Bates stamp tool (#230): its own grant; counters made and saved; a
# check stamps the first PDF and takes nothing; stamping returns the file or a
# zip and moves the counter on.
class BatesCountersControllerTest < ActionController::TestCase
  setup do
    @dir = Dir.mktmpdir
    session[:user] = { 'email' => 'clerk@example.com', 'employee_id' => 42 }
    granted(true)
    @counter = BatesCounter.create!(name: 'Request 2026-014', start_text: '000001', created_by: 'clerk@example.com')
  end

  teardown { FileUtils.rm_rf(@dir) }

  def granted(yes)
    @controller.helpers.define_singleton_method(:can_use_app_feature?) { |app, key| yes && app == 'paperboy' && key == 'bates_stamp' }
  end

  def upload(pages, name = 'doc.pdf')
    path = File.join(@dir, name)
    Prawn::Document.generate(path) { |doc| pages.times { |index| doc.start_new_page if index.positive? } }
    Rack::Test::UploadedFile.new(path, 'application/pdf', original_filename: name)
  end

  test 'nobody without the grant gets in' do
    granted(false)

    get :index

    assert_redirected_to root_path
  end

  test 'a counter is made, and its next number and stamp are saved' do
    post :create, params: { name: 'Matter 77', start: '0500' }
    made = BatesCounter.find_by!(name: 'Matter 77')
    assert_redirected_to edit_bates_counter_path(made)
    assert_equal [4, 500], [made.digits, made.next_number]

    get :edit, params: { id: made.id }
    assert_response :success
    assert_select '[data-controller=stamp-designer][data-stamp-designer-areas-value*=?]', '{number}'
    assert_select 'input[name=start][value=?]', '0500'

    patch :update, params: { id: made.id, start: '000777', first_page: '2', areas: [{ 'rows' => ['GSA-{number}'] }].to_json }
    made.reload
    assert_equal [6, 777, 2, ['GSA-{number}']], [made.digits, made.next_number, made.first_page, made.area_list.first['rows']]
  end

  test 'a check stamps the first PDF with the numbers on the page and takes none' do
    post :preview, params: { id: @counter.id, start: '000050', areas: [{ 'rows' => ['Some static text {number}'] }].to_json,
                             file: upload(2) }

    assert_response :success
    assert_includes PDF::Reader.new(StringIO.new(response.body)).pages.second.text, 'Some static text 000051'
    assert_equal [1, 0], [@counter.reload.next_number, @counter.runs.count]
  end

  test 'one PDF comes back stamped; several come back as a zip; the counter moves on' do
    post :stamp, params: { id: @counter.id, files: [upload(2, 'one.pdf')] }
    assert_response :success
    assert_equal 'application/pdf', response.media_type
    assert_equal '000001 - 000002', response.headers['X-Bates-Range']

    post :stamp, params: { id: @counter.id, files: [upload(1, 'a.pdf'), upload(2, 'b.pdf')] }
    assert_equal 'application/zip', response.media_type
    names = Zip::InputStream.open(StringIO.new(response.body)) { |zip| Array.new(2) { zip.get_next_entry.name } }
    assert_equal %w[01_a.pdf 02_b.pdf], names
    assert_equal [6, 2], [@counter.reload.next_number, @counter.runs.count]
  end

  test 'a file that is not a PDF is refused and no number is used' do
    path = File.join(@dir, 'note.pdf')
    File.write(path, 'hello')

    post :stamp, params: { id: @counter.id, files: [Rack::Test::UploadedFile.new(path, 'application/pdf')] }

    assert_response :unprocessable_content
    assert_match(/Upload one or more PDFs/, response.headers['X-Bates-Error'])
    assert_equal 1, @counter.reload.next_number
  end
end
