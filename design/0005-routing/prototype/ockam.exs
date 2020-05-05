Code.compile_file("./codec.exs", __DIR__)




defmodule Ockam.Stream do
  use GenServer

  def start(name) do
    GenServer.start_link(__MODULE__, %{subscribers: []}, name: {:via, Registry, {Ockam.Router, name}})
  end

  def subscribe(name, pid) do
    :ok = GenServer.cast({:via, Registry, {Ockam.Router, name}}, {:subscribe, pid})
  end

  @impl true
  def init(init_args) do
    {:ok, init_args}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state = %{subscribers: subscribers}) do
    {:noreply, %{state | subscribers: [pid | subscribers]}}
  end

  @impl true
  def handle_info({:routed, {name, message}}, state = %{subscribers: subscribers}) do
    IO.inspect {"Stream incoming", name, message}
    Enum.each subscribers, fn subscriber -> send(subscriber, {:response, message}) end
    {:noreply, state}
  end
end




defmodule Ockam.Channel do
  use GenServer

  def start(name) do
    GenServer.start_link(__MODULE__, %{name: name}, name: {:via, Registry, {Ockam.Router, name}})
  end

  @impl true
  def init(%{name: name}) do
    response_stream = name <> "_response_stream"
    Ockam.Stream.start(response_stream)
    Ockam.Stream.subscribe(response_stream, self())
    {:ok, %{name: name, response_stream: response_stream, return_route: []}}
  end

  @impl true
  def handle_info({:response, message}, state = %{name: name, return_route: return_route}) do
    IO.inspect {"Channel response incoming", name, return_route, message}

    # this is where we would encrypt the payload
    out_message = %Ockam.Message{
      onward_route: return_route,
      payload: message.payload,
      return_route: [name | message.return_route]
    }

    IO.inspect {"Channel response outgoing", name, message}
    Ockam.Router.route(out_message)

    {:noreply, state}
  end

  @impl true
  def handle_info({:routed, {name, in_message}}, state = %{name: name, response_stream: response_stream}) do
    IO.inspect {"Channel routed incoming", name, in_message}

    # this where we would decrypt the payload
    out_message = Ockam.Message.decode(in_message.payload)
    out_message = if out_message.return_route === [] do
      %{out_message | return_route: [response_stream]}
    else
      out_message
    end

    IO.inspect {"Channel routed outgoing", name, out_message}
    Ockam.Router.route(out_message)

    {:noreply, %{state | return_route: in_message.return_route}}
  end
end




defmodule Ockam.Controller do
  use GenServer

  def start(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: {:via, Registry, {Ockam.Router, __MODULE__}})
  end

  @impl true
  def init(init_args) do
    {:ok, init_args}
  end

  @impl true
  def handle_info({:routed, message = %Ockam.Message{ payload: :ping }}, state) do
    IO.inspect {"Controller routed incoming", message}
    m = %Ockam.Message{ payload: :pong, onward_route: message.return_route }
    IO.inspect {"Controller routed outgoing", m}
    Ockam.Router.route(m)
    {:noreply, state}
  end

  @impl true
  def handle_info({:routed, message}, state) do
    IO.inspect {"Controller routed incoming", message}
    {:noreply, state}
  end

end




defmodule Ockam.Router do

  def start() do
    Registry.start_link(keys: :unique, name: Ockam.Router)
  end

  def dispatch(name, message) do
    Registry.dispatch(Ockam.Router, name, fn [{pid, _}] -> send(pid, {:routed, message}) end)
  end

  def route({:udp, address}, message), do: dispatch(Ockam.Transport.UDP, {address, message})

  def route(address, message) when is_binary(address), do: dispatch(address, {address, message})

  def route(message = %Ockam.Message{ onward_route: [] }), do: dispatch(Ockam.Controller, message)

  def route(message = %Ockam.Message{ onward_route: [ head | tail ] }) do
    route(head, %{message | onward_route: tail})
  end

end




defmodule Ockam.Transport.UDP do
  use GenServer

  def start(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: {:via, Registry, {Ockam.Router, __MODULE__}})
  end

  @impl true
  def init(init_args) do
    {:ok, socket} = :gen_udp.open(init_args.port, [:binary, :inet, {:ip, init_args.ip}, {:active, true}])
    {:ok, Map.put_new(init_args, :socket, socket)}
  end

  @impl true
  def handle_info({:routed, {{to_ip, to_port}, message}}, state = %{socket: socket, ip: my_ip, port: my_port}) do
    IO.inspect {"Transport.UDP routed incoming", message}

    return_route = message.return_route
    message = %{message | return_route: [{:udp, {my_ip, my_port}} | return_route]}


    IO.inspect {"Transport.UDP routed outgoing", to_ip, to_port, message}
    message = Ockam.Message.encode(message)
    :ok = :gen_udp.send(socket, to_ip, to_port, message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, _, from_ip, from_port, message}, state) do
    IO.inspect {"Transport.UDP incoming", message}

    message = Ockam.Message.decode(message)
    receiver = {:udp, {from_ip, from_port}}
    message = if message.return_route === [], do: %{message | return_route: [receiver]}, else: message

    IO.inspect {"Transport.UDP outgoing", message}
    Ockam.Router.route(message)
    {:noreply, state}
  end
end
