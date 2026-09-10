# frozen_string_literal: true

module HsaAdoptionCards
  # A TinyTds client for the GSA_Scan database, opened for one procedure call
  # and closed straight after.
  #
  # Deliberately not an ActiveRecord connection. A +connects_to+ pool is
  # registered application-wide the moment its model loads, and the test
  # suite's transactional fixtures then open every pool for every test — so
  # an unreachable GSA_Scan would fail the whole suite, and a slow one would
  # slow every page. This app talks to one server through two procedures; a
  # client per call keeps that entirely its own affair.
  #
  # Settings, all HSA_ADOPT_SQL_*:
  #   HOST + PORT      the instance, e.g. gsa-sql22.ent.co.ventura.ca.us / 1433
  #   DATASERVER       alternatively "server\instance", resolved by the SQL
  #                    Browser service; takes precedence over HOST + PORT
  #   DATABASE         defaults to GSA_Scan
  #   USERNAME/PASSWORD SQL auth with a login on this instance; left unset,
  #                    Kerberos from the ticket in KRB5CCNAME, the same way
  #                    config/database.yml reaches GSABSS on the servers. The
  #                    GSABSS credentials are never tried: they belong to a
  #                    different server and this instance does not know them.
  #   TIMEOUT          seconds, defaults to GSABSS_TIMEOUT then 5
  class Connection
    APP_NAME = 'Paperboy HSA Adoption Card Search'

    # ADO.NET switches these on for every session; FreeTDS does not. The
    # search procedure builds its MatchedOn column with FOR XML and reads
    # indexed views, both of which SQL Server refuses without them.
    SESSION_OPTIONS = <<~SQL.squish
      SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON;
      SET CONCAT_NULL_YIELDS_NULL ON; SET QUOTED_IDENTIFIER ON; SET NUMERIC_ROUNDABORT OFF;
    SQL

    def self.open
      client = new.client
      client.execute(SESSION_OPTIONS).do
      yield client
    ensure
      client&.close
    end

    def client
      require 'tiny_tds'
      TinyTds::Client.new(**options)
    end

    def options
      opts = { database: env('DATABASE', 'GSA_Scan'), appname: APP_NAME, tds_version: env('TDSVER', '7.4'),
               timeout: env('TIMEOUT', ENV.fetch('GSABSS_TIMEOUT', 5)).to_i }
      opts.merge!(server_options).merge!(credential_options)
    end

    private

    def env(suffix, default = nil)
      ENV.fetch("HSA_ADOPT_SQL_#{suffix}", default).to_s.strip.presence || default
    end

    def server_options
      dataserver = env('DATASERVER')
      return { dataserver: dataserver } if dataserver

      host = env('HOST') || raise(MissingConfiguration.for('HSA_ADOPT_SQL_HOST', 'The adoption cards SQL Server'))
      { host: host, port: env('PORT', 1433).to_i }
    end

    def credential_options
      username = env('USERNAME')
      return {} if username.nil?

      { username: username, password: ENV.fetch('HSA_ADOPT_SQL_PASSWORD', nil) }
    end
  end
end
