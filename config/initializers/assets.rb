# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Dart Sass compiles app/assets/stylesheets into app/assets/builds; Sprockets
# only serves the result. Leave the SCSS source on Sprockets' load path and it
# treats application.scss as a second candidate for "application.css" and hands
# it to the sassc processor Sprockets 4 registers for text/scss
# (sprockets/lib/sprockets.rb:173). libsass is no longer in the bundle, so that
# path raises a confusing LoadError deep inside SasscProcessor instead of
# saying the stylesheet build is simply missing.
#
# These blocks run in registration order, so this one sees the fully populated
# path list that sprockets-rails appended. Only our own directory is dropped --
# gems such as jquery-datatables keep theirs.
Rails.application.config.assets.configure do |env|
  scss_source = Rails.root.join('app/assets/stylesheets').to_s
  kept = env.paths.reject { |path| path.to_s == scss_source }

  next if kept.length == env.paths.length

  env.clear_paths
  kept.each { |path| env.append_path(path) }
end
