# frozen_string_literal: true

require_relative 'app_registrar'

module Paperboy
  # Scaffolds a new sub-application inside Paperboy: a routed namespace, a base
  # controller gated on the ACL "application" permission, a landing page, a
  # sidebar with one button, an entry in the app switcher and an ACL checkbox.
  # Mirrors how data_runner and coa are wired up.
  #
  # Every file is planned in memory first (see #plan), so a shared file whose
  # shape has drifted aborts the run before anything is written.
  class AppBuilder
    class Error < StandardError; end

    TEMPLATES = File.expand_path('../tasks/templates/paperboy_app', __dir__)

    # Names that would collide with an existing app, a Rails path or a
    # top-level controller namespace.
    RESERVED = %w[admin api application assets coa data_runner layouts paperboy rails shared].freeze

    # Sidebar accent colours, keyed to the tokens in _tokens.scss.
    THEMES = {
      'teal' => ['$green-teal', '$green-teal-hover'],
      'blue' => ['$blue-action', '$blue-action-hover'],
      'cyan' => ['$cyan-action', '$cyan-action-hover'],
      'slate' => ['$slate-action', '$slate-action-hover'],
      'green' => ['$primary-color', '$green-action-hover']
    }.freeze

    attr_reader :key, :label, :module_name, :theme

    # +name+ accepts "hello_world", "hello-world", "Hello World" or
    # "HelloWorld" — all normalise to the key hello_world.
    def initialize(name, label: nil, theme: nil, root: Rails.root)
      @key = name.to_s.strip.underscore.parameterize(separator: '_')
      @label = label.presence || @key.titleize
      @theme = theme.presence || 'teal'
      @module_name = @key.camelize
      @root = Pathname(root)
      validate!
    end

    # Writes the whole app. Returns { relative_path => content } of everything
    # written; with dry_run: true it returns the same hash and writes nothing.
    def call(dry_run: false)
      files = plan
      return files if dry_run

      files.each do |path, content|
        full = @root.join(path)
        full.dirname.mkpath
        full.write(content)
      end
      files
    end

    # Everything the run would write: brand new files, plus the shared files
    # that get patched to register the app.
    def plan
      new_files.merge(AppRegistrar.new(self, root: @root).patches)
    end

    def new_files
      {
        "app/controllers/#{key}/base_controller.rb" => render('base_controller.rb.tt'),
        "app/controllers/#{key}/dashboard_controller.rb" => render('dashboard_controller.rb.tt'),
        "app/views/#{key}/dashboard/index.html.erb" => render('index.html.erb.tt'),
        "app/views/#{key}/shared/_sidebar.html.erb" => render('sidebar.html.erb.tt')
      }
    end

    # Templates use __TOKEN__ placeholders rather than ERB, so that templates
    # which are themselves ERB need no escaping.
    def render(template)
      accent, accent_hover = THEMES.fetch(theme)
      File.read(File.join(TEMPLATES, template))
          .gsub('__DASH_KEY__', key.dasherize)
          .gsub('__MODULE__', module_name)
          .gsub('__THEME_LABEL__', theme.capitalize)
          .gsub('__ACCENT_HOVER__', accent_hover)
          .gsub('__ACCENT__', accent)
          .gsub('__LABEL__', label)
          .gsub('__KEY__', key)
    end

    private

    def validate!
      raise Error, "'#{key}' is not a usable app name: use letters, numbers and underscores, e.g. hello_world." unless key.match?(/\A[a-z][a-z0-9_]*\z/)
      raise Error, "'#{key}' is reserved. Pick another name." if RESERVED.include?(key)
      raise Error, "Unknown theme '#{theme}'. Available: #{THEMES.keys.join(', ')}." unless THEMES.key?(theme)
      raise Error, "App '#{key}' already exists at app/controllers/#{key}/." if @root.join("app/controllers/#{key}").exist?
      return unless @root.join('app/helpers/application_helper.rb').read.include?("can_access_app?('#{key}')")

      raise Error, "App '#{key}' is already registered in the app switcher."
    end
  end
end
