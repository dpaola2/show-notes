# Controller-level helpers for server-side PostHog capture.
#
# Included in ApplicationController (platform: "web") and Api::BaseController
# (platform: "ios"), so the same event names land in one PostHog project,
# differentiated by the `platform` property. Logged-in requests use the user id
# as the distinct_id; anonymous web requests get a stable per-session id.
module AnalyticsTrackable
  extend ActiveSupport::Concern

  private

  def track_event(event, properties = {})
    Analytics.capture(
      distinct_id: analytics_distinct_id,
      event: event,
      properties: { platform: analytics_platform }.merge(properties)
    )
  end

  def identify_user(user, properties = {})
    return unless user

    Analytics.identify(
      distinct_id: user.id,
      properties: { platform: analytics_platform }.merge(properties)
    )
  end

  def analytics_distinct_id
    current_user&.id&.to_s || posthog_cookie_distinct_id || (session[:analytics_id] ||= SecureRandom.uuid)
  end

  # Align anonymous server-side events with posthog-js by reusing the
  # distinct_id it stores in its cookie. Once the visitor logs in, the JS
  # `identify(user.id)` call merges that anonymous id into the user — so the
  # pre-login server events follow along. Falls back to a session id when the
  # cookie isn't present (e.g. API requests, or JS not yet loaded).
  def posthog_cookie_distinct_id
    key = ENV["POSTHOG_API_KEY"]
    return nil if key.blank?

    raw = cookies["ph_#{key}_posthog"]
    return nil if raw.blank?

    JSON.parse(raw)["distinct_id"].presence
  rescue JSON::ParserError
    nil
  end

  # Overridden in Api::BaseController.
  def analytics_platform
    "web"
  end
end
