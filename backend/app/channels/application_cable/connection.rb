module ApplicationCable
  # Chat was anonymous under Socket.io too: anyone can watch, and messages name
  # their sender in the payload (see ChatChannel#send_message).
  class Connection < ActionCable::Connection::Base
  end
end
