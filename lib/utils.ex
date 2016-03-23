defmodule APNS.Utils.Map do
  def compact_to_list(%{} = map) do
    map |> Enum.filter(fn {_, v} -> v != nil end)
  end

  def compact(%{} = map) do
    map |> compact_to_list() |> Enum.into(%{})
  end

  def rename_key(%{} = map, old_key, new_key) do
    map |> Map.put(new_key, map[old_key]) |> Map.delete(old_key)
  end
end
