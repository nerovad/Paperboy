Rails.application.config.teams_webhook_url = if Rails.env.production?
  "https://prod-62.usgovtexas.logic.azure.us:443/workflows/8c15db716dc74ed293b3d5d22b2f6d86/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=VucP5RqgqaQW5EhzXMr81WX_mECr56HZnZ_z0-dHEDw"
else
  "https://prod-35.usgovtexas.logic.azure.us:443/workflows/45e93a299c0142f5ba3f7f0e5f3e5b33/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=AxOFWWHEeHrA_umcBN3IMdn8c1XkZT0nzdvvD6qxlPo"
end
