



defmodule Ockam.Message do
  use Bitwise

  defstruct version: 1, onward_route: [], return_route: [], payload: ""

  def decode_varint_u2le(<<0::1, b1::unsigned-integer-7, rest::binary>>), do: {b1, rest}
  def decode_varint_u2le(<<1::1, b1::unsigned-integer-7, 0::1, b2::unsigned-integer-7, rest::binary>>), do:
    {(b2 <<< 7) + b1, rest}

  def encode_varint_u2le(i) when i >= 0   and i < 128,   do: <<0::1, i::unsigned-integer-7>>
  def encode_varint_u2le(i) when i >= 128 and i < 16384, do:
    <<1::1,  (i &&& 0b01111111)::unsigned-integer-7, 0::1, ((i >>> 7) &&& 0b01111111)::unsigned-integer-7>>

  def decode(encoded) do
    {version, rest} = decode_varint_u2le(encoded)
    case version do
      1 -> Ockam.Message.V1.decode(rest)
    end
  end

  def encode(message = %Ockam.Message{version: version}) do
    case version do
      1 -> Ockam.Message.V1.encode(message)
    end
  end
end




defmodule Ockam.Message.V1 do

  def decode_host_address(<<0::8, a::8, b::8, c::8, d::8, rest::binary>>), do: {{a,b,c,d}, rest}
  def decode_host_address(<<1::8, a::unsigned-little-integer-16, b::unsigned-little-integer-16,
                                  c::unsigned-little-integer-16, d::unsigned-little-integer-16,
                                  e::unsigned-little-integer-16, f::unsigned-little-integer-16,
                                  g::unsigned-little-integer-16, h::unsigned-little-integer-16,
                                  rest::binary>>) do
     {{a,b,c,d,e,f,g,h}, rest}
  end
  def decode_host_address(<<2::8, length::8, encoded::binary>>) do
    <<address::binary-size(length), rest::binary>> = encoded
    {address, rest}
  end

  def decode_socket_address(protocol, encoded) do
    {host_address, <<port::unsigned-little-integer-16, rest::binary>>} = decode_host_address(encoded)
    {{protocol, {host_address, port}}, rest}
  end

  def decode_address(<<0::8, length::8, encoded::binary>>) do
    <<address::binary-size(length), rest::binary>> = encoded
    {address, rest}
  end
  def decode_address(<<1::8, rest::binary>>), do: decode_socket_address(:tcp, rest)
  def decode_address(<<2::8, rest::binary>>), do: decode_socket_address(:udp, rest)

  def decode_addressses(0, addresses, rest), do: {Enum.reverse(addresses), rest}
  def decode_addressses(n, addresses, message) do
    {address, rest} = decode_address(message)
    decode_addressses(n-1, [address | addresses], rest)
  end

  def decode_route(<<number_of_addresses::unsigned-integer-8, rest::binary>>) do
    decode_addressses(number_of_addresses, [], rest)
  end

  def decode_payload(<<0::8>>), do: :ping
  def decode_payload(<<1::8>>), do: :pong
  def decode_payload(payload), do: payload

  def decode(encoded) do
    {onward_route, rest} = decode_route(encoded)
    {return_route, rest} = decode_route(rest)
    payload = decode_payload(rest)
    %Ockam.Message{version: 1, onward_route: onward_route, return_route: return_route, payload: payload}
  end

  def encode_host_address({a, b, c, d}), do: <<0::8, a::8, b::8, c::8, d::8>>
  def encode_host_address({a, b, c, d, e, f, g, h}) do
    <<1::8, a::unsigned-little-integer-16, b::unsigned-little-integer-16,
            c::unsigned-little-integer-16, d::unsigned-little-integer-16,
            e::unsigned-little-integer-16, f::unsigned-little-integer-16,
            g::unsigned-little-integer-16, h::unsigned-little-integer-16>>
  end

  def encode_address(address) when is_binary(address), do: <<0::8, byte_size(address)::8>> <> address
  def encode_address({:tcp, {host, port}}),
    do: <<1::8>> <> encode_host_address(host) <> <<port::unsigned-little-integer-16>>
  def encode_address({:udp, {host, port}}),
    do: <<2::8>> <> encode_host_address(host) <> <<port::unsigned-little-integer-16>>

  def encode_addresses([], encoded), do: encoded
  def encode_addresses([address | addresses], encoded) do
    encode_addresses(addresses, encoded <> encode_address(address))
  end

  def encode_route(addresses)do
    number_of_addresses = length(addresses)
    encode_addresses(addresses, <<number_of_addresses::unsigned-integer-8>>)
  end

  def encode_payload(:ping), do: <<0::8>>
  def encode_payload(:pong), do: <<1::8>>
  def encode_payload(payload), do: payload

  def encode(%Ockam.Message{onward_route: onward, return_route: return, payload: payload}) do
    onward_route = encode_route(onward)
    return_route = encode_route(return)
    <<1>> <> onward_route <> return_route <> encode_payload(payload)
  end

end
