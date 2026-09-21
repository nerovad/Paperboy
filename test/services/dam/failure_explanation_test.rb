# frozen_string_literal: true

require 'test_helper'

module Dam
  # The sentence on the Storage screen has to name the thing an administrator
  # can go and fix. "Errno::ENOENT: No such file or directory - convert" does
  # not; "ImageMagick is not installed on this server" does.
  class FailureExplanationTest < ActiveSupport::TestCase
    test 'a missing tool is named as a missing tool' do
      assert_match(/ImageMagick is not installed/,
                   explain('Errno::ENOENT: No such file or directory - convert'))
      assert_match(/ffmpeg is not installed/,
                   explain('Errno::ENOENT: No such file or directory - ffmpeg'))
      assert_match(/poppler-utils is not installed/,
                   explain('Errno::ENOENT: No such file or directory - pdftoppm'))
    end

    test 'an ImageMagick built without a format is told apart from a missing one' do
      assert_match(/built without support/,
                   explain("convert: no decode delegate for this image format `x.png'"))
      assert_match(/policy refuses/,
                   explain('convert: attempt to perform an operation not authorized by security policy'))
    end

    test 'the share being away reads as worth trying again' do
      assert_match(/unreachable.*trying again/,
                   explain('Errno::EHOSTDOWN: Host is down @ dir_initialize'))
    end

    test 'a file the library can no longer find is not confused with a missing tool' do
      assert_match(/no longer where the library expects/,
                   explain('Errno::ENOENT: No such file or directory @ rb_sysopen - /mnt/i/gone.jpg'))
    end

    test 'the reasons a location refuses a file read as the location refusing it' do
      assert_match(/does not take that format/,
                   explain('File JPEG is not one of the formats Photo archive takes (PDF)'))
      assert_match(/closed to new files/,
                   explain('Storage location Cold archive is read-only and cannot take new uploads'))
    end

    test 'anything unrecognised says so rather than guessing' do
      assert_equal Dam::FailureExplanation::FALLBACK, explain('Something nobody has seen before')
    end

    test 'nothing recorded explains nothing' do
      assert_nil explain(nil)
      assert_nil explain('')
    end

    private

    def explain(text) = Dam::FailureExplanation.for(text)
  end
end
