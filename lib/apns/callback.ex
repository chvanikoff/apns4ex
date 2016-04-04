defmodule APNS.Callback do
  require Logger

  def error(%APNS.Error{error: error, message_id: message_id}, token \\ "unknown token") do
    Logger.error(~s([APNS] Error "#{error}" for message #{inspect(message_id)} to #{token}))
  end

  def feedback(%APNS.Feedback{token: token}) do
    Logger.info(~s("[APNS] Feedback received for token #{token}))
  end
end
