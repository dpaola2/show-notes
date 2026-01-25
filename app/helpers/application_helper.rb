module ApplicationHelper
  def format_duration(seconds)
    return "" unless seconds

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end

  def format_cost_cents(cents)
    return "" unless cents && cents > 0

    if cents >= 100
      "$#{(cents / 100.0).round(2)}"
    else
      "#{cents}¢"
    end
  end

  def cost_badge_class(cents)
    if cents >= 75  # $0.75+
      "bg-amber-100 text-amber-800"
    elsif cents >= 50  # $0.50+
      "bg-yellow-100 text-yellow-800"
    else
      "bg-gray-100 text-gray-600"
    end
  end

  def inbox_count
    return 0 unless current_user
    @_inbox_count ||= current_user.user_episodes.in_inbox.count
  end
end
