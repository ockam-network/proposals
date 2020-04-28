
defmodule Ockam.Stream.Consumer.UDPSender do
  use GenServer

  def start(name, udp_address) do
    GenServer.start_link(__MODULE__, udp_address, name: {:global, "s" <> name})
  end

  @impl true
  def init(udp_address) do
    {:ok, udp_address}
  end

  @impl true
  def handle_info(message, state = {ip, port}) do
    {:ok, socket} = :gen_udp.open(9001)
    :ok = :gen_udp.send(socket, ip, port, message)
    :gen_udp.close(socket)
    {:noreply, state}
  end
end

defmodule Ockam.Stream do
  use GenServer

  def start(stream_id) do
    GenServer.start_link(__MODULE__, nil, name: {:via, Registry, {Ockam.Stream.Registry, stream_id}})
  end

  def write(stream_id, message) do
    :ok = GenServer.call({:via, Registry, {Ockam.Stream.Registry, stream_id}}, message)
  end

  def subscribe(stream_id, pid) do
    :ok = GenServer.call({:via, Registry, {Ockam.Stream.Registry, stream_id}}, {:subscribe, pid})
  end

  @impl true
  def init(_) do
    {:ok, %{subscribers: []}}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from,  state = %{subscribers: subscribers}) do
    {:reply, :ok, %{state | subscribers: [pid | subscribers]}}
  end

  @impl true
  def handle_call(message, _from, state = %{subscribers: subscribers}) do
    Enum.each subscribers, fn subscriber -> send(subscriber, message) end
    {:reply, :ok, state}
  end
end


defmodule Ockam.Transport.UDP do
  use GenServer

  def start(name, init_args) do
    GenServer.start_link(__MODULE__, init_args, name: {:global, name})
  end

  @impl true
  def init(init_args) do
    {:ok, socket} = :gen_udp.open(init_args.port, [:binary, :inet, {:ip, init_args.ip}, {:active, true}])
    {:ok, Map.put_new(init_args, :socket, socket)}
  end

  @impl true
  def handle_info({:udp, _, from_ip, from_port, message}, state) do
    case :erlang.binary_to_term(message) do
      {:create_stream, stream_id} ->
        {:ok, _} = Ockam.Stream.start(stream_id)
      {:write_to_stream, stream_id, message} ->
        Ockam.Stream.write(stream_id, message)
      {:subscribe_to_stream, stream_id} ->
        {:ok, pid} = Ockam.Stream.Consumer.UDPSender.start(stream_id, {from_ip, from_port})
        Ockam.Stream.subscribe(stream_id, pid)
    end
    {:noreply, state}
  end
end

defmodule R do
  def run do
    {:ok, _} = Ockam.Transport.UDP.start "udp_transport", %{ip: {127,0,0,1}, port: 9000}
    {:ok, _} = Registry.start_link(keys: :unique, name: Ockam.Stream.Registry)
  end
end

defmodule B do
  def run do
    r = %{ip: {127,0,0,1}, port: 9000}
    {:ok, socket} = :gen_udp.open(6000)
    :gen_udp.send(socket, r.ip, r.port, :erlang.term_to_binary({:create_stream, "B"}))
    :gen_udp.send(socket, r.ip, r.port, :erlang.term_to_binary({:subscribe_to_stream, "B"}))
    loop({r, socket})
  end

  def loop({r, socket}) do
    receive do
      {:udp, _, sender_ip, sender_port, message} ->
        decoded = :erlang.binary_to_term(:erlang.list_to_binary(message))
        IO.puts "Sender: #{inspect sender_ip}, #{sender_port} - #{inspect message}, #{inspect decoded}"
        case decoded do
          {reply_to, "ping"} ->
            :gen_udp.send(socket, r.ip, r.port, :erlang.term_to_binary({:write_to_stream, reply_to, "pong"}))
          _ -> :ignore
        end
      _ -> :ignore
    end
    loop({r, socket})
  end
end

defmodule A do
  def run do
    r = %{ip: {127,0,0,1}, port: 9000}
    {:ok, socket} = :gen_udp.open(3000)
    :gen_udp.send(socket, r.ip, r.port, :erlang.term_to_binary({:create_stream, "A"}))
    :gen_udp.send(socket, r.ip, r.port, :erlang.term_to_binary({:subscribe_to_stream, "A"}))
    :gen_udp.send(socket, r.ip, r.port, :erlang.term_to_binary({:write_to_stream, "B",
      :erlang.term_to_binary({"A", "ping"})
    }))
    loop(socket)
  end

  def loop(socket) do
    receive do
      {:udp, _, sender_ip, sender_port, message} ->
        IO.puts "Sender: #{inspect sender_ip}, #{sender_port} - #{message}"
      _ -> :ignore
    end
    loop(socket)
  end
end
