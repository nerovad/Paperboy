# frozen_string_literal: true

# The things a search box can *do*, as opposed to the forms it can open.
#
# Two surfaces render this list: the Paperboy sidebar's search, and the command
# palette that ":" opens from anywhere. A command is activated by dispatching
# its window event, so whatever answers it — a dialog in the layout, a
# controller on a page — need not sit anywhere near the row that was clicked.
#
#   label  what the row reads
#   event  the window event dispatched when the row is chosen
#   terms  every word the command answers to; it is offered once each word
#          typed starts one of these (see sidebar_search_controller.js)
module SearchCommands
  ALL = [
    {
      label: 'Who Am I',
      event: 'who-am-i:open',
      terms: 'who am i whoami my account hierarchy identity profile organization'
    }
  ].freeze
end
