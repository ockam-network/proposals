Code.compile_file("./ockam.exs", __DIR__)

defmodule Test do
  def start(port) do
    {:ok, _} = Ockam.Router.start
    {:ok, _} = Ockam.Controller.start %{}
    {:ok, _} = Ockam.Transport.UDP.start %{ip: {127,0,0,1}, port: port}
  end
end

defmodule R1 do
  def start do
    Test.start(9001)
    Ockam.Channel.start "C1"
  end
end

defmodule R2 do
  def start do
    Test.start(9002)
  end
end

defmodule R3 do
  def start do
    Test.start(9003)
  end
end

defmodule R4 do
  def start do
    Test.start(9004)
  end
end

defmodule A do
  def start do
    Test.start(6000)
  end
end

defmodule B do
  def start do
    Test.start(3000)
  end
end
