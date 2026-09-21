# frozen_string_literal: true

# Lets Active Storage find the service behind a DAM storage location.
#
# Services normally come only from config/storage.yml, but a location's root is
# set on the Storage screen, per environment, at runtime. So a blob whose
# service is named dam_location_<id>_<digest> is resolved from its location
# row instead. The digest pins the name to one root, so the built service is
# cached for the life of the process like any configured one.
module DamStorageServiceRegistry
  def fetch(name)
    return super unless Dam::StorageLocation::SERVICE_NAME.match?(name.to_s)

    services.fetch(name.to_sym) do |key|
      service = Dam::StorageLocation.service_for(key)
      next services[key] = service if service
      next yield(key) if block_given?

      raise KeyError, "No DAM storage location answers to the #{key} Active Storage service"
    end
  end
end

ActiveStorage::Service::Registry.prepend(DamStorageServiceRegistry)
