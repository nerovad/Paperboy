INVOICE_COORDS = YAML.load_file(
  Rails.root.join("config/invoice_coordinates.yml")
).deep_symbolize_keys
