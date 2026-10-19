# frozen_string_literal: true

Rails.autoloaders.main.ignore(Rails.root.join('lib/generators')) if Rails.env.production?
