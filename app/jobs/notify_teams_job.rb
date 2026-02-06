class NotifyTeamsJob < ApplicationJob
  queue_as :default

  def perform(cir_id)
    cir = CriticalInformationReporting.find(cir_id)
    TeamsNotifier.send_cir_alert(cir)
  end
end
