
module MiniTestWithHooks
  class Unit < MiniTest::Unit
    
    def before_suites
    end

    def after_suites
    end

    def _run_suites(suites, type)
      begin
        before_suites
        super(suites, type)
      ensure
        after_suites
      end
    end

    def _run_suite(suite, type)
      begin
        suite.before_suite if suite.respond_to?(:before_suite)
        super(suite, type)
      ensure
        suite.after_suite if suite.respond_to?(:after_suite)
      end
    end
  end
end



module AvmShell
  class Unit < MiniTestWithHooks::Unit

    def before_suites
      super
    end

    def after_suites
      super
    end
  end
end
  
MiniTest::Unit.runner = AvmShell::Unit.new