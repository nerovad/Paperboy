# frozen_string_literal: true

require 'test_helper'

# submit's value is the visible label. Apply must be a button so the label
# stays "Apply changes" while the posted value is still "1".
class DevelopmentHelperTest < ActionView::TestCase
  self.fixture_table_names = []

  test 'update issue apply button posts apply without replacing its label' do
    script = Development::ScriptCatalog.find('update_issue')

    render partial: 'development/runs/card', locals: { script: script }

    assert_select 'button.btn.warning[type=submit][name=apply][value="1"]', text: 'Apply changes' do |buttons|
      button = buttons.first
      assert_equal script[:confirm], button['data-turbo-confirm']
      assert_equal 'Apply issue update', button['data-confirm-title']
      assert_equal 'Apply', button['data-confirm-label']
    end
    assert_select 'input.btn.secondary[type=submit][name=commit][value="Preview changes"]'
    assert_select 'input[name=apply]', count: 0
    assert_select 'input[data-turbo-confirm]', count: 0
  end
end
