# Fire-and-forget conform of an uploaded master (replaces Express'
# `void conformMedia(...)`). Conform.conform_media never raises: failures are
# recorded on the row as conform_status = 'failed'.
class ConformMediaJob < ApplicationJob
  queue_as :default

  def perform(media_id, channel_id, uuid, raw_path)
    Conform.conform_media(media_id: media_id, channel_id: channel_id, uuid: uuid, raw_path: raw_path)
  end
end
