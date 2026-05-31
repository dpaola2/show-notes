# Thin wrapper around the PostHog server-side client.
#
# Every method is a safe no-op when PostHog is not configured (POSTHOG_CLIENT
# is nil) and swallows capture errors so analytics can never break a request.
# Controllers should prefer the AnalyticsTrackable concern's #track_event /
# #identify_user helpers, which add platform + distinct_id automatically.
module Analytics
  module_function

  def capture(distinct_id:, event:, properties: {})
    return unless POSTHOG_CLIENT

    POSTHOG_CLIENT.capture(
      distinct_id: distinct_id.to_s,
      event: event,
      properties: properties.compact
    )
  rescue => e
    Rails.logger.warn("[PostHog] capture failed (#{event}): #{e.message}")
  end

  def identify(distinct_id:, properties: {})
    return unless POSTHOG_CLIENT

    POSTHOG_CLIENT.identify(
      distinct_id: distinct_id.to_s,
      properties: properties.compact
    )
  rescue => e
    Rails.logger.warn("[PostHog] identify failed: #{e.message}")
  end
end
