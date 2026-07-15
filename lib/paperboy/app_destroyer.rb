# frozen_string_literal: true

require_relative 'app_unregistrar'

module Paperboy
  # Removes a sub-application created by AppBuilder: deletes its namespaced
  # directories, unregisters it from the shared files, and revokes its ACL
  # grants.
  #
  # The grants matter. Left behind they are invisible orphans — nothing renders
  # them once the ACL item is gone — that would silently re-grant access to
  # whoever held them if the key is ever reused.
  class AppDestroyer
    class Error < StandardError; end

    # Apps that predate the generator and carry a lot of hand-written code, or
    # that are not sub-applications at all. Tearing these down is a bigger
    # decision than a rake task should make on someone's behalf.
    PROTECTED = %w[admin api application assets coa data_runner layouts paperboy rails shared].freeze

    # Everything a grown-up app might own. Only paths namespaced by the key,
    # and only the ones that actually exist.
    DIRECTORIES = ['app/controllers/%s', 'app/views/%s', 'app/models/%s', 'app/helpers/%s',
                   'app/javascript/controllers/%s', 'test/controllers/%s'].freeze

    attr_reader :key

    def initialize(name, root: Rails.root)
      @key = name.to_s.strip.underscore.parameterize(separator: '_')
      @root = Pathname(root)
      validate!
    end

    def dash_key
      key.dasherize
    end

    # Snapshotted, so it still reads true after the files are gone.
    def plan
      @plan ||= {
        directories: directories,
        patches: AppUnregistrar.new(self, root: @root).unpatches,
        grant_counts: grants.transform_values(&:count)
      }
    end

    def call
      plan => { directories:, patches: }
      patches.each { |path, content| @root.join(path).write(content) }
      directories.each { |dir| @root.join(dir).rmtree }
      grants.each_value(&:delete_all)
      plan
    end

    def registered?
      @root.join('app/helpers/application_helper.rb').read.include?("can_access_app?('#{key}')")
    end

    private

    def directories
      DIRECTORIES.map { |dir| format(dir, key) }.select { |dir| @root.join(dir).directory? }
    end

    def grants
      {
        'Group_Permissions' => GroupPermission.where(permission_type: 'application', permission_key: key),
        'org_permissions' => OrgPermission.where(permission_type: 'application', permission_key: key)
      }
    end

    def validate!
      raise Error, "'#{key}' is not a usable app name." unless key.match?(/\A[a-z][a-z0-9_]*\z/)
      raise Error, "'#{key}' is protected and will not be removed automatically. Take it apart by hand if you mean it." if PROTECTED.include?(key)
      return if registered? || directories.any?

      raise Error, "No app '#{key}' found: nothing registered in the app switcher, and no app/controllers/#{key}/."
    end
  end
end
