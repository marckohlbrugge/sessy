# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: SaaS gem audit", "bin/bundler-audit check --gemfile-lock Gemfile.saas.lock"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error --add-engines-path saas"

  step "Gemfile: Drift check", "bin/bundle-drift --check"

  step "Tests: Rails", "bin/rails test"
  # bin/ci runs before Bundler.require, so Sessy.saas? can't see the engine
  # here; the env var is the sanctioned pre-boot mode signal.
  step "Tests: SaaS engine", "bin/rails test saas/test" if ENV["SESSY_MODE"] == "saas"
  step "Tests: System", "bin/rails test:system"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
