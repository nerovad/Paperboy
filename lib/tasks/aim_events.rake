# frozen_string_literal: true

# Who held each invoice after its older events (#190), read from the history
# by Aim::EventHolderBackfill and marked 'inferred'. Safe to run again: it
# fills only events still without a holder, and leaves the ones it cannot
# read as they were.
#
#   bin/rails aim:backfill_event_holders
namespace :aim do
  desc 'Fill in who held each invoice after its older events, from the history'
  task backfill_event_holders: :environment do
    result = Aim::EventHolderBackfill.new.call
    puts "aim.invoice_events: #{result.inferred} events given their holder (inferred), " \
         "#{result.unknown} left unknown, across #{result.invoices} invoices"
  end
end
