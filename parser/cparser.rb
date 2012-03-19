require 'rubygems'
require 'parslet'
require 'parslet/convenience'
require 'pp'


class Cparser < Parslet::Parser
  alias_method :`, :str

  rule(:source_file) do
    source_element.repeat >> sp?
  end
  root(:source_file)

  rule(:source_elements) do
    source_element.repeat
  end
  rule(:source_element) do
    sp? >> function_declaration.as(:function_declaration) | sp? >> statement.as(:statement)
  end
  rule(:statement) do
    block |
    variable_statement |
    const_statement |
    empty_statement |
    expr_statement |
    if_statement |
    iteration_statement |
    continue_statement |
    break_statement |
    return_statement |
    with_statement |
    switch_statement |
    labelled_statement |
    throw_statement |
    try_statement
  end
  rule(:literal) do
    `null` | `true` | `false` | number | string | regexp
  end
  rule(:property) do
    (ident | string | number).as(:name) >> sp? >> `:` >> sp? >> assignment_expr.as(:value) |
    ident.as(:name) >> sp >> ident.as(:prop_type) >> sp? >> `(` >> formal_parameter_list.maybe.as(:args) >> sp? >> `)` >> sp? >> `{` >> sp? >> function_body.as(:value) >> sp? >> `}`
  end
  rule(:property_list) do
    (property >> sp? >> `,` >> sp?).repeat >> property
  end
  rule(:primary_expr) do
    primary_expr_no_brace |
    `{` >> sp? >> (property_list.as(:object_literal) >> sp? >> (`,` >> sp?).maybe).maybe >> `}`
  end

  rule(:primary_expr_no_brace) do
    `this`.as(:this) |
    literal.as(:literal) |
    array_literal.as(:array) |
    ident.as(:resolve) |
    `(` >> sp? >> expr >> sp? >> `)`
  end

  rule(:array_literal) do
    `[`.as(:loc) >> sp? >> element_list.maybe.as(:elements) >> sp? >> `]`
  end

  rule(:element_list) do
    (`,`.as(:element) >> sp?).repeat.as(:leading_elision) >>
      (assignment_expr.as(:element) >> sp? >> `,` >> sp? >> (`,`.as(:element) >> sp?).repeat.as(:middle_elision)).repeat.as(:parts) >>
      assignment_expr.maybe.as(:last_element)
  end


  rule(:member_expr) do
    (
      primary_expr |
      function_expr.as(:function_expr) |
      `new`.as(:new) >> sp >> member_expr.as(:expr) >> sp? >> arguments
    ).as(:expr) >> (
      sp? >> `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      sp? >> `.` >> sp? >> ident.as(:name)
    ).as(:call).repeat.as(:calls)
  end

  rule(:member_expr_no_bf) do
    (
      primary_expr_no_brace |
      `new`.as(:new) >> sp >> member_expr.as(:expr) >> sp? >> arguments
    ).as(:expr) >> (
      sp? >> `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      sp? >> `.` >> sp? >> ident.as(:name)
    ).as(:call).repeat.as(:calls)
  end

  rule(:new_expr) do
    member_expr |
    `new`.as(:new) >> sp >> new_expr.as(:expr)
  end

  rule(:new_expr_no_bf) do
    member_expr_no_bf |
    `new`.as(:new) >> sp >> new_expr.as(:expr)
  end

  rule(:call_expr) do
    (member_expr.as(:expr) >> sp? >> arguments).as(:expr) >>
    (sp? >>
      (arguments |
      `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      `.` >> sp? >> ident.as(:name)
      )
    ).as(:call).repeat.as(:calls)
  end

  rule(:call_expr_no_bf) do
    (member_expr_no_bf.as(:expr) >> sp? >> arguments).as(:expr) >>
    (sp? >>
      (arguments |
      `[` >> sp? >> expr.as(:expr) >> sp? >> `]` |
      `.` >> sp? >> ident.as(:name)
      )
    ).as(:call).repeat.as(:calls)
  end

  rule(:arguments) do
    `(` >> sp? >> argument_list.maybe.as(:args) >> sp? >> `)`
  end

  rule(:argument_list) do
    assignment_expr.as(:first) >> (sp? >> `,` >> sp? >> assignment_expr).repeat.as(:rest)
  end

  rule(:left_hand_side_expr) do
    call_expr |
    new_expr
  end

  rule(:left_hand_side_expr_no_bf) do
    new_expr_no_bf |
    call_expr_no_bf
  end

  rule(:postfix_expr) do
    left_hand_side_expr.as(:expr) >> (sp? >> `++`.as(:postfix) | sp? >> `--`.as(:postfix)).maybe.as(:postfix_op)
  end

  rule(:postfix_expr_no_bf) do
    left_hand_side_expr_no_bf.as(:expr) >> (sp? >> `++`.as(:postfix) | sp? >> `--`.as(:postfix)).maybe.as(:postfix_op)
  end

  rule(:unary_expr_common) do
    (`delete` | `void` | `typeof` | `++` | `--` | `+` | `-` | `~` | `!`).as(:unary) >> sp? >> unary_expr.as(:expr)
  end

  rule(:unary_expr) do
    unary_expr_common |
    postfix_expr
  end

  rule(:unary_expr_no_bf) do
    unary_expr_common |
    postfix_expr_no_bf
  end

  rule(:multiplicative_expr) do
    unary_expr.as(:left) >> (sp? >> (`*` | `/` | `%`).as(:binary) >> sp? >> unary_expr.as(:right)).repeat.as(:ops)
  end
  rule(:multiplicative_expr_no_bf) do
    unary_expr_no_bf.as(:left) >> (sp? >> (`*` | `/` | `%`).as(:binary) >> sp? >> unary_expr.as(:right)).repeat.as(:ops)
  end

  rule(:additive_expr) do
    multiplicative_expr.as(:left) >> (sp? >> (`+` | `-`).as(:binary) >> sp? >> multiplicative_expr.as(:right)).repeat.as(:ops)
  end
  rule(:additive_expr_no_bf) do
    multiplicative_expr_no_bf.as(:left) >> (sp? >> (`+` | `-`).as(:binary) >> sp? >> multiplicative_expr.as(:right)).repeat.as(:ops)
  end

  rule(:shift_expr) do
    additive_expr.as(:left) >> (sp? >> (`<<` | `>>>` | `>>`).as(:binary) >> sp? >> additive_expr.as(:right)).repeat.as(:ops)
  end
  rule(:shift_expr_no_bf) do
    additive_expr_no_bf.as(:left) >> (sp? >> (`<<` | `>>>` | `>>`).as(:binary) >> sp? >> additive_expr.as(:right)).repeat.as(:ops)
  end

  rule(:relational_expr) do
    shift_expr.as(:left) >> (sp? >> (`<=` | `<` | `>=` | `>` | `instanceof` | `in`).as(:binary) >> sp? >> shift_expr.as(:right)).repeat.as(:ops)
  end
  rule(:relational_expr_no_in) do
    shift_expr.as(:left) >> (sp? >> (`<=` | `<` | `>=` | `>` | `instanceof`).as(:binary) >> sp? >> shift_expr.as(:right)).repeat.as(:ops)
  end
  rule(:relational_expr_no_bf) do
    shift_expr_no_bf.as(:left) >> (sp? >> (`<=` | `<` | `>=` | `>` | `instanceof` | `in`).as(:binary) >> sp? >> shift_expr.as(:right)).repeat.as(:ops)
  end

  rule(:equality_expr) do
    relational_expr.as(:left) >> (sp? >> (`===` | `==` | `!==` | `!=`).as(:binary) >> sp? >> relational_expr.as(:right)).repeat.as(:ops)
  end
  rule(:equality_expr_no_in) do
    relational_expr_no_in.as(:left) >> (sp? >> (`===` | `==` | `!==` | `!=`).as(:binary) >> sp? >> relational_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:equality_expr_no_bf) do
    relational_expr_no_bf.as(:left) >> (sp? >> (`===` | `==` | `!==` | `!=`).as(:binary) >> sp? >> relational_expr.as(:right)).repeat.as(:ops)
  end

  rule(:bitwise_and_expr) do
    equality_expr.as(:left) >> (sp? >> `&`.as(:binary) >> `&`.absnt? >> sp? >> equality_expr.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_and_expr_no_in) do
    equality_expr_no_in.as(:left) >> (sp? >> `&`.as(:binary) >> `&`.absnt? >> sp? >> equality_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_and_expr_no_bf) do
    equality_expr_no_bf.as(:left) >> (sp? >> `&`.as(:binary) >> `&`.absnt? >> sp? >> equality_expr.as(:right)).repeat.as(:ops)
  end

  rule(:bitwise_xor_expr) do
    bitwise_and_expr.as(:left) >> (sp? >> `^`.as(:binary) >> sp? >> bitwise_and_expr.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_xor_expr_no_in) do
    bitwise_and_expr_no_in.as(:left) >> (sp? >> `^`.as(:binary) >> sp? >> bitwise_and_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_xor_expr_no_bf) do
    bitwise_and_expr_no_bf.as(:left) >> (sp? >> `^`.as(:binary) >> sp? >> bitwise_and_expr.as(:right)).repeat.as(:ops)
  end

  rule(:bitwise_or_expr) do
    bitwise_xor_expr.as(:left) >> (sp? >> `|`.as(:binary) >> `|`.absnt? >> sp? >> bitwise_xor_expr.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_or_expr_no_in) do
    bitwise_xor_expr_no_in.as(:left) >> (sp? >> `|`.as(:binary) >> `|`.absnt? >> sp? >> bitwise_xor_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:bitwise_or_expr_no_bf) do
    bitwise_xor_expr_no_bf.as(:left) >> (sp? >> `|`.as(:binary) >> `|`.absnt? >> sp? >> bitwise_xor_expr.as(:right)).repeat.as(:ops)
  end

  rule(:logical_and_expr) do
    bitwise_or_expr.as(:left) >> (sp? >> `&&`.as(:binary) >> sp? >> bitwise_or_expr.as(:right)).repeat.as(:ops)
  end
  rule(:logical_and_expr_no_in) do
    bitwise_or_expr_no_in.as(:left) >> (sp? >> `&&`.as(:binary) >> sp? >> bitwise_or_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:logical_and_expr_no_bf) do
    bitwise_or_expr_no_bf.as(:left) >> (sp? >> `&&`.as(:binary) >> sp? >> bitwise_or_expr.as(:right)).repeat.as(:ops)
  end

  rule(:logical_or_expr) do
    logical_and_expr.as(:left) >> (sp? >> `||`.as(:binary) >> sp? >> logical_and_expr.as(:right)).repeat.as(:ops)
  end
  rule(:logical_or_expr_no_in) do
    logical_and_expr_no_in.as(:left) >> (sp? >> `||`.as(:binary) >> sp? >> logical_and_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:logical_or_expr_no_bf) do
    logical_and_expr_no_bf.as(:left) >> (sp? >> `||`.as(:binary) >> sp? >> logical_and_expr.as(:right)).repeat.as(:ops)
  end

  rule(:conditional_expr) do
    logical_or_expr.as(:cond) >> (sp? >> `?` >> sp? >> assignment_expr.as(:true_expr) >> sp? >> `:` >> sp? >> conditional_expr.as(:false_expr)).maybe
  end
  rule(:conditional_expr_no_in) do
    logical_or_expr_no_in.as(:cond) >> (sp? >> `?` >> sp? >> assignment_expr_no_in.as(:true_expr) >> sp? >> `:` >> sp? >> conditional_expr_no_in.as(:false_expr)).maybe
  end
  rule(:conditional_expr_no_bf) do
    logical_or_expr_no_bf.as(:cond) >> (sp? >> `?` >> sp? >> assignment_expr.as(:true_expr) >> sp? >> `:` >> sp? >> conditional_expr.as(:false_expr)).maybe
  end

  rule(:assignment_expr) do
    (left_hand_side_expr.as(:left) >> sp? >> assignment_operator.as(:assignment) >> sp?).repeat.as(:ops) >> conditional_expr.as(:right)
  end
  rule(:assignment_expr_no_in) do
    (left_hand_side_expr.as(:left) >> sp? >> assignment_operator.as(:assignment) >> sp?).repeat.as(:ops) >> conditional_expr_no_in.as(:right)
  end
  rule(:assignment_expr_no_bf) do
    (left_hand_side_expr_no_bf.as(:left) >> sp? >> assignment_operator.as(:assignment) >> sp?).repeat(0, 1).as(:ops) >> assignment_expr.as(:right)
  end

  rule(:assignment_operator) do
    `=` >> `=`.absnt? |
    `+=` |
    `-=` |
    `*=` |
    `/=` |
    `<<=` |
    `>>=` |
    `>>>=` |
    `&=` |
    `^=` |
    `|=` |
    `%=`
  end

  rule(:expr) do
    assignment_expr.as(:left) >> (sp? >> `,`.as(:binary) >> sp? >> assignment_expr.as(:right)).repeat.as(:ops)
  end
  rule(:expr_no_in) do
    assignment_expr_no_in.as(:left) >> (sp? >> `,`.as(:binary) >> sp? >> assignment_expr_no_in.as(:right)).repeat.as(:ops)
  end
  rule(:expr_no_bf) do
    assignment_expr_no_bf.as(:left) >> (sp? >> `,`.as(:binary) >> sp? >> assignment_expr.as(:right)).repeat.as(:ops)
  end

  rule(:block) do
    `{`.as(:st) >> sp? >> source_elements.as(:block) >> sp? >> `}`
  end

  rule(:variable_statement) do
    `var`.as(:st) >> sp >> variable_declaration_list.as(:vars) >> (sp? >> `;` | error)
  end

  rule(:variable_declaration_list) do
    variable_declaration.as(:first) >> (sp? >> `,` >> sp? >> variable_declaration).repeat.as(:rest)
  end
  rule(:variable_declaration_list_no_in) do
    variable_declaration_no_in.as(:first) >> (sp? >> `,` >> sp? >> variable_declaration_no_in).repeat.as(:rest)
  end

  rule(:variable_declaration) do
    ident.as(:var) >> (sp? >> `=` >> sp? >> assignment_expr).maybe.as(:init)
  end
  rule(:variable_declaration_no_in) do
    ident.as(:var) >> (sp? >> `=` >> sp? >> assignment_expr_no_in).maybe.as(:init)
  end

  rule(:const_statement) do
    `const` >> sp >> const_declaration_list >> (sp? >> `;` | error)
  end
  rule(:const_declaration_list) do
    const_declaration.as(:first) >> (sp? >> `,` >> sp? >> const_declaration).repeat.as(:rest)
  end
  rule(:const_declaration) do
    ident.as(:const) >> (sp? >> `=` >> sp? >> assignment_expr.as(:init)).maybe
  end

  rule(:empty_statement) do
    `;`
  end

  rule(:expr_statement) do
    expr_no_bf.as(:expr_statement) >> (sp? >> `;` | error)
  end

  rule(:if_statement) do
    `if`.as(:st) >> sp? >> `(` >> sp? >> expr.as(:if_condition) >> sp? >> `)` >> sp? >> statement.as(:true_part) >> (sp? >> `else` >> sp? >> statement).maybe.as(:false_part)
  end

  rule(:iteration_statement) do
    `do`.as(:st) >> sp? >> statement.as(:code) >> sp? >> `while` >> sp? >> `(` >> sp? >> expr.as(:do_while) >> sp? >> `)` >> (sp? >> `;` | error) |
    `while`.as(:st) >> sp? >> `(` >> sp? >> expr.as(:while) >> sp? >> `)` >> sp? >> statement.as(:code) |
    `for`.as(:st) >> sp? >> `(` >> sp? >> (expr_no_in >> sp?).maybe.as(:init) >> `;` >> sp? >> (expr >> sp?).maybe.as(:test) >> `;` >> sp? >> (expr >> sp?).maybe.as(:counter) >> `)` >> sp? >> statement.as(:code) |
    `for`.as(:st) >> sp? >> `(` >> sp? >> (`var`.as(:st) >> sp >> variable_declaration_list_no_in.as(:vars)).as(:init) >> sp? >> `;` >> sp? >> (expr >> sp?).maybe.as(:test) >> `;` >> sp? >> (expr >> sp?).maybe.as(:counter) >> `)` >> sp? >> statement.as(:code) |
    `for`.as(:st) >> sp? >> `(` >> sp? >> (left_hand_side_expr.as(:left) >> sp >> `in` >> sp >> (expr >> sp?).maybe.as(:right)).as(:for_in) >> `)` >> sp? >> statement.as(:code) |
    `for`.as(:st) >> sp? >> `(` >> sp? >> ((`var`.as(:st) >> sp >> ident.as(:var)).as(:vars) >> sp >> `in` >> sp >> (expr >> sp?).maybe.as(:right)).as(:for_in) >> `)` >> sp? >> statement.as(:code) |
    `for`.as(:st) >> sp? >> `(` >> sp? >> ((`var`.as(:st) >> sp >> ident.as(:var) >> sp? >> `=` >> sp? >> assignment_expr_no_in.as(:expr)).as(:vars) >> sp >> `in` >> sp >> (expr >> sp?).maybe.as(:right)).as(:for_in) >> `)` >> sp? >> statement.as(:code)
  end

  rule(:continue_statement) do
    `continue`.as(:st) >> (sp >> ident).maybe.as(:continue) >> (sp? >> `;` | error)
  end
  rule(:break_statement) do
    `break`.as(:st) >> (sp >> ident).maybe.as(:break) >> (sp? >> `;` | error)
  end
  rule(:return_statement) do
    `return`.as(:st) >> (sp? >> expr).maybe.as(:return) >> (sp? >> `;` | error)
  end

  rule(:with_statement) do
    `with` >> sp? >> `(` >> sp? >> expr.as(:with_expr) >> sp? >> `)` >> sp? >> statement
  end

  rule(:switch_statement) do
    (`switch`.as(:st) >> sp? >> `(` >> sp? >> expr.as(:switch) >> sp? >> `)` >> sp? >> case_block.as(:cases)).as(:switch_statement)
  end

  rule(:case_block) do
    `{` >> sp? >> case_clause.repeat >> (default_clause >> case_clause.repeat).maybe >> `}`
  end
  rule(:case_clause) do
    `case`.as(:st) >> sp? >> expr.as(:case) >> sp? >> `:` >> sp? >> source_elements.as(:code) >> sp?
  end
  rule(:default_clause) do
    `default`.as(:default) >> sp? >> `:` >> sp? >> source_elements.as(:code) >> sp?
  end

  rule(:labelled_statement) do
    ident.as(:label) >> sp? >> `:` >> sp? >> statement.as(:labelled)
  end

  rule(:throw_statement) do
    `throw`.as(:st) >> sp? >> expr.as(:throw) >> (sp? >> `;` | error)
  end

  rule(:try_statement) do
    `try`.as(:st) >> sp? >> block.as(:try) >> sp? >> (
      `finally` >> sp? >> block.as(:finally) |
      `catch` >> sp? >> `(` >> sp? >> ident.as(:catch_var) >> sp? >> `)` >> sp? >> block.as(:catch) >> (sp? >> `finally` >> sp? >> block).maybe.as(:finally)
    )
  end

  rule(:function_declaration) do
    `function`.as(:st) >> sp >> ident.as(:name) >> sp? >> `(` >> sp? >> (formal_parameter_list >> sp?).maybe.as(:args) >> `)` >> sp? >> `{` >> sp? >> function_body.as(:body) >> sp? >> `}`
  end
  rule(:function_expr) do
    `function`.as(:st) >> (sp >> ident).maybe.as(:name) >> sp? >> `(` >> sp? >> (formal_parameter_list >> sp?).maybe.as(:args) >> `)` >> sp? >> `{` >> sp? >> function_body.as(:body) >> sp? >> `}`
  end

  rule(:formal_parameter_list) do
    ident.as(:first) >> (sp? >> `,` >> sp? >> ident).repeat.as(:rest)
  end

  rule(:function_body) do
    source_elements
  end


  rule(:string) do
    (
      `"` >> (`\\` >> any | match(%([^"\]))).repeat >> `"` |
      `'` >> (`\\` >> any | match(%([^'\]))).repeat >> `'`
    ).as(:string)
  end

  rule(:number) do
    float.as(:float) | integer.as(:integer)
  end
  rule(:float) do
    digit.repeat(1) >> `.` >> digit.repeat >> (match['eE'] >> match['-+'].maybe >> digit.repeat(1)).maybe |
    digit.repeat(1) >> (`.` >> digit.repeat).maybe >> match['eE'] >> match['-+'].maybe >> digit.repeat(1) |
    `.` >> digit.repeat(1) >> (match['eE'] >> match['-+'].maybe >> digit.repeat(1)).maybe
  end
  rule(:integer) do
    `0` >> (match['xX'] >> match['0-9a-fA-F'].repeat(1) | match['0-7'].repeat) | digit.repeat(1)
  end
  rule(:digit) do
    match['0-9']
  end

  rule(:regexp) do
    `/` >> (
      match['^\[\/'].repeat(1) |
      `\\` >> any |
      `[` >> `^`.maybe >> `]`.maybe >> (match['^\]'].repeat(1) | `\\` >> any).repeat >> `]`
    ).repeat.as(:regexp) >> `/` >> match['gim'].repeat.as(:flags)
  end

  rule(:ident) do
    (
      (reserved >> match['A-Za-z0-9_$'].absnt?).absnt? >>
      match['A-Za-z_$'] >> match['A-Za-z0-9_$'].repeat
    ).as(:ident)
  end

  RESERVED_WORDS = %w(
    break case catch const continue default delete do else false finally
    for function if in instanceof new null return switch this throw true
    try typeof var void while with
  )
  rule(:reserved) do
    RESERVED_WORDS.map {|w| str(w) }.inject {|l,r| l | r }
  end

  rule(:error) do
    match("[ \t]").repeat >> (`}`.prsnt? | match("[\r\n]") | eof)
  end

  rule(:eof) do
    any.absnt?
  end

  rule(:sp) do
    match("[ \t\r\n]").repeat(1) |
    `//` >> match("[^\r\n]").repeat |
    `/*` >> (`*/`.absnt? >> any).repeat >> `*/`
  end
  rule(:sp?) { sp.repeat }
end

parser = Cparser.new
#pp parser.vector.parse('Vector.<Vector.<Character>>')

string = File.read(ARGV[0])

pp parser.parse_with_debug(string)

