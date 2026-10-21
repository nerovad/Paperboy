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
  end
end
