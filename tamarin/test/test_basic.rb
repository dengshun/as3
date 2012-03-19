require 'rubygems'
require 'minitest/autorun'
require 'helper'
require 'benchmark'
require 'avm_shell'
require 'avm_runner'

class TestBasic < MiniTest::Unit::TestCase
 
  
  def self.before_suite
    Thread.abort_on_exception = true
    @runner = AvmRunner.new('/home/marvel/ssa/tamarin/bin/libavmshell_debugger.so')
    @runner.transport = 'ipc'
    @thread = @runner.start_vm('as3/mb_test.abc',10)
  end
  
  def self.vm
    @runner
  end
    
  def self.after_suite
    
  end
    
  def random_string(r=10)
    a = Kernel.rand(r) + r
    #p "#{r} -> #{a}"
    alphanumerics = [('0'..'9'),('A'..'Z'),('a'..'z')].map {|range| range.to_a}.flatten
    (r...a).map { alphanumerics[Kernel.rand(alphanumerics.size)] }.join
  end
  
  def random_struct
    h = {}
    Kernel.rand(10).times do |a|
      ar = []
      (Kernel.rand(10) + 1).times do |b|
        ar.push random_string(128)
      end
      ar += [1,0,nil,'',-20,"1.87",true,false,{},[]]
      h[random_string(10)] = ar 
    end
    h
  end
  
  def send_receive
    vm = self.class.vm
    100.times do |i|
      reply = nil
      data = {:c => 'MbTest', :f => :echoDict, :args => [random_struct]}
      time = Benchmark.realtime {reply = vm.send_message(data)}
      p "#{reply.size} in #{time}"
      assert_equal data[:args].first,reply
    end
  end
  
  
  def dtest_send_receive
    send_receive
  end
  
  def test_concurrent_send_receive
    threads = []
    10.times do
      threads << Thread.new do
        send_receive
      end
    end
    threads.each {|t| t.join}
  end
 
end