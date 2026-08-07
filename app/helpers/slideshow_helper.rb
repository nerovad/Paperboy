# frozen_string_literal: true

# Supplies the image sets rendered by sub-application landing pages.
module SlideshowHelper
  # Paperboy's own landing images. Also the default a generated app lands with
  # (see lib/tasks/templates/paperboy_app/home.html.erb.tt), so a brand new app
  # has a slideshow on day one, before anyone has drawn it any pictures.
  def paperboy_home_images
    [
      { src: 'VenturaPier.png',     alt: 'Ventura Pier' },
      { src: 'VenturaCross.png',    alt: 'Ventura Cross' },
      { src: 'VenturaCityHall.png', alt: 'Ventura City Hall' },
      { src: 'Sunny_Beach.png',     alt: 'Sunny beach promenade stroll' },
      { src: 'Sunny_Coastal.png',   alt: 'Sunny coastal retreat with mountains' }
    ]
  end

  def data_runner_home_images
    slideshow_images('data_runner', 'Data source ingestion',
                     'Data validation and transformation', 'Data delivery and synchronization')
  end

  def billing_home_images
    slideshow_images('billing', 'Fiscal period planning',
                     'Monthly billing reconciliation', 'Completed billing reports')
  end

  def coa_home_images
    slideshow_images('coa', 'Organized accounting ledger',
                     'Hierarchical account structure', 'Balanced account reconciliation')
  end

  def aim_home_images
    slideshow_images('aim', 'Invoice reconciliation',
                     'Invoice review and approval', 'Approved invoice routing')
  end

  def print_production_home_images
    slideshow_images('print_production', 'Complex document printing',
                     'Document folding and envelope insertion', 'Finished mail distribution')
  end

  def digital_asset_management_home_images
    slideshow_images('digital_asset_management', 'Digital asset ingestion',
                     'Digital asset cataloging', 'Digital asset delivery')
  end

  def admin_tools_home_images
    slideshow_images('admin_tools', 'User and account administration',
                     'Roles and access permissions', 'Application and system configuration')
  end

  private

  def slideshow_images(namespace, *descriptions)
    descriptions.each_with_index.map do |description, index|
      path = format('%s/slide_%02d.png', namespace, index + 1)
      { src: path, alt: description }
    end
  end
end
