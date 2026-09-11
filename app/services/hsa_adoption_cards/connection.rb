# frozen_string_literal: true

module HsaAdoptionCards
  # A TinyTds client for the Scan Center's "GSA Scan" database on the GSABSS
  # server, opened for one procedure call and closed straight after.
  #
  # Server, port, credentials and timeout are the GSABSS_* settings every
  # other Paperboy connection already uses, so nothing new has to be
  # configured to reach this database. Only the database name is this
  # app's own, and it has a default:
  #
  #   HSA_ADOPT_SQL_DATABASE   defaults to "GSA Scan"
  #
  # Deliberately not an ActiveRecord connection. A +connects_to+ pool is
  # registered application-wide the moment its model loads, and the test
  # suite's transactional fixtures then open every pool for every test — so
  # a database missing from a CI server would fail the whole suite. This
  # app talks to one database through three procedures; a client per call
  # keeps that entirely its own affair.
  class Connection
    APP_NAME = 'Paperboy HSA Adoption Card Search'
    DEFAULT_DATABASE = 'GSA Scan'

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
      { host: gsabss('HOST') || raise(MissingConfiguration.for('GSABSS_HOST', 'The SQL Server')),
        port: (gsabss('PORT') || 1433).to_i,
        database: ENV.fetch('HSA_ADOPT_SQL_DATABASE', nil).to_s.strip.presence || DEFAULT_DATABASE,
        appname: APP_NAME, tds_version: '7.4',
        timeout: (gsabss('TIMEOUT') || 5).to_i }.merge(credential_options)
    end

    private

    def gsabss(suffix)
      ENV.fetch("GSABSS_#{suffix}", nil).to_s.strip.presence
    end

    # The same rule as config/database.yml: a username means SQL auth (CI,
    # workstations); none means Kerberos from the ticket in KRB5CCNAME.
    def credential_options
      username = gsabss('USERNAME')
      return {} if username.nil?

      { username: username, password: ENV.fetch('GSABSS_PASSWORD', nil) }
    end
  end
end
