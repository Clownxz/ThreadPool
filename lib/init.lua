--!strict

--[[
    Thread Pool     1.0.0-beta
    A library for creating Thread Pools to improve performance and reduce latency.

    https://clownxz.github.io/ThreadPool/
]]

--[=[
    @class ThreadPool
    
    Recyles threads instead of creating a new thread everytime you want to run your code in a thread.
    
    **Usage**
    
    ```lua
        local ThreadPool = Require(path.to.module)
        
        local myThreadPool = ThreadPool.new()
        myThreadPool:spawn(function(...)
            print(...) -- Prints "Hello World"
        end, "Hello, world!")
    ```
]=]
local ThreadPool = {}
ThreadPool.__index = ThreadPool

--[=[
    @prop _openThreads { thread? }
    @within ThreadPool
    @private
    @tag Internal Use Only
    
    References to open threads.
]=]
ThreadPool._openThreads = {}

--[=[
    @prop _threadCount number
    @within ThreadPool
    @private
    @readonly
    @tag Internal Use Only
    
    The amount of threads to cache.
    
    Negative numbers will enable Dynamic Caching, the Absolute Value of the property will always represent the minimum amount of threads that will be kept open.
]=]
ThreadPool._threadCount = 1

--[=[
    @prop _cachedThreadLifetime number
    @within ThreadPool
    @private
    @readonly
    @tag Internal Use Only
    
    The amount of seconds a thread will be kept alive after going idle.
]=]
ThreadPool._cachedThreadLifetime = 60

--[=[
    @method _call
    @within ThreadPool
    @private
    @tag Internal Use Only
    
    An Internal Function for use when passing arguments into a recycled thread.
    
    @param callback (T...) -> nil
    @param ... T...
    
    @return void
]=]
function ThreadPool:_call<T...>(callback: (T...) -> nil, ...: T...)
	local index = #self._openThreads

	-- Store thread and remove it from openThreads table
	local thread = self._openThreads[index]
	self._openThreads[index] = nil

	-- Yield until callback finishes execution
	callback(...)
	table.insert(self._openThreads, thread) -- Store the newly opened Thread into openThreads
end

--[=[
    @method _createThread
    @within ThreadPool
    @private
    @tag Internal Use Only
    
    Creates a new thread in the ThreadPool.
    
    @return void
]=]
function ThreadPool:_createThread()
	local closeThread = false
	local index = #self._openThreads + 1

	-- Create new thread and add it to the openThreads table
	local newThread: thread | nil
	newThread = coroutine.create(function()
		local lifetime = 0

		while not closeThread do
			local currentTick = os.clock()
			self:_call(coroutine.yield())

			-- Track lifetime
			lifetime += os.clock() - currentTick

			-- Implement cachedThreadLifetime
			if lifetime >= self._cachedThreadLifetime then
				closeThread = true
				newThread = nil
				self._openThreads[index] = nil
			end
		end
	end)
	coroutine.resume(newThread :: thread)

	table.insert(self._openThreads, newThread)
end

--[=[
    @method spawn
    @within ThreadPool
    
    Runs the provided function on a new or reused thread with the supplied parameters.
    
    @param callback (...: any) -> nil
    @param ... any
    
    @return void
]=]
function ThreadPool:spawn<T...>(callback: (T...) -> nil, ...: T...)
	if #self._openThreads < 1 then
		self:_createThread()
	end

	coroutine.resume(self._openThreads[#self._openThreads], callback, ...)
	self._openThreads[#self._openThreads] = nil
end

--[=[
    @function new
    @within ThreadPool
    
    Creates a new `ThreadPool` Instance.
    
    :::note
    You can specify the amount of threads the ThreadPool will keep open by setting the `threadCount` parameter.

    You can also specify the max time the Thread will be cached for by setting the `cachedThreadLifetime` parameter.
    Setting this parameter to 0 will disable caching.
    
    @param threadCount number?
    @param cachedThreadLifetime number?
    
    @return ThreadPool
]=]
function ThreadPool.new(threadCount: number?, cachedThreadLifetime: number?)
	local self = {}
	setmetatable(self, ThreadPool)

	-- Apply properties
	self._threadCount = threadCount or self._threadCount
	self._cachedThreadLifetime = cachedThreadLifetime or self._cachedThreadLifetime

	-- Create initial new threads
	for n = 1, math.abs(self._threadCount), 1 do
		self:_createThread()
	end

	return self
end

export type ThreadPool = typeof(ThreadPool.new())

return ThreadPool