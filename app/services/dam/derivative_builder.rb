# frozen_string_literal: true

module Dam
  # Builds the two copies the library actually shows: a web-sized proxy and a
  # grid thumbnail. Everything else about an asset can be read from its row;
  # these are the only reason the DAM needs bytes of its own for a file it
  # merely references.
  #
  # Whatever wrote the share may already have made them — ResourceSpace writes
  # five sizes beside every original — so adoption is tried first and costs a
  # copy of a few hundred kilobytes instead of a pass through ffmpeg.
  #
  # Failure is recorded on the asset rather than raised: a library where one
  # corrupt TIFF stops the queue is worse than one with a missing thumbnail.
  class DerivativeBuilder
    PROXY_PIXELS = 1600
    THUMBNAIL_PIXELS = 400
    # Long enough for a large TIFF or a two-hour video, short enough that a
    # file ffmpeg cannot make sense of does not hold a worker all day.
    TIMEOUT = 10.minutes

    # Where in a video to look for a frame worth showing. Three seconds in,
    # because the first frame of a great many videos is black.
    THUMBNAIL_FRAME = '00:00:03'

    class CommandFailed < StandardError; end

    def initialize(asset)
      @asset = asset
    end

    def call
      return finish('none') unless buildable?
      return finish('ready') if AdoptedPreviews.new(@asset).call

      build
      finish(@asset.proxy.attached? || @asset.thumbnail.attached? ? 'ready' : 'none')
    rescue StandardError => e
      @asset.update_columns(derivative_state: 'failed',
                            derivative_error: "#{e.class}: #{e.message}".truncate(2000))
      'failed'
    ensure
      @scratch&.each { |path| FileUtils.rm_f(path) }
    end

    private

    def source_path
      @source_path ||= @asset.referenced? ? @asset.original_path : nil
    end

    # A stored asset's bytes are on a service, which may not be a local disk,
    # so it is written to a temp file and read back like any other source.
    def with_source
      return yield(source_path) if source_path

      @asset.file.open(tmpdir: tmp_root) { |file| yield(Pathname(file.path)) }
    end

    def buildable? = @asset.referenced? || @asset.file.attached?

    def pdf? = @asset.content_type == 'application/pdf' || @asset.format.to_s.casecmp('pdf').zero?

    def build
      case @asset.media_type
      when 'image' then with_source { |path| build_image(path) }
      when 'video' then with_source { |path| build_video(path) }
      # Only a PDF can be rendered to a page image; a .doc or .txt is a
      # document to the catalogue but not to pdftoppm.
      when 'document' then with_source { |path| build_document(path) } if pdf?
      end
    end

    def build_image(path)
      attach(:proxy, convert(path, PROXY_PIXELS, 'proxy.jpg'))
      attach(:thumbnail, convert(path, THUMBNAIL_PIXELS, 'thumb.jpg'))
    end

    # The proxy is the poster frame rather than a transcode: re-encoding a
    # library's worth of video is a decision of its own, not something an
    # ingest should start doing on its own initiative.
    def build_video(path)
      frame = in_tmp('frame.jpg')
      run('ffmpeg', '-nostdin', '-y', '-ss', THUMBNAIL_FRAME, '-i', path.to_s,
          '-frames:v', '1', '-q:v', '3', frame.to_s)
      frame = first_frame(path) unless frame.exist? && frame.size.positive?

      attach(:proxy, convert(frame, PROXY_PIXELS, 'proxy.jpg'))
      attach(:thumbnail, convert(frame, THUMBNAIL_PIXELS, 'thumb.jpg'))
    end

    # A video shorter than the frame we asked for gives nothing back, so the
    # very first frame is the fallback.
    def first_frame(path)
      frame = in_tmp('frame-first.jpg')
      run('ffmpeg', '-nostdin', '-y', '-i', path.to_s, '-frames:v', '1', '-q:v', '3', frame.to_s)
      frame
    end

    def build_document(path)
      page = in_tmp('page')
      run('pdftoppm', '-jpeg', '-r', '150', '-f', '1', '-l', '1', path.to_s, page.to_s)
      rendered = Pathname(Dir.glob("#{page}*.jpg").first.to_s)
      raise CommandFailed, 'pdftoppm produced no page' unless rendered.file?

      @scratch << rendered

      attach(:proxy, convert(rendered, PROXY_PIXELS, 'proxy.jpg'))
      attach(:thumbnail, convert(rendered, THUMBNAIL_PIXELS, 'thumb.jpg'))
    end

    # '>' only shrinks, so a small original is never blown up into a blurry
    # proxy larger than the file it came from. [0] takes the first frame of a
    # multi-page TIFF or an animated GIF.
    def convert(path, pixels, name)
      output = in_tmp(name)
      run('convert', "#{path}[0]", '-auto-orient', '-resize', "#{pixels}x#{pixels}>",
          '-quality', '82', '-strip', output.to_s)
      output
    end

    def attach(name, path)
      return unless path.exist? && path.size.positive?

      @asset.public_send(name).attach(io: File.open(path, 'rb'),
                                      filename: "#{@asset.id}-#{path.basename}",
                                      content_type: 'image/jpeg')
    end

    # Killed rather than waited on for ever: one file ffmpeg cannot make sense
    # of must not hold a worker all day. Returns nothing useful — a command
    # that did not work raises.
    def run(*command)
      output = nil
      status = nil
      Open3.popen2e(*command) do |stdin, out, thread|
        stdin.close
        raise CommandFailed, "#{command.first} timed out" unless thread.join(TIMEOUT)

        output = out.read
        status = thread.value
      end
      return if status&.success?

      raise CommandFailed, "#{command.first}: #{output.to_s.lines.last(3).join(' ').squish.truncate(300)}"
    end

    def in_tmp(name)
      path = tmp_root.join("#{@asset.id}-#{SecureRandom.hex(4)}-#{name}")
      (@scratch ||= []) << path
      path
    end

    def tmp_root
      @tmp_root ||= Rails.root.join('tmp/dam').tap { |path| FileUtils.mkdir_p(path) }
    end

    # Returns the state, so a caller can log what happened without asking the
    # asset again.
    def finish(state)
      @asset.update_columns(derivative_state: state, derivative_error: nil)
      state
    end
  end
end
