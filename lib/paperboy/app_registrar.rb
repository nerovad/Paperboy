# frozen_string_literal: true

module Paperboy
  # Registers a generated app in the handful of shared files that make an app
  # real: the routes, the app-switcher helper, the sidebar dispatcher, the ACL
  # Applications list and the sidebar theme.
  #
  # Every method returns the *new content* for a file; nothing is written here,
  # so a missing anchor is discovered before the run touches the working tree.
  # These anchors track the shape of files that data_runner and coa also live
  # in — if one of them is refactored, update the matching anchor below.
  class AppRegistrar
    class MissingAnchorError < StandardError; end

    def initialize(app, root:)
      @app = app
      @root = root
    end

    # => { relative_path => patched_content }
    def patches
      {
        'config/routes.rb' => routes,
        'app/helpers/application_helper.rb' => application_helper,
        'app/views/shared/_sidebar.html.erb' => sidebar_dispatcher,
        'app/controllers/acl_controller.rb' => acl_controller,
        'app/assets/stylesheets/layout/_sidebar.scss' => sidebar_theme
      }
    end

    private

    attr_reader :app, :root

    # A namespace at the top of the file, next to :data_runner.
    def routes
      block = "  namespace :#{app.key} do\n    root 'dashboard#index'\n  end\n\n"
      insert_before(read('config/routes.rb'), anchor: '^  namespace :data_runner do$',
                                              text: block, label: 'config/routes.rb')
    end

    # Two edits: the switcher entry (gated by the ACL grant) and the
    # controller_path => app key mapping that highlights the current app.
    def application_helper
      path = 'app/helpers/application_helper.rb'
      entry = "    apps << { key: '#{app.key}', label: '#{app.label}', " \
              "path: #{app.key}_root_path } if can_access_app?('#{app.key}')\n"
      branch = "    elsif controller_path.start_with?('#{app.key}/')\n      '#{app.key}'\n"

      content = insert_before(read(path), scope: 'def paperboy_apps', anchor: '^    apps$',
                                          text: entry, label: "#{path} (paperboy_apps)")
      insert_before(content, scope: 'def current_app_key', anchor: '^    else$',
                             text: branch, label: "#{path} (current_app_key)")
    end

    def sidebar_dispatcher
      path = 'app/views/shared/_sidebar.html.erb'
      text = %(<% elsif controller_path.start_with?("#{app.key}/") %>\n) +
             %(  <%= render "#{app.key}/shared/sidebar" %>\n)
      insert_before(read(path), anchor: '^<% else %>$', text: text, label: path)
    end

    # Appended to AclController::APPLICATION_ITEMS, which is what renders the
    # checkbox on both the group and org permission screens. Deliberately not
    # added to any default-public list: nobody sees the app until granted.
    def acl_controller
      path = 'app/controllers/acl_controller.rb'
      content = read(path)
      re = /(APPLICATION_ITEMS = \[\n)(.*?)(^  \]\.freeze$)/m
      raise MissingAnchorError, missing(path) unless content.match?(re)

      content.sub(re) do
        items = ::Regexp.last_match(2).rstrip
        "#{::Regexp.last_match(1)}#{items},\n    { key: '#{app.key}', label: '#{app.label}' }\n#{::Regexp.last_match(3)}"
      end
    end

    def sidebar_theme
      path = 'app/assets/stylesheets/layout/_sidebar.scss'
      insert_before(read(path), anchor: '^  &\.data-runner-sidebar \{$',
                                text: app.render('sidebar_theme.scss.tt'), label: path)
    end

    # Inserts +text+ before the first +anchor+ appearing after +scope+, so an
    # anchor as generic as "else" can still be pinned to one method.
    def insert_before(content, anchor:, text:, label:, scope: '\A')
      re = Regexp.new("(#{scope}.*?)(#{anchor})", Regexp::MULTILINE)
      raise MissingAnchorError, missing(label) unless content.match?(re)

      content.sub(re) { "#{::Regexp.last_match(1)}#{text}#{::Regexp.last_match(2)}" }
    end

    def read(path)
      full = root.join(path)
      raise MissingAnchorError, "#{path} does not exist." unless full.exist?

      full.read
    end

    def missing(label)
      "Could not find the expected anchor in #{label}. That file has changed " \
        "shape, so '#{app.key}' was not registered and nothing was written. " \
        'Update the anchor in lib/paperboy/app_registrar.rb (or register the app by hand).'
    end
  end
end
