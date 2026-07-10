# config/initializers/zeitwerk_ignore_generators.rb
Rails.autoloaders.main.ignore(Rails.root.join('lib/generators')) if Rails.env.production?
