require 'rubygems'
require 'parslet'
require 'parslet/convenience'
require 'pp'
#require 'expressions'
require 'common'
require 'writer'

module As3
  module Grammar
    include Parslet

    def str_as(value)
      if ['[','{','('].include?(value)
        name = :lb
      elsif [']','}',')'].include?(value)
        name = :rb
      else
        name = value.to_sym
      end
      str(value).as(:str)
    end

    alias_method :`, :str_as
    alias_method :str_as, :str
    
    rule :source_file do
      (package >> sp? >> klass.maybe >> sp? >> (package >> sp? >> klass.maybe >> sp?).repeat >> sp?).as(:source)
    end

    rule :statements do
      statement.repeat >> sp?
    end
  
    rule :package_statement do
      package_ifdef |
      import |
      klass |
      function |
      function_statement |
      namespace_definition |
      interface_definition |
      binding_statement
    end

    rule :statement do
      variable_declaration_no_assign |
      variable_declaration |
      ifdef |
      switch_statement |
      function |
      inline_function_declaration |
      variable_assignment_statement |
      iteration_statement |
      if_statement |
      try_statement |
      throw_statement |
      return_statement |
      break_statement |
      continue_statement |
      function_statement |
      variable_type_expr |
      case_clause |
      block

    end

    rule :package do
      sp? >> `package` >> sp? >> package_name >> sp? >> package_block >> sp?
    end

    rule :package_block do
      `{` >> sp? >> (package_statement >> sp?).repeat >> sp? >> `}`
    end

    rule :block do
      `{` >> sp? >> (sp? >> statement.as(:statement) >> sp? | sp? >> any_in_block.as(:asis) >> sp?).repeat >> sp? >> `}` >> sp?
    end

    rule :package_ifdef_block do
      `{` >> sp? >> import.repeat >> sp? >> `}`
    end

    rule :package_ifdef do
      sp? >> ident >> `::` >> ident >> sp? >> package_ifdef_block >> sp?
    end

    rule :ifdef do
      sp? >> ident >> `::` >> ident >> sp? >> block >> sp?
    end

    rule :if_statement do
      `if`.as(:st) >> sp? >> (condition_with_block |  condition_with_statement | if_block_inline).as(:if) >> sp? >> elsif_statement.repeat >> sp? >> else_statement.maybe >> sp?
    end

    rule :elsif_statement do
      `else` >> sp? >> `if` >> sp? >> (condition_with_block | if_block_inline).as(:elsif)
    end

    rule :else_statement do
      `else` >> sp? >> (block | (`;`.absnt? >> any).repeat >> sp? >> `;`).as(:else)  >> sp?
    end

    rule :if_statement_inline do
      `if`.as(:st) >> sp? >> if_block_inline.as(:if_inline) >> (`else` >> sp? >> `if` >> sp? >> if_block_inline.as(:elsif_inline)).repeat >> sp? >> (`else` >> sp? >> ((`;`.absnt? >> any).repeat).as(:else_inline)).maybe
    end

    rule :condition_with_block do
      (`(` >> sp? >> any_in_rb.repeat >> `)` >> sp? >> (`||` | `&&`).maybe >> sp?).repeat >> sp? >> block >> sp?
    end
    
    rule :condition_with_statement do
      `(` >> sp? >> any_in_rb.repeat >> `)` >> sp? >> statement >> sp?
    end
    
    rule :if_block_inline do
      rb_any >> sp? >> (`;`.absnt? >> any).repeat >> sp? >> `;` >> sp?
    end

    rule :iteration_statement do
      label.maybe >> sp? >> `do`.as(:st) >> sp? >> block.as(:code) >> sp? >> `while` >> sp? >> `(` >> sp? >> any_in_rb.repeat.as(:do_while) >> sp? >> `)` >> sp? >> `;` |
      label.maybe >> sp? >> `while`.as(:st) >> sp? >> `(` >> sp? >> any_in_rb.repeat >> `)` >> sp? >> block.as(:code) |
      label.maybe >> sp? >> `for`.as(:st) >> sp? >> `each` >> sp? >> `(` >> sp? >> `var`.maybe >> sp? >> (variable_type_expr | ident).maybe >> sp? >> `in` >> sp? >> (xml_expr | function_expr | call_expression | vector | variable_name) >> sp? >> `)` >> sp? >> block |
      label.maybe >> sp? >> `for`.as(:st) >> sp? >> `(` >> sp? >> `var` >> sp? >> variable_type_expr >> sp? >> `in` >> sp? >> (xml_expr | function_expr | call_expression | vector | variable_name) >> sp? >> `)` >> sp? >> block |
      label.maybe >> sp? >> `for`.as(:st) >> sp? >> `(` >> sp? >> any_in_rb.repeat >> `)` >> sp? >> block
    end

    rule :try_statement do
      `try`.as(:st) >> sp? >> block.as(:try) >> sp? >> (catch_statement >> sp?).repeat >> finally_statement.maybe
    end

    rule :catch_statement do
      `catch` >> sp? >> `(` >> sp? >> variable_type_expr.as(:catch_var) >> sp? >> `)` >> sp? >> block.as(:catch)
    end

    rule :finally_statement do
      `finally` >> sp? >> block.as(:finally)
    end

    rule :switch_consume do
      (`switch`.as(:st) >> sp? >> rb_any.as(:switch) >> sp? >> block.as(:cases)).as(:switch_statement)
    end

    rule(:case_block) do
      `{` >> sp? >> case_clause.repeat >> (default_clause >> case_clause.repeat).maybe >> `}`
    end
    
    rule(:case_clause) do
      `case`.as(:st) >> sp? >> expression.as(:case) >> sp? >> `:` >> sp? >> statements.as(:code) >> sp?
    end
    
    rule(:default_clause) do
      `default`.as(:default) >> sp? >> `:` >> sp? >> statements.as(:code) >> sp?
    end
    
    rule(:switch_statement) do
      (`switch`.as(:st) >> sp? >> `(` >> sp? >> expression_rh.as(:switch) >> sp? >> `)` >> sp? >> case_block.as(:cases)).as(:switch_statement) >> sp?
    end

    rule(:throw_statement) do
      `throw`.as(:st) >> sp? >> ident.as(:throw) >> sp? >> `;`
    end

    rule(:continue_statement) do
      `continue`.as(:st) >> (sp >> ident).maybe.as(:continue) >> sp? >> `;`
    end

    rule(:break_statement) do
      `break`.as(:st) >> (sp >> ident).maybe.as(:break) >> sp? >> `;`
    end

    rule(:return_statement) do
      `return`.as(:st) >> (`;`.absnt? >> any).repeat.as(:return) >> sp? >> `;`
    end
    
    rule :delete_statement do
      `delete`.as(:st) >> (`;`.absnt? >> any).repeat.as(:return) >> sp? >> `;`
    end

    

    rule :any_in_block do
      (`}`.absnt? >> any.as(:any))
    end

    rule :sb_any do
      `[` >> sp? >> any_in_sb.as(:any_in_sb).repeat >> sp? >> `]`
    end

    rule :any_in_sb do
      (`]`.absnt? >> any.as(:any))
    end

    rule :any_in_rb do
      function_expr | rb_any | (`)`.absnt? >> any.as(:any))
    end

    rule :rb_any do
      (`(` >> sp? >> any_in_rb.as(:rb_any).repeat >> sp? >> `)`)
    end

    rule :import do
      (`import` >> sp? >> package_name >> (`;` | sp) >> sp?).as(:import)
    end


    rule :klass do
      (visibility.maybe.as(:visibility) >> sp? >> ident_type.maybe >> sp? >> `class` >> sp? >> ident.as(:classname) >> sp? >> extends.maybe >> sp? >> implements.maybe >> sp? >> block).as(:class)
    end

    rule :extends do
      `extends` >> sp? >> ident
    end

    rule :implements do
      `implements` >> sp? >> ident
    end

    rule :function do
      sp? >> function_declaration >> sp? >> block
    end

    rule :namespace_definition do
      visibility.maybe.as(:visibility) >> sp? >> `namespace` >> sp? >> ident >> sp? >> (`;`.absnt? >> any).repeat >> sp? >> `;` >> sp?
    end
    
    rule :interface_definition do
      visibility.maybe.as(:visibility) >> sp? >> ident_type.maybe >> sp? >> `interface` >> sp? >> ident >> sp? >> extends.maybe >> sp? >> block >> sp?
    end
    
    rule :function_declaration do
      (visibility.maybe.as(:visibility) >> sp? >> ident_type.maybe >> sp? >> `function` >> sp? >> (`get` | `set`).maybe >> sp? >> ident >> sp? >> `(` >> function_parameter_list.maybe >> `)` >> sp? >> (`:` >> sp? >> return_type).maybe >> sp?).as(:function_declaration)
    end

    rule :inline_function_declaration do
      (visibility.maybe.as(:visibility) >> sp? >> ident_type.maybe >> sp? >> (variable_type_expr | ident) >> sp? >> `=` >> sp? >>  `function` >> sp? >> `(` >> function_parameter_list.maybe >> `)` >> sp? >> (`:` >> sp? >> return_type).maybe >> sp? >> block >> sp? >> `;` >> sp?).as(:inline_function_declaration)
    end
    
    rule :inline_function do
      sp? >> `function` >> sp? >> `(` >> function_parameter_list.maybe >> `)` >> sp? >> (`:` >> sp? >> return_type).maybe >> sp? >> block >> sp?
    end
    
    rule :function_parameter_list do
      sp? >> (rest | function_parameter).as(:first) >> (sp? >> `,` >> sp? >> (rest | function_parameter)).repeat.as(:rest) >> sp?
    end

    rule :function_parameter do
      variable_type_expr >> sp? >> variable_assignment_rh.maybe >> sp?
    end

    rule :function_statement do
      (sp? >> function_expr >> `;` >> sp?).as(:function_statement)
    end

    rule :function_expr do
      (sp? >> `new`.maybe >> sp? >> (call_expression.maybe >> function_call >> call_expression.maybe >> rb_any.repeat).repeat(1, 100)).as(:function_expr)
    end

    rule :function_call do
      sp? >> (`!` | `.`).maybe >> `(` >> function_argument_list.maybe.as(:function_argument_list) >> `)` >> sp?
    end

    rule :function_argument_list do
      (sp? >> (expression_rh).as(:first) >> (sp? >> `,` >> sp? >> expression_rh >> sp?).repeat.as(:rest) >> sp?).as(:function_argument_list)
    end

    rule :variable_declaration_no_assign do
      (visibility.maybe.as(:visibility) >> sp? >> ident_type.maybe.as(:ident_type) >> sp? >> `var` >> sp? >> variable_type_expr >> sp? >> `;` >> sp?).as(:variable_declaration_no_assign)
    end
    
    rule :variable_declaration do
      (visibility.maybe.as(:visibility) >> sp? >> ident_type.maybe.as(:ident_type) >> sp? >> `var`.maybe >> sp? >> variable_type_expr >> sp? >> variable_assignment_rh >> sp? >> (`(` >> `)`).maybe >> `;` >> sp?).as(:variable_declaration)
    end

    rule :variable_assignment_statement do
      (sp? >> variable_name >> sp? >> variable_assignment_rh >> sp? >> `;` >> sp?).as(:variable_assignment_statement)
    end

    rule :variable_type_expr do
      (ident.as(:l) >> space? >> `:` >> space? >> (vector | call_expression | ident).as(:r)).as(:variable_type_expr)
    end

    rule :vector do
      (ident >> `.` >> `<` >> (vector | ident).repeat >> `>`).as(:vector)
    end

    rule :variable_assignment_rh do
      (sp? >> assignment_operator.as(:op) >> sp? >> `new`.maybe >> sp? >> (ternary_expr | expression_rh ) >> sp?).as(:variable_assignment_rh)
    end
    
    

    rule :rest do
      `...` >> ident.as(:rest) >> (space? >> `:` >> space? >> (vector | ident)).maybe
    end
    
    rule :xml_literal do
      sp? >> (`<` >> ((`/>` | `>`).absnt? >> any).repeat >> `/>`) | (xml_open >> (xml_close.absnt? >> any).repeat >> xml_close) >> sp?
    end
    
    rule :xml_open do
      (`<` >> (`>`.absnt? >> any.as(:any)).repeat >> `>`)
    end
    
    rule :xml_close do
      (`</` >> (`>`.absnt? >> any.as(:any)).repeat >> `>`)
    end
    
    rule :xml_expr do
      `XML` >> sp? >> rb_any >> `..` >> ident
    end
    rule :binding_statement do
      sp? >> sb_any >> sp
    end
    
    rule :object_property do
      (literal | ident) >> sp? >> `:` >> sp? >> expression_rh >> sp?
    end
    
    rule :object_literal do
      (sp? >> `{` >> sp? >> object_property >> (sp? >> `,` >> sp? >> object_property).repeat >> sp? >> `}` >> sp?).as(:object_literal)
    end
    
    rule :ternary_expr do
      (sp? >>  (`?`.absnt? >> (equality_expression | expression)) >> sp? >> `?` >> sp? >> (`:`.absnt? >> any).repeat >> sp? >> `:` >> sp? >> (`;`.absnt? >> any).repeat >> sp?).as(:ternary_expression)
    end
    
    rule :additive_expression do
      expression >> (sp? >> (`+` | `-`) >> sp? >> expression).as(:additive_expr).repeat
    end
    
    rule :multiplicative_expression do
      expression >> (sp? >> (`*` | `/` | `%`) >> sp? >> expression).as(:multiplicative_expr).repeat
    end
    
    rule :relational_expression do
      expression >> (sp? >> (`<=` | `<` | `>=` | `>` | `is` | `in`) >> sp? >> expression).as(:relational_expr).repeat
    end
    
    rule :equality_expression do
      expression >> (sp? >> (`===` | `==` | `!==` | `!=`) >> sp? >> expression >> sp?).as(:equality_expr).repeat >> sp?
    end
    
    rule :postfix_expression do
      sp? >> expression >> (`++` | `--`).maybe >> sp?
    end
     
    rule :expression_rh do
      (additive_expression |
        multiplicative_expression |
        relational_expression |
        equality_expression).repeat
    end
    
    rule :expression do
      inline_function |
      inline_function_declaration |
      object_literal |
      function_expr |
      xml_literal |
      vector |
      variable_name |
      literal |
      regexp |
      variable_type_expr |
      xml_expr |
      ident|
      sb_any |
      rb_any |
      block
    end

    rule :name_or_value do
      vector |
      literal |
      regexp |
      variable_name |
      ident
    end
    
    rule :return_type do
      (vector | native_return_types | literal | ident).as(:return_type)
    end

    rule :native_return_types do
      native_types | `void` | ident
    end

    NATIVE_TYPES = %w(Object Boolean Number String Array Date Error Function Dictionary ByteArray uint int)

    rule :native_types do
      (NATIVE_TYPES.map { |w| str(w) }.inject { |l, r| l | r }).as(:native_types)
    end

    rule :ident_type do
      ((`static` >> space? >> `const`) | `static` | `const` | `final` | `override` | `dynamic`).as(:ident_type)
    end

    rule(:package_name) do
      (ident >> (`.` >> ident).repeat).as(:package_name)
    end

    rule :variable_name do
      (sp? >> call_expression >> sp? >> (`as` >> sp? >> (vector | call_expression)).maybe >> sp?).as(:variable_name)
    end
    
    rule :list_expression do
      ident >> sp? >> (`[` >> sp? >> expression.maybe >> sp? >> `]`).repeat
    end
    
    rule :call_expression do
      `.`.maybe >> list_expression >>  (sp? >> `.` >> list_expression).repeat
    end
    
    rule :label do
      (ident >> `:`).as(:label)
    end

  end

  class Main < Parslet::Parser
    include Common
    #include Expressions
    include Grammar

    root :source_file
  end

end

#parser = As3::Main.new
#pp parser.variable_name.parse_with_debug('Team.HERO')
#pp parser.expression_rh.parse_with_debug('_curChar.teamName == Team.HERO')
#pp parser.variable_declaration.parse_with_debug('var team:Team = _curChar.teamName == Team.HERO ? _heroes : _villains;')
#pp parser.variable_assignment_statement.parse_with_debug('_userData = _udm.data[0];')
#pp parser.comp_expr.parse('_character.countersWith != null')
#pp parser.variable_assignment_statement.parse('report = _character.countersWith != null;')
#exit


def phash(obj,str)
  if obj.is_a? Hash
    obj.each do |k,v|
      if v.is_a? String
        str << v
      else
        phash(v,str)
      end
    end
  elsif obj.is_a? Array
    obj.each do |i|
      if i.is_a? String
        str << i
      else
        phash(i,str)
      end
    end
  else
    str << obj unless obj.nil?
  end
end

arg = ARGV[0]
if File.directory?(arg)
  files = Dir.glob("#{arg}/**/*.as")
else
  files = [arg]
end

tree = nil
files.each do |file|
  p "processing #{file}"
  string = File.read(file)
  parser = As3::Main.new
  begin
    tree = parser.parse(string)
  rescue Parslet::ParseFailed => error
    puts error, parser.root.error_tree
    p "in #{file}"
    exit 0
  end
end

#pp tree
#exit


ast = As3::Writer.new.apply(tree)

pp ast
exit 0

str = ''
phash(tree,str)
print str
exit 0

