# app/jobs/concerns/transcription_sorting.rb
module TranscriptionSorting
  extend ActiveSupport::Concern

  def sort_by_track_number(extracted_files)
    extracted_files.sort_by do |path|
      file_name = File.basename(path)
      # Your specific regex for track numbers at the end of the filename
      match = file_name.match(/(\d+)\.[^.]+$/)
      track_number = match ? match[1].to_i : 0
      track_number
    end
  end

  def is_audio_or_video?(path)
    %w[.mp3 .wav .m4a .mp4 .mov .avi .mkv].include?(File.extname(path).downcase)
  end
end

