require "posthog"

# PostHog product analytics client (server-side capture).
#
# Configured via ENV so the public project key is not committed:
#   POSTHOG_API_KEY  - project API key (phc_...), write-only, safe in app config
#   POSTHOG_HOST     - ingestion host (defaults to US Cloud)
#
# When POSTHOG_API_KEY is absent (local dev / test / CI) the client is nil and
# Analytics.* calls become no-ops, so analytics never blocks a request.
POSTHOG_CLIENT =
  if ENV["POSTHOG_API_KEY"].present?
    PostHog::Client.new(
      api_key: ENV["POSTHOG_API_KEY"],
      host: ENV.fetch("POSTHOG_HOST", "https://us.i.posthog.com"),
      on_error: proc { |_status, message| Rails.logger.warn("[PostHog] #{message}") }
    )
  end
