# AI Instructions

- Generated Ruby conforms to `.rubocop.yml`.
- CI Pipeline requirements:
  * bundle exec rubocop
  * bundle exec brakeman
  * bundle exec bundle-audit check
  * bundle exec rake test
- Propose git commit message.
  * Prose limited to 72 characters
  * Blank Line
  * Description lines limited to 80 characters
