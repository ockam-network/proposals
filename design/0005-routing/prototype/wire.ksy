
meta:
  id: ockam_message
  title: Ockam Message
  imports:
    - ockam_wire/variable_length_encoded_u2le

seq:
  - id: version
    type: variable_length_encoded_u2le

  - id: onward_route
    type: route

  - id: return_route
    type: route

  - id: message_type
    type: u1

  - id: message_body
    type:
      switch-on: message_type
      cases:
        0: ping
        1: pong

        2: payload

        3: request_channel
        4: key_agreement_t1_m2
        5: key_agreement_t1_m3

# 1: request_stream
# 2: response_to_request_stream
# 3: request_stream_consumer
# 4: response_to_request_stream_consumer
# setup_stream
# write_to_stream
# subscribe_to_steam
# push_stream_messages_to_endpoint
# setup_channel


types:
  route:
    seq:
      - id: number_of_addresses
        type: u1
      - id: addresses
        type: address
        repeat: expr
        repeat-expr: number_of_addresses

  address:
    seq:
      - id: type
        type: u1

      - id: value
        type:
          switch-on: type
          cases:
            0: local_address
            1: tcp_address
            2: udp_address

  local_address:
    seq:
      - id: length
        type: u1
      - id: local_address
        size: length.value

  udp_address:
    seq:
      - id: udp_address
        type: socket_address

  tcp_address:
    seq:
      - id: tcp_address
        type: socket_address

  socket_address:
    seq:
      - id: host
        type: host_address
      - id: port
        type: u2le

  host_address:
    - id: type
      type: u1

    - id: value
      type:
        switch-on: type
        cases:
          0: ipv4
          1: ipv6
          # 2: dns_name

  ping:
    seq:
      - id: data
        size: 0

  pong:
    seq:
      - id: data
        size: 0
