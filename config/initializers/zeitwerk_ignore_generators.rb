# config/initializers/zeitwerk_ignore_generators.rb
if Rails.env.production?
  Rails.autoloaders.main.ignore(Rails.root.join("lib/generators"))
end
