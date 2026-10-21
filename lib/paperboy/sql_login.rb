# frozen_string_literal: true

module Paperboy
  # Whether TinyTDS may receive a username and password.
  #
  # Principle: Boundary Discipline - DOMAIN\user is NTLM, and WSL, Ubuntu,
  # and Arch are not on the domain, so those hosts use the Kerberos ticket.
  module SqlLogin
    module_function

    # A blank username means Kerberos. DOMAIN\user on Linux also means
    # Kerberos: FreeTDS would send it as NTLM, and SQL Server rejects that
    # as an untrusted domain. Windows keeps DOMAIN\user for SSPI. A username
    # with no backslash is a SQL login, which CI uses.
    def sql_credentials?(username)
      name = username.to_s.strip
      return false if name.empty?
      return false if linux_domain_login?(name)

      true
    end

    def linux_domain_login?(username)
      !Gem.win_platform? && username.to_s.include?('\\')
    end

    def credentials(username, password)
      return {} unless sql_credentials?(username)

      { username: username.to_s, password: password }
    end

    # A DOMAIN\user already in the process hides the SQL login in .env.
    # Dotenv will not replace a variable that is set, and on Linux that
    # name means Kerberos. The ticket can open the server and still be
    # refused by Paperboy_Test, which the SQL login owns.
    #
    # Principle: Boundary Discipline - tests use the file's SQL login;
    # the shell's domain name stays the development login.
    def prefer_dotenv_sql_login!(root = Dir.pwd)
      return unless linux_domain_login?(ENV.fetch('GSABSS_USERNAME', nil))

      require 'dotenv'
      # overwrite reverses the list, and the last parsed file wins. Listing
      # .env.local first makes it win, matching dotenv-rails.
      files = %w[.env.local .env].map { |name| File.join(root, name) }
      parsed = Dotenv.parse(*files, overwrite: true)
      username = parsed['GSABSS_USERNAME']
      return unless sql_credentials?(username)

      ENV['GSABSS_USERNAME'] = username.to_s
      ENV['GSABSS_PASSWORD'] = parsed['GSABSS_PASSWORD'] if parsed.key?('GSABSS_PASSWORD')
    end
  end
end
