# frozen_string_literal: true

# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative "timer"

module Timers
	# Maintains an ordered list of events, which can be cancelled.
	class Events
		# Represents a cancellable handle for a specific timer event.
		class Handle
			def initialize(time, callback)
				@time = time
				@callback = callback
			end

			# The absolute time that the handle should be fired at.
			attr_reader :time
			alias to_f time

			# Cancel this timer, O(1).
			def cancel!
				# The simplest way to keep track of cancelled status is to nullify the
				# callback. This should also be optimal for garbage collection.
				@callback = nil
			end

			# Has this timer been cancelled? Cancelled timer's don't fire.
			def cancelled?
				@callback.nil?
			end

			def > other
				@time > other.to_f
			end

			def >= other
				@time >= other.to_f
			end

			def <= other
				@time <= other.to_f
			end

			def < other
				@time < other.to_f
			end

			def == other
				@time == other.to_f
			end

			def <=> other
				@time <=> other.to_f
			end

			# Fire the callback if not cancelled with the given time parameter.
			def fire(time)
				@callback.call(time) if @callback
			end
		end

		def initialize
			# A min-heap of handles.  @heap[0] is the next event to be fired.
			@heap = []
			@queue = []
		end

		# Add an event at the given time.
		def schedule(time, callback)
			handle = Handle.new(time.to_f, callback)

			@queue << handle

			return handle
		end

		# Returns the first non-cancelled handle.
		def first
			merge!

			while handle = heap_peek
				return handle unless handle.cancelled?
				heap_pop
			end
		end

		# Returns the number of pending (possibly cancelled) events.
		def size
			@heap.size + @queue.size
		end

		# Fire all handles for which Handle#time is less than the given time.
		def fire(time)
			merge!
			time = time.to_f

			while handle = heap_pop_lte(time)
				handle.fire(time)
			end
		end

		private

		def heap_peek
			@heap[0]
		end

		def heap_pop_lte(time)
			heap_pop if @heap[0].to_f <= time
		end

		def heap_pop
			return if @heap.empty?
			return @heap.pop if @heap.size == 1
			popped = @heap[0]
			heap_delete_at(0)
			popped
		end

		# (HEAP_N - 1) / HEAP_N of the heap will be in the bottom layer
		#
		# Insert and delete takes O(log n / log d).
		#
		# However, if insertions and cancellations are concentrated in the last
		# layer, they can be done much faster on average.
		HEAP_N = 4

		def merge!
			while handle = @queue.shift
				next if handle.cancelled?
				heap_push(handle)
			end
		end

		# place at the end of the heap and sift up
		def heap_push(handle)
			@heap << handle
			heap_sift_up(@heap.size - 1, handle)
		end

		# pop the last item to overwrite the deleted item, then sift down
		def heap_delete_at(index)
			last = @heap.pop
			@heap[index] = last
			heap_sift_down(index, last)
		end

		def heap_sift_up(index, handle = @heap[index])
			htime = handle.to_f

			# and sift it up to where it belongs
			while 0 < index
				# get parent
				pindex = (index - 1) / HEAP_N
				parent = @heap[pindex]

				# parent is smaller: heap is restored
				break if parent.to_f <= htime
				# cnt[0] += 1

				# parent is larger: swap and continue sifting
				@heap[pindex] = handle
				@heap[index] = parent

				index = pindex
			end
			index
		end

		def heap_sift_down(index, handle = @heap[index])
			last_index = @heap.size - 1
			htime = handle.to_f

			# and sift it down to where it belongs
			while true
				cindex = cindex0 = (index * HEAP_N) + 1
				break if last_index < cindex0

				# cnt[0] += 1

				# find the min child (and its cindex)
				child = @heap[cindex0]
				ctime = child.to_f
				i = 1
				while i < HEAP_N && (sibindex = cindex0 + i) <= last_index
					sibling = @heap[sibindex]
					sibtime = sibling.to_f
					if sibtime < ctime
						child = sibling
						ctime = sibtime
						cindex = sibindex
					end
					i += 1
				end

				# child is larger: heap is restored
				break if htime <= ctime

				# child is smaller: swap and continue sifting
				@heap[index] = child
				@heap[cindex] = handle

				index = cindex
			end
		end

	end
end
