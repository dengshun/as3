module As3
  class Writer < Parslet::Transform
    rule(:function_declaration => {:function_parameter_list => {:first => simple(:first), :rest => sequence(:rest)}}) do
      raise 'help'
    end
    
#    rule(:str => simple(:x)) { x.to_s }
#    rule(:ident => simple(:x)) { x.to_s }
#    rule(:s => simple(:x)) { x.to_s }
#    rule(:sp => simple(:x)) { x.to_s }
#    rule(:sp => sequence(:x)) { x.to_s }
    
    rule(:variable_type_expr => {:r => subtree(:s)}) do
     raise s
    end
    
    rule(:package_name => simple(:package_name)) do
      raise 'package'
    end
    
    
  end
end