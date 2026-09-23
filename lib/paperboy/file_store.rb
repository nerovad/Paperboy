# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'smb_shortcut'

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

      def directory?
        root.directory?
      end

      def readable?
        root.directory? && root.readable?
      end

      def list
        root.children
      end

      def exist?(name)
        child(name).file?
      end

      def copy(source, name)
        target = child(name)
        target.dirname.mkpath
        FileUtils.cp(Pathname.new(source), target, preserve: true)
      end

      # A removal is an action that reports whether a file was removed.
      # rubocop:disable-next Naming/PredicateMethod
      def remove(name)
        path = child(name)
        return false unless path.file?

        FileUtils.rm_f(path)
        true
      end

      private

      attr_reader :root

      def child(name)
        relative = Pathname.new(name.to_s)
        raise ArgumentError, 'file name must be relative' if relative.absolute? || relative.each_filename.include?('..')

        root.join(relative)
      end
    end

    class Smb
      UNC_TARGET = /\A\\\\([^\\]+)\\([^\\]+)(?:\\(.*))?\z/

      def initialize(shortcut_path, env: ENV, shortcut_class: SmbShortcut::WindowsShortcut,
                     share_class: SmbShortcut::SmbShare)
        @shortcut_path = Pathname.new(shortcut_path).expand_path
        @env = env
        @shortcut_class = shortcut_class
        @share_class = share_class
      end

      def directory?
        shortcut_path.file?
      end

      def readable?
        shortcut_path.file? && shortcut_path.readable?
      end

      def list
        share.files
      end

      def exist?(name)
        share.exist?(remote_name(name))
      end

      def copy(source, name)
        share.put(Pathname.new(source).to_s, remote_name(name))
      end

      # rubocop:disable-next Naming/PredicateMethod
      def remove(name)
        return false unless exist?(name)

        share.delete(remote_name(name))
        true
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

        folder = shortcut.target[UNC_TARGET, 3].to_s
        parts = [folder, relative.to_s].reject(&:empty?)
        parts.join('\\').tr('/', '\\')
      end

      def instantiate(factory, *args, **options)
        factory.respond_to?(:call) ? factory.call(*args, **options) : factory.new(*args, **options)
      end
    end
  end
end
