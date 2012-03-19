module AvmShell
  class Runner
    attr_accessor :context, :transport
    include FFI::Library
    
    def initialize(so)
      ffi_lib FFI::Library::LIBC
      ffi_lib so
    
      attach_function :main, [:int, :pointer], :int
      attach_function :zmq_start_queue, [:string, :string, :int, :bool], :int
      attach_function :zmq_send_message, [:string, :string], :pointer
      attach_function :zmq_context, [], :pointer
  
    
      callback :receive_message_callback, [:pointer], :void
      attach_function :zmq_receive_message, [:pointer, :receive_message_callback], :void
      attach_function :zmq_reply_message, [:string], :void
    end
    
    
  
    def inproc_message_handler
      cb = FFI::Function.new(:void, [:pointer]) do |ptr|
        str = ptr.read_string()
        LibC.free(ptr)
        reply = message_received(str)
        zmq_reply_message(reply)
        zmq_receive_message(FFI::MemoryPointer.from_string(''),cb)
      end
      zmq_receive_message(FFI::MemoryPointer.from_string(''),cb)
    end
    
    def socket_message_handler
      ctx = ZMQ::Context.new
      s = ctx.socket ZMQ::REP
      s.connect("ipc://dealer2")
      
      while true
        msg = s.recv_string 0
        reply = message_received(msg)
        s.send_string reply, 0
      end
    end
    
    def receive_messages
      Thread.new {
        if @transport == 'inproc'
          inproc_message_handler
        else
          socket_message_handler
        end
      }
    end
  
    def message_received(str)
      message, extra = TNetstring.parse(str)
      klass = Object.const_get(message['c']);
      if message['args']
        result = klass.send(message['f'].to_sym,message['args'])
      else
        result = klass.send(message['f'].to_sym)
      end
      TNetstring.encode(result)
    rescue Exception => e
      p "Error handling received message #{e}"
      TNetstring.encode('error')
    end
  
    def send_message(msg)
      msg = TNetstring.encode(msg)
      if @transport == 'inproc'
        ptr = zmq_send_message("inproc://router",msg)
        str = ptr.read_string()
        LibC.free(ptr)
      else
        if Thread.current[:socket]
          s = Thread.current[:socket]
        else
          s =  @context.socket ZMQ::REQ
          s.connect("ipc://router")
          Thread.current[:socket] = s
        end
        
        s.send_string(msg, 0)
        str = s.recv_string 0
      end
      reply, extra = TNetstring.parse(str)
      reply
    end
  
    def start_queue
      if @transport == 'inproc'
        zmq_context
        io_threads = 0
        singleton_context = true
      else
        io_threads = 1
        singleton_context = false
        @context = ZMQ::Context.new
      end
      Thread.new do 
        zmq_start_queue("#{@transport}://router","#{@transport}://dealer",io_threads,singleton_context)
      end
      Thread.new do 
        zmq_start_queue("#{@transport}://router2","#{@transport}://dealer2",io_threads,singleton_context)
      end
      receive_messages
    end
  
    def start_vm(file,threads=1)
      start_queue
      if threads == 0
        run_vm(file,threads)
      else
        Thread.new do
          run_vm(file,threads)
        end
      end
    end
  
    def run_vm(file,threads)
      if threads > 1
        args = 3
      else
        args = 1
      end
      
      strptrs = []
      strptrs << FFI::MemoryPointer.from_string('avmshell')
      if threads > 1
        strptrs << FFI::MemoryPointer.from_string('-workers')
        strptrs << FFI::MemoryPointer.from_string("#{threads},#{threads}")
      end
      threads.times {strptrs << FFI::MemoryPointer.from_string(file)}
      strptrs << nil

      argv = FFI::MemoryPointer.new(:pointer, strptrs.length)
      strptrs.each_with_index do |p, i|
        argv[i].put_pointer(0,  p)
      end
      main(threads + args, argv)
    end

  end
end