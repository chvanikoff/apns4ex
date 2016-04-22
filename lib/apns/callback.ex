defmodule APNS.Callback do
  def error(%APNS.Error{error: error, message_id: message_id}, token \\ "unknown token") do
    APNS.Logger.warn(~s(error "#{error}" for message #{inspect(message_id)} to #{token}))
  end

  def feedback(%APNS.Feedback{token: token}) do
    APNS.Logger.info(~s(feedback received for token #{token}))
  end
end
