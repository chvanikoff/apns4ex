defmodule APNS.Package do
  def to_binary(message, payload) do
    token_bin = message.token |> Base.decode16!(case: :mixed)

    frame = <<
      1                  :: 8,
      32                 :: 16,
      token_bin          :: binary,
      2                  :: 8,
      byte_size(payload) :: 16,
      payload            :: binary,
      3                  :: 8,
      4                  :: 16,
      message.id         :: 32,
      4                  :: 8,
      4                  :: 16,
      message.expiry     :: 32,
      5                  :: 8,
      1                  :: 16,
      message.priority   :: 8
    >>

    <<
      2                 ::  8,
      byte_size(frame)  ::  32,
      frame             ::  binary
    >>
  end
end
