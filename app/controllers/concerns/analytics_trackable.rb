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
    current_user&.id&.to_s || (session[:analytics_id] ||= SecureRandom.uuid)
  end

  # Overridden in Api::BaseController.
  def analytics_platform
    "web"
  end
end
