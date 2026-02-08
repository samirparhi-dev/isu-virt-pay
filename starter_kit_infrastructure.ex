# iSupayX Assessment - Starter Kit Infrastructure
# Pre-built helpers that candidates can use without heavy lifting

defmodule iSupayX.Infrastructure.Queue do
  @moduledoc """
  Simple in-memory queue implementation using Elixir Agent.
  Candidates can use this directly for pub/sub without building from scratch.

  Usage:
    {:ok, pid} = Queue.start_link()
    Queue.enqueue(pid, {:event, "transaction.authorized", %{id: 123}})
    Queue.dequeue(pid)
  """

  use Agent

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> :queue.new() end, name: name)
  end

  def enqueue(pid, item) do
    Agent.update(pid, fn queue ->
      :queue.in(item, queue)
    end)
  end

  def dequeue(pid) do
    Agent.get_and_update(pid, fn queue ->
      case :queue.out(queue) do
        {{:value, item}, new_queue} -> {item, new_queue}
        {:empty, queue} -> {nil, queue}
      end
    end)
  end

  def peek(pid) do
    Agent.get(pid, fn queue ->
      case :queue.peek(queue) do
        {:value, item} -> item
        :empty -> nil
      end
    end)
  end

  def size(pid) do
    Agent.get(pid, fn queue ->
      :queue.len(queue)
    end)
  end

  def is_empty?(pid) do
    size(pid) == 0
  end

  def clear(pid) do
    Agent.update(pid, fn _queue -> :queue.new() end)
  end
end


defmodule iSupayX.Infrastructure.PubSub do
  @moduledoc """
  Simple pub/sub system using Phoenix.PubSub.
  Wraps Phoenix.PubSub for easier use.

  Usage:
    # In your application.ex, add to supervision tree:
    {Phoenix.PubSub, name: iSupayX.PubSub}

    # Publish event:
    PubSub.publish("transaction.authorized", %{transaction_id: "txn_123"})

    # Subscribe:
    PubSub.subscribe("transaction.authorized")

    # In your GenServer/process, handle broadcast:
    def handle_info({:event, topic, payload}, state) do
      # Handle event
      {:noreply, state}
    end
  """

  def publish(topic, payload) do
    Phoenix.PubSub.broadcast(
      iSupayX.PubSub,
      topic,
      {:event, topic, payload}
    )
  end

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(iSupayX.PubSub, topic)
  end

  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(iSupayX.PubSub, topic)
  end

  @doc """
  Hierarchical topic support for wildcard subscriptions.
  Example: "transaction.*" subscribes to "transaction.authorized", "transaction.failed", etc.
  """
  def subscribe_pattern(pattern) do
    # For simplicity, exact matching. Candidates can enhance this.
    subscribe(pattern)
  end

  def publish_to_pattern(pattern, payload) do
    publish(pattern, payload)
  end
end


