defmodule APNS.SslConfiguration do
  import APNS.Utils.Map, only: [compact_to_list: 1, rename_key: 3]

  defstruct [
    reuse_sessions: false,
    mode: :binary,
    certfile: nil,
    cert_password: nil,
    cert: nil,
    key: nil,
    keyfile: nil
  ]

  def get(options) do
    global = Application.get_all_env(:apns) |> Enum.into(%{})
    options = Enum.into(options, %{})

    %__MODULE__{}
    |> struct(global)
    |> struct(options)
    |> certfile_path()
    |> cert_password()
    |> cert()
    |> key()
    |> keyfile()
    |> Map.from_struct()
    |> rename_key(:cert_password, :password)
    |> compact_to_list()
  end

  defp certfile_path(%{certfile: nil} = config), do: config
  defp certfile_path(%{certfile: path} = config) when is_binary(path), do: Map.put(config, :certfile, Path.expand(path))
  defp certfile_path(%{certfile: {app_name, path}} = config) when is_atom(app_name) do
    path = Path.expand(path, :code.priv_dir(app_name))
    Map.put(config, :certfile, path)
  end

  defp cert_password(%{cert_password: nil} = config), do: config
  defp cert_password(%{cert_password: password} = config), do: Map.put(config, :cert_password, to_char_list(password))

  defp cert(%{cert: nil} = config), do: config
  defp cert(%{cert: binary_cert} = config) do
    [{:Certificate, cert_der, _}] = :public_key.pem_decode(binary_cert)
    Map.put(config, :cert, cert_der)
  end

  defp key(%{key: nil} = config), do: config
  defp key(%{key: binary_key} = config) do
    [{:RSAPrivateKey, key_der, _}] = :public_key.pem_decode(binary_key)
    Map.put(config, :key, key_der)
  end

  defp keyfile(%{keyfile: nil} = config), do: config
  defp keyfile(%{keyfile: binary_keyfile} = config), do: Map.put(config, :keyfile, Path.absname(binary_keyfile))
end
