require 'rubygems'
require 'avm_shell'


class AvmRunner < AvmShell::Runner
  
  
 
  def self.setup
   {:c => 'MbTest', :f => :loadXmlFromFile, :args => ["/home/marvel/server/rails/db/client_full.xml"]}
  end
    
end