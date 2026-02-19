class GenerateOgImageJob < ApplicationJob
  queue_as :default

  def perform(episode_id)
    episode = Episode.find(episode_id)

    return unless episode.summary.present?

    image_data = OgImageGenerator.generate(episode)

    episode.og_image.attach(
      io: StringIO.new(image_data),
      filename: "og_#{episode.id}.png",
      content_type: "image/png"
    )
  rescue StandardError => e
    Rails.logger.error("OG image generation failed for episode #{episode_id}: #{e.message}")
  end
end
