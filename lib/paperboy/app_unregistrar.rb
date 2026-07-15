# frozen_string_literal: true

module Paperboy
  # Reverses AppRegistrar: strips an app's namespace, switcher entry, sidebar
  # branch, ACL item and sidebar theme back out of the shared files.
  #
  # Removal keys off the app key rather than the exact string the generator
  # wrote, so it still works once the entry has been edited by hand — a
  # renamed label, or extra routes added inside the namespace.
  class AppUnregistrar
    class Error < StandardError; end

    def initialize(app, root:)
      @app = app
      @root = root
    end

    # => { relative_path => new_content }, skipping files that need no change.
    def unpatches
      {
        'config/routes.rb' => routes,
        'app/helpers/application_helper.rb' => application_helper,
        'app/views/shared/_sidebar.html.erb' => sidebar_dispatcher,
        'app/controllers/acl_controller.rb' => acl_controller,
        'app/assets/stylesheets/layout/_sidebar.scss' => sidebar_theme
      }.reject { |path, content| content == read(path) }
    end

    private

    attr_reader :app, :root

    # Takes the whole namespace block, including any routes added inside it.
    # Nested blocks are indented deeper, so ^  end matches only its own end.
    def routes
      read('config/routes.rb').sub(/^  namespace :#{app.key} do\n(?:.*?\n)*?^  end\n\n?/, '')
    end

    def application_helper
      content = read('app/helpers/application_helper.rb')
                .sub(/^.*can_access_app\?\('#{app.key}'\).*\n/, '')
      content.sub(%r{^    elsif controller_path\.start_with\?\('#{app.key}/'\)\n      '#{app.key}'\n}, '')
    end

    def sidebar_dispatcher
      read('app/views/shared/_sidebar.html.erb')
        .sub(%r{^<% elsif controller_path\.start_with\?\("#{app.key}/"\) %>\n  <%= render "#{app.key}/shared/sidebar" %>\n}, '')
    end

    def sidebar_theme
      read('app/assets/stylesheets/layout/_sidebar.scss')
        .sub(/^  &\.#{app.dash_key}-sidebar \{\n(?:.*?\n)*?^  \}\n\n?/, '')
    end

    # Rebuilt rather than line-deleted, so the trailing comma lands on the
    # right entry whichever one is removed.
    def acl_controller
      content = read('app/controllers/acl_controller.rb')
      re = /(APPLICATION_ITEMS = \[\n)(.*?)(^  \]\.freeze$)/m
      return content unless content.match?(re)

      content.sub(re) do
        head = ::Regexp.last_match(1)
        tail = ::Regexp.last_match(3)
        items = ::Regexp.last_match(2).lines.map { |line| line.strip.chomp(',') }.reject(&:empty?)
        items.reject! { |line| line.include?("key: '#{app.key}'") }
        body = items.map { |item| "    #{item}" }.join(",\n")
        body += "\n" unless body.empty?
        "#{head}#{body}#{tail}"
      end
    end

    def read(path)
      full = root.join(path)
      raise Error, "#{path} does not exist." unless full.exist?

      full.read
    end
  end
end
