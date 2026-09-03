# frozen_string_literal: true

require 'fileutils'
require 'digest'
require 'pathname'
require 'tempfile'

module P2m
  class OmsStaging
    DESTINATION = Pathname.new('/mnt/o/Outputs/DataRunner/00_SentToUSPS')

    def initialize(root: OmsAssociatedFiles::ROOT, destination: DESTINATION)
      @root = Pathname.new(root).expand_path
      @destination = Pathname.new(destination).expand_path
      @associated_files = OmsAssociatedFiles.new(root: @root)
    end

    def stage(directory:, oms_number:, checksums: nil)
      files = associated_files.call(directory: directory, oms_number: oms_number)
      destination.mkpath
      files.each do |name|
        checksum = copy(root.join(directory, name), destination.join(name))
        checksums[name] = checksum if checksums
      end
      files.length
    end

    def remove(directory:, oms_number:)
      files = associated_files.call(directory: directory, oms_number: oms_number)
      files.count do |name|
        path = destination.join(name)
        next false unless path.file?

        FileUtils.rm_f(path)
        true
      end
    end

    private

    attr_reader :root, :destination, :associated_files

    def copy(source, target)
      return Digest::SHA256.file(target).hexdigest if matching_file?(source, target)
      raise "staged file already exists with different contents: #{target.basename}" if target.exist?

      copy_with_checksum(source, target)
    end

    def matching_file?(source, target)
      target.file? && source.size == target.size && source.mtime == target.mtime
    end

    def copy_with_checksum(source, target)
      source_stat = source.stat
      digest = Digest::SHA256.new
      temporary = Tempfile.new([".#{target.basename}", '.part'], destination.to_s, binmode: true)
      moved = false

      begin
        File.open(source, 'rb') do |input|
          while (chunk = input.read(1024 * 1024))
            digest.update(chunk)
            temporary.write(chunk)
          end
        end
        temporary.close
        File.chmod(source_stat.mode, temporary.path)
        File.utime(source_stat.atime, source_stat.mtime, temporary.path)
        File.rename(temporary.path, target)
        moved = true
        digest.hexdigest
      ensure
        temporary.close unless temporary.closed?
        temporary.unlink unless moved
      end
    end
  end
end
