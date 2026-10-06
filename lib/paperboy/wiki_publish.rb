# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'wiki_catalog'
require_relative 'wiki_rewriter'
require_relative 'wiki_renderer'
require_relative 'wiki_planner'

module Paperboy
  # Command line for staging a wiki tree and printing the publish plan.
  module WikiPublish
    class Cli
      def self.run(argv)
        command = argv.shift
        case command
        when 'stage' then stage(parse(argv))
        when 'plan' then plan(parse(argv))
        else
          warn 'Usage: wiki_publish.rb stage|plan --catalog PATH --root PATH --out PATH --repo-url URL'
          exit 2
        end
      end

      def self.stage(options)
        catalog = WikiCatalog.load(options[:catalog])
        WikiRenderer.new(catalog, repo_html_url: options[:repo_url]).write(options[:root], options[:out])
      end

      def self.plan(options)
        catalog = WikiCatalog.load(options[:catalog])
        staged = WikiPlanner.read_tree(options[:out])
        existing = WikiPlanner.read_tree(options[:wiki])
        result = WikiPlanner.new(catalog).classify(staged, existing)
        File.write(File.join(options[:out], 'plan.json'), JSON.generate(result))
        puts WikiPlanner.new(catalog).report(result)
      end

      def self.parse(argv)
        options = {}
        OptionParser.new do |parser|
          parser.on('--catalog PATH') { |value| options[:catalog] = value }
          parser.on('--root PATH') { |value| options[:root] = value }
          parser.on('--out PATH') { |value| options[:out] = value }
          parser.on('--repo-url URL') { |value| options[:repo_url] = value }
          parser.on('--wiki PATH') { |value| options[:wiki] = value }
        end.parse!(argv)
        options
      end
    end
  end
end

Paperboy::WikiPublish::Cli.run(ARGV) if $PROGRAM_NAME == __FILE__
