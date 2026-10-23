# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application'
pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'
pin_all_from 'app/javascript/controllers', under: 'controllers'
pin 'form_navigation', to: 'form_navigation.js'
pin 'pb_modal', to: 'pb_modal.js'
pin 'pdf_js', to: 'pdf_js.js'
pin 'stamp_layout', to: 'stamp_layout.js'
pin 'choices_setup', to: 'choices_setup.js'
pin 'sortablejs', to: 'https://esm.sh/sortablejs@1.15.2'
# Served from the chartkick gem. Loaded on demand by sql_chart_controller.
pin 'chartkick', to: 'chartkick.js', preload: false
pin 'Chart.bundle', to: 'Chart.bundle.js', preload: false
