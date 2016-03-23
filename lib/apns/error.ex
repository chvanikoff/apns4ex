defmodule APNS.Error do
  @statuses %{
    0 => "No errors encountered",
    1 => "Processing error",
    2 => "Missing device token",
    3 => "Missing topic",
    4 => "Missing payload",
    5 => "Invalid token size",
    6 => "Invalid topic size",
    7 => "Invalid payload size",
    8 => "Invalid token",
    10 => "Shutdown",
    255 => "None (unknown)"
  }

  defstruct [
    message_id: nil,
    status: nil,
    error: nil
  ]

  def new(message_id, status) do
    %__MODULE__{
      message_id: message_id,
      status: status,
      error: @statuses[status]
    }
  end
end
