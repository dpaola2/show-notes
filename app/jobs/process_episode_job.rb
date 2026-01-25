class ProcessEpisodeJob < ApplicationJob
  queue_as :default

  def perform(user_episode_id)
    user_episode = UserEpisode.find(user_episode_id)
    episode = user_episode.episode

    # Check if another user already processed this episode
    if episode.transcript.present? && episode.summary.present?
      user_episode.update!(processing_status: :ready)
      return
    end

    # Step 1: Download audio to temp file
    user_episode.update!(processing_status: :downloading)
    audio_file = download_audio(episode.audio_url)

    # Step 2: Transcribe with Whisper (if not already done)
    unless episode.transcript.present?
      user_episode.update!(processing_status: :transcribing)
      transcript = WhisperClient.transcribe(audio_file)
      episode.create_transcript!(content: transcript.to_json)
    end

    # Step 3: Summarize with Claude (if not already done)
    unless episode.summary.present?
      user_episode.update!(processing_status: :summarizing)
      summary = ClaudeClient.summarize(episode.transcript.content)
      episode.create_summary!(
        sections: summary["sections"],
        quotes: summary["quotes"]
      )
    end

    user_episode.update!(processing_status: :ready)

  rescue => e
    user_episode.update!(
      processing_status: :error,
      processing_error: e.message
    )
  ensure
    audio_file&.close
    audio_file&.unlink if audio_file.respond_to?(:unlink)
  end

  private

  MAX_FILE_SIZE = 24.megabytes # Whisper API limit is 25MB

  def download_audio(url)
    require "open-uri"
    require "tempfile"

    temp_file = Tempfile.new([ "audio", ".mp3" ])
    temp_file.binmode

    URI.parse(url).open do |remote_file|
      temp_file.write(remote_file.read)
    end

    temp_file.rewind

    # Compress if file is too large for Whisper API
    if temp_file.size > MAX_FILE_SIZE
      temp_file = compress_audio(temp_file)
    end

    temp_file
  end

  def compress_audio(input_file)
    require "tempfile"

    output_file = Tempfile.new([ "audio_compressed", ".mp3" ])

    # Use ffmpeg to compress: mono, 16kHz sample rate, 64k bitrate
    # This is sufficient quality for speech transcription
    system(
      "ffmpeg", "-y", "-i", input_file.path,
      "-ac", "1",           # mono
      "-ar", "16000",       # 16kHz sample rate
      "-b:a", "64k",        # 64kbps bitrate
      output_file.path,
      out: File::NULL,
      err: File::NULL
    )

    input_file.close
    input_file.unlink

    unless File.exist?(output_file.path) && File.size(output_file.path) > 0
      raise "Audio compression failed. Is ffmpeg installed?"
    end

    output_file.rewind
    output_file
  end
end
