json.id user_episode.id
json.processing_status user_episode.processing_status
json.location user_episode.location
json.processing_error user_episode.processing_error
json.created_at user_episode.created_at.iso8601

json.episode do
  json.id user_episode.episode.id
  json.title user_episode.episode.title
  json.published_at user_episode.episode.published_at&.iso8601
  json.duration_seconds user_episode.episode.duration_seconds

  json.podcast do
    json.id user_episode.episode.podcast.id
    json.title user_episode.episode.podcast.title
    json.author user_episode.episode.podcast.author
    json.artwork_url user_episode.episode.podcast.artwork_url
  end

  if local_assigns[:include_summary]
    summary = user_episode.episode.summary
    if summary
      json.summary do
        json.sections summary.sections.map { |s| { title: s["title"], content: s["content"] } }
        json.quotes summary.quotes.map { |q| { text: q["text"] } }
      end
    else
      json.summary nil
    end
  else
    json.summary nil
  end
end
