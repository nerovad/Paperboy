# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'smb_shortcut'
require 'tempfile'

module Paperboy
  # Provides a small filesystem-like interface for local directories and
  # Windows shortcuts that point to SMB folders.
  module FileStore
    class Error < StandardError; end

    class << self
      def for(location, **options)
        path = Pathname.new(location.to_s)
        return Smb.new(path, **options) if path.extname.casecmp?('.lnk')

        Local.new(path)
      end
    end

    class Local
      def initialize(root)
        @root = Pathname.new(root).expand_path
      end

      def directory?(name = nil)
        name ? child(name).directory? : root.directory?
      end

      def path
        root
      end

      def readable?
        root.directory? && root.readable?
      end

      def list
        root.children
      end

      def entries(prefix = nil)
        base = prefix ? child(prefix) : root
        base.children.map do |path|
          { name: path.basename.to_s, directory: path.directory? }
        end
      end

      def directories(prefix = nil)
        entries(prefix).select { |entry| entry.fetch(:directory) }.map { |entry| entry.fetch(:name) }
      end

      def files(prefix = nil)
        entries(prefix).reject { |entry| entry.fetch(:directory) }.map { |entry| entry.fetch(:name) }
      end

      def walk(prefix = nil)
        entries(prefix).flat_map do |entry|
          name = [prefix, entry.fetch(:name)].compact.join('/')
          entry.fetch(:directory) ? walk(name) : [entry.merge(name: name)]
        end
      end

      def exist?(name)
        child(name).file?
      end

      def copy(source, name)
        target = child(name)
        target.dirname.mkpath
        FileUtils.cp(Pathname.new(source), target, preserve: true)
      end

      def mkdir(name = nil)
        name ? child(name).mkpath : root.mkpath
      end

      # A removal is an action that reports whether a file was removed.
      # rubocop:disable-next Naming/PredicateMethod
      def remove(name)
        path = child(name)
        return false unless path.file?

        FileUtils.rm_f(path)
        true
      end

      def clear(prefix = nil)
        base = prefix ? child(prefix) : root
        base.children.each do |path|
          path.directory? ? FileUtils.rm_rf(path) : FileUtils.rm_f(path)
        end
      end

      def rmdir(name)
        path = child(name)
        path.rmdir if path.directory? && path.children.empty?
      end

      def download(name)
        child(name)
      end

      def with_download(name)
        yield download(name)
      end

      def cleanup_download(_path); end

      def mtime(name)
        child(name).mtime
      end

      private

      attr_reader :root

      def child(name)
        relative = Pathname.new(name.to_s)
        raise ArgumentError, 'file name must be relative' if relative.absolute? || relative.each_filename.include?('..')

        root.join(relative)
      end
    end

    # rubocop:disable-next Metrics/ClassLength
    class Smb
      UNC_TARGET = /\A\\\\([^\\]+)\\([^\\]+)(?:\\(.*))?\z/

      def initialize(shortcut_path, env: ENV, shortcut_class: SmbShortcut::WindowsShortcut,
                     share_class: SmbShortcut::SmbShare)
        @shortcut_path = Pathname.new(shortcut_path).expand_path
        @env = env
        @shortcut_class = shortcut_class
        @share_class = share_class
      end

      def directory?(name = nil)
        return shortcut_path.file? if name.nil?

        exist_directory?(remote_name(name))
      end

      def path
        shortcut_path
      end

      def readable?
        shortcut_path.file? && shortcut_path.readable?
      end

      def list
        remote_prefix.empty? ? share.files : share.list(remote_prefix)
      end

      def entries(prefix = nil)
        path = prefix ? remote_name(prefix) : remote_prefix
        share.entries(path.empty? ? nil : path)
      end

      def directories(prefix = nil)
        entries(prefix).select { |entry| entry.fetch(:directory) }.map { |entry| entry.fetch(:name) }
      end

      def files(prefix = nil)
        entries(prefix).reject { |entry| entry.fetch(:directory) }.map { |entry| entry.fetch(:name) }
      end

      def walk(prefix = nil)
        entries(prefix).flat_map do |entry|
          name = [prefix, entry.fetch(:name)].compact.join('/')
          entry.fetch(:directory) ? walk(name) : [entry.merge(name: name)]
        end
      end

      def exist?(name)
        share.exist?(remote_name(name))
      end

      def copy(source, name)
        mkdir(File.dirname(name)) unless File.dirname(name) == '.'
        share.put(Pathname.new(source).to_s, remote_name(name))
      end

      def mkdir(name = nil)
        return share.mkdir(remote_prefix) if name.nil? && !remote_prefix.empty?
        return true if name.nil?

        parts = name.to_s.tr('/', '\\').split('\\').reject(&:empty?)
        parts.each_index do |index|
          path = parts.first(index + 1).join('\\')
          share.mkdir(remote_name(path)) unless exist_directory?(remote_name(path))
        end
        true
      end

      # rubocop:disable-next Naming/PredicateMethod
      def remove(name)
        return false unless exist?(name)

        share.delete(remote_name(name))
        true
      end

      def clear(prefix = nil)
        entries(prefix).each do |entry|
          name = [prefix, entry.fetch(:name)].compact.join('/')
          entry.fetch(:directory) ? clear(name) : remove(name)
        end
        share.rmdir(remote_name(prefix)) if prefix
      end

      def rmdir(name)
        share.rmdir(remote_name(name))
      end

      def download(name)
        temporary = Tempfile.new(['paperboy-smb-file', File.extname(name.to_s)])
        temporary.close
        share.get(remote_name(name), temporary.path)
        Pathname.new(temporary.path)
      rescue StandardError
        FileUtils.rm_f(temporary.path) if temporary
        raise
      end

      def with_download(name)
        path = download(name)
        yield path
      ensure
        cleanup_download(path)
      end

      def cleanup_download(path)
        FileUtils.rm_f(path) if path
      end

      def mtime(name)
        relative = Pathname.new(name.to_s)
        parent = relative.parent.to_s
        basename = relative.basename.to_s
        entries(parent == '.' ? nil : parent).find { |entry| entry.fetch(:name) == basename }&.[](:modified_at)
      end

      private

      attr_reader :shortcut_path, :env, :shortcut_class, :share_class

      def shortcut
        @shortcut ||= instantiate(shortcut_class, shortcut_path.to_s)
      end

      def share
        @share ||= instantiate(
          share_class,
          host: shortcut.host,
          share: shortcut.share,
          ip: env['SMB_IP'].to_s.strip.then { |value| value unless value.empty? },
          username: env.fetch('SMB_USERNAME'),
          password: env.fetch('SMB_PASSWORD')
        )
      end

      def remote_name(name)
        relative = Pathname.new(name.to_s)
        raise ArgumentError, 'file name must be relative' if relative.absolute? || relative.each_filename.include?('..')

        parts = [remote_prefix, relative.to_s].reject(&:empty?)
        parts.join('\\').tr('/', '\\')
      end

      def remote_prefix
        current_shortcut = shortcut
        folder = current_shortcut.folder if current_shortcut.respond_to?(:folder)
        return folder.to_s.tr('/', '\\') unless folder.nil?

        target = current_shortcut&.target.to_s
        prefix = target[UNC_TARGET, 3]
        return prefix.to_s.tr('/', '\\') if prefix

        raise Error, "Shortcut does not contain a usable UNC target: #{shortcut_path}"
      end

      def exist_directory?(name)
        share.list(name)
        true
      rescue SmbShortcut::CommandError
        false
      end

      def instantiate(factory, *args, **options)
        factory.respond_to?(:call) ? factory.call(*args, **options) : factory.new(*args, **options)
      end
    end
  end
end
