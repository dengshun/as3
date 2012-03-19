module As3
  module Common
    include Parslet

    rule :literal do
      (`null` | `true` | `false` | `undefined` | number | string).as(:literal)
    end

    rule(:string) do
      (
        `"` >> (`\\` >> any.as(:any) | match(%([^"\]))).as(:s).repeat >> `"` |
        `'` >> (`\\` >> any.as(:any) | match(%([^'\]))).as(:s).repeat >> `'`
      ).as(:string)
    end

    rule :ident do
      (
        (reserved >> match['A-Za-z0-9_*'].absnt?).absnt? >>
          match['A-Za-z_*@'] >> match['A-Za-z0-9_*@'].repeat
      ).as(:ident)
    end

    RESERVED_WORDS = %w(chris ochs)
    RESERVED_WORDS2 = %w(as break case catch class const continue default delete do else extends finally for function if implements import in
    instanceof interface internal is native new package private protected public return super switch throw to try typeof use var
    void while with each get set include dynamic final native override static abstract byte cast debugger double enum export
    float goto intrinsic long prototype short synchronized throws to transient virtual volatile
    )
    rule(:reserved) do
      RESERVED_WORDS.map { |w| str(w) }.inject { |l, r| l | r }
    end

    VISIBILITY = %w(
    public private dynamic protected internal
    )
    rule :visibility do
      VISIBILITY.map { |w| str(w) }.inject { |l, r| l | r }
    end

    rule(:number) do
      float.as(:float) | integer.as(:integer)
    end
    rule(:float) do
      digit.repeat(1) >> `.` >> digit.repeat >> (match['eE'] >> match['-+'].maybe >> digit.repeat(1)).maybe |
      digit.repeat(1) >> (`.` >> digit.repeat).maybe >> match['eE'] >> match['-+'].maybe >> digit.repeat(1) |
      match['-+'].maybe >> `.` >> digit.repeat(1) >> (match['eE'] >> match['-+'].maybe >> digit.repeat(1)).maybe
    end

    rule(:integer) do
      `0` >> (match['xX'] >> match['0-9a-fA-F'].repeat(1) | match['0-7'].repeat) | digit.repeat(1)
    end

    rule(:digit) do
      match['-+'].maybe >> match['0-9']
    end

    rule(:eof) do
      any.absnt?
    end

    rule(:error) do
      match("[ \t]").repeat >> (`}`.prsnt? | match("[\r\n]") | eof)
    end

    rule(:space) {
      (match('\s').repeat(1)).as(:space)
    }
    rule(:space?) {
      space.maybe
    }

    rule(:regexp) do
      `/` >> (
        match['^\[\/'].repeat(1) |
        `\\` >> any |
        `[` >> `^`.maybe >> `]`.maybe >> (match['^\]'].repeat(1) | `\\` >> any).repeat >> `]`
      ).repeat.as(:regexp) >> `/` >> match['gim'].repeat.as(:flags)
    end
  
    rule(:sp) do
      (match("[ \t\r\n]").as(:s).repeat(1) |
        `//` >> match("[^\r\n]").as(:s).repeat |
        `/*` >> (`*/`.absnt? >> any.as(:any)).repeat >> `*/`).as(:sp)
    end
    rule(:sp?) { sp.repeat }

    rule :comparison_operator do
      (`*` | `/` | `%` | `<=` | `<` | `>=` | `>` | `===` | `==` | `!==` | `!=`).as(:cop)
    end
    
    rule(:assignment_operator) do
      (str('=') >> `=`.absnt? |
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
      `%=`).as(:aop)
    end
  end
end