defmodule iSupayX.Infrastructure.RateLimiter do
  @moduledoc """
  Token bucket rate limiter using ETS.
  Helps candidates implement velocity checks without building from scratch.

  Usage:
    RateLimiter.check_rate(merchant_id, limit: 10, window: 60_000)
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    table = :ets.new(:rate_limiter, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @doc """
  Check if the key is within rate limit.
  Returns {:ok, remaining} or {:error, :rate_limit_exceeded}

  Options:
    - limit: number of requests allowed
    - window: time window in milliseconds
  """
  def check_rate(key, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    window = Keyword.get(opts, :window, 60_000)

    now = System.system_time(:millisecond)
    cutoff = now - window

    case :ets.lookup(:rate_limiter, key) do
      [] ->
        # First request
        :ets.insert(:rate_limiter, {key, [now]})
        {:ok, limit - 1}

      [{^key, timestamps}] ->
        # Filter out old timestamps
        recent = Enum.filter(timestamps, fn ts -> ts > cutoff end)

        if length(recent) >= limit do
          {:error, :rate_limit_exceeded}
        else
          new_timestamps = [now | recent]
          :ets.insert(:rate_limiter, {key, new_timestamps})
          {:ok, limit - length(new_timestamps)}
        end
    end
  end

  def reset(key) do
    :ets.delete(:rate_limiter, key)
    :ok
  end
end


defmodule iSupayX.Infrastructure.IdempotencyCache do
  @moduledoc """
  Simple idempotency cache using ETS.
  Stores request/response pairs to prevent duplicate processing.

  Usage:
    IdempotencyCache.get("idempotency-key-123")
    IdempotencyCache.put("idempotency-key-123", %{status: 201, body: ...}, ttl: 86_400_000)
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    table = :ets.new(:idempotency_cache, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @doc """
  Get cached response for idempotency key.
  Returns {:ok, response} or :not_found
  """
  def get(key) do
    case :ets.lookup(:idempotency_cache, key) do
      [] ->
        :not_found

      [{^key, response, expires_at}] ->
        now = System.system_time(:millisecond)

        if now < expires_at do
          {:ok, response}
        else
          # Expired, delete
          :ets.delete(:idempotency_cache, key)
          :not_found
        end
    end
  end

  @doc """
  Cache response for idempotency key with TTL in milliseconds.
  Default TTL: 24 hours
  """
  def put(key, response, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 86_400_000)  # 24 hours
    expires_at = System.system_time(:millisecond) + ttl

    :ets.insert(:idempotency_cache, {key, response, expires_at})
    :ok
  end

  def delete(key) do
    :ets.delete(:idempotency_cache, key)
    :ok
  end
end


defmodule iSupayX.Infrastructure.DistributedLock do
  @moduledoc """
  Simple distributed lock implementation using ETS.
  In production, use Redis or similar, but this works for the assessment.

  Usage:
    case DistributedLock.acquire("merchant:#{merchant_id}", ttl: 30_000) do
      {:ok, lock_ref} ->
        # Do work
        DistributedLock.release(lock_ref)

      {:error, :lock_held} ->
        # Someone else has the lock
    end

  Or use with_lock/3:
    DistributedLock.with_lock("merchant:#{merchant_id}", [ttl: 30_000], fn ->
      # Do work here
    end)
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    table = :ets.new(:distributed_locks, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  @doc """
  Acquire a lock with TTL.
  Returns {:ok, lock_ref} or {:error, :lock_held}
  """
  def acquire(resource, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 30_000)
    timeout = Keyword.get(opts, :timeout, 0)

    lock_ref = make_ref()
    expires_at = System.system_time(:millisecond) + ttl

    result = try_acquire(resource, lock_ref, expires_at, timeout)

    case result do
      :ok -> {:ok, lock_ref}
      :error -> {:error, :lock_held}
    end
  end

  defp try_acquire(resource, lock_ref, expires_at, timeout) do
    deadline = System.system_time(:millisecond) + timeout

    case do_acquire(resource, lock_ref, expires_at) do
      :ok ->
        :ok

      :error when timeout > 0 ->
        # Wait and retry
        now = System.system_time(:millisecond)

        if now < deadline do
          Process.sleep(50)
          try_acquire(resource, lock_ref, expires_at, deadline - now)
        else
          :error
        end

      :error ->
        :error
    end
  end

  defp do_acquire(resource, lock_ref, expires_at) do
    now = System.system_time(:millisecond)

    case :ets.lookup(:distributed_locks, resource) do
      [] ->
        # No lock exists, acquire it
        :ets.insert(:distributed_locks, {resource, lock_ref, expires_at})
        :ok

      [{^resource, _existing_ref, existing_expires}] ->
        # Check if expired
        if now >= existing_expires do
          # Expired, can acquire
          :ets.insert(:distributed_locks, {resource, lock_ref, expires_at})
          :ok
        else
          # Still held
          :error
        end
    end
  end

  @doc """
  Release a lock by lock reference.
  """
  def release(lock_ref) when is_reference(lock_ref) do
    # Find and delete by lock_ref
    :ets.match_delete(:distributed_locks, {:_, lock_ref, :_})
    :ok
  end

  def release(resource) when is_binary(resource) do
    :ets.delete(:distributed_locks, resource)
    :ok
  end

  @doc """
  Execute function with lock acquired.
  Automatically releases lock after execution.
  """
  def with_lock(resource, opts \\ [], fun) do
    case acquire(resource, opts) do
      {:ok, lock_ref} ->
        try do
          fun.()
        after
          release(lock_ref)
        end

      {:error, :lock_held} = error ->
        error
    end
  end
end


defmodule iSupayX.Infrastructure.RetryBackoff do
  @moduledoc """
  Exponential backoff helper for retries.

  Usage:
    RetryBackoff.with_retry([max_attempts: 3, base_delay: 1000], fn ->
      # Attempt risky operation
    end)
  """

  def with_retry(opts \\ [], fun) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay = Keyword.get(opts, :base_delay, 1000)
    max_delay = Keyword.get(opts, :max_delay, 30_000)

    do_retry(fun, 1, max_attempts, base_delay, max_delay)
  end

  defp do_retry(fun, attempt, max_attempts, _base_delay, _max_delay)
       when attempt > max_attempts do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(fun, attempt, max_attempts, base_delay, max_delay) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} = error ->
        if attempt < max_attempts do
          # Calculate exponential backoff
          delay = min(base_delay * :math.pow(2, attempt - 1), max_delay)
          Process.sleep(round(delay))
          do_retry(fun, attempt + 1, max_attempts, base_delay, max_delay)
        else
          error
        end

      other ->
        other
    end
  end

  @doc """
  Calculate backoff delay for attempt number.
  """
  def calculate_delay(attempt, base_delay \\ 1000, max_delay \\ 30_000) do
    delay = base_delay * :math.pow(2, attempt - 1)
    min(delay, max_delay) |> round()
  end
end
