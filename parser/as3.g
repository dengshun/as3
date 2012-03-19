/*
License:
  Currently there's no license restriction.You could use,modify it as you like.:)

*/
/*
@Author He.Ye (email:heyesh@cn.ibm.com)

Known Issue that is incompatible with Ecma-262(ECMAScript3 Specification)
1.[Lexer rule]RegularExpressionFirstChar must NOT be > , to avoid the consusable with XML Literal />

Known Issue that is incompatible with Ecma-357(ECMAScript for XML (E4X) Specification)
1. XMLName Lexer rule follows Ecma-262 Identifier rule (BUT can be a Reserved Word)

November 2008: Ernest Pasour - patched to add 'void' type as a valid function return type.
                             - interleaved helper code into grammar for purposes of supporting format/indent tool.
                             - changed memberExpression, callExpression and several others to use code from another grammar that handles function calls correctly.
                             - added ability to parse namespaces (double colon) in the code. ex. mOutputArea.mx_internal::getTextField();
                             - added support for binding declarations. ex. [Exclude(name="horizontalScrollBarStyleName", kind="style")]
                                                                           [IconFile("Accordion.png")]
                                                                           [RequiresDataBinding(true)]
                             - added support for include directives
                             - added support for 'is' operator
                             - added support for '.*' in imports
                             - added support of 'as' operator
                             - added 'use namespace' directive
                             - added default xml namespace directive
                             - fixed implements to take a typeList instead of just a single type
                             - fixed formalParameterList to allow a single parameter that is an ellipsis
                             - added fileContents rule to allow a package declaration plus any combination of classes/interfaces/statements/directives afterward (i.e. outside the package)
                             	-I think this is the change that forced me to add -Xmx512m on the command line to prevent JDK OutOfMemoryError while processing the file.
                             - fixed identifierLiteral to allow keywords that aren't reserved
                             - fixed to allow xml attribute to allow any keyword to be used as an attribute name
                             - added support for xml attribute expressions ( ex. x.y.(@name=="abc").length()); )
                             - changed code that handles virtual semicolon to do lookahead for EOL/LineComment/MLComment instead of promoting token from non-hidden to hidden, which causes problems with the parser prediction phase
                             - fixed to allow trailing commas in array specifier, since that seems to be legal
January 2009				 - fixed to allow type specifier on ellipsis parameter.  Ex. override flash_proxy function callProperty(name:*, ... args:Array):*
February 2009				 - removed MUL_ASSIGN because of ambiguity with '*' type: ex. var x:*=2;
March 2009                   - added support for double negation ex. !!true or ~~true
                             - added support for conditional compiler code (ex. Config::debug {})
April 2009                   - added missing operators &&= and ||=
                             - added support for nested Vector declarations.  (ex. var nssets:Vector.<Vector.<String>> = new Vector.<Vector.<String>>(n+1);)
May 2009					 - fixed e4x to handle tagnames/attributes with hyphens/dots/colons (ex. <array-table></array-table>
							 - fixed e4x to allow var layers:XMLList = xmlData..ns::g.(@inkscape::groupmode =="layer");
June 2009                    - added support for methods named "get" and "set".  I didn't think it was legal, but it appears to be.  This makes the grammar a little ambiguous, but it seems to work.
August 2009                  - added support for e4x attr names that are variable expressions.  Ex. <foo {attr}="value"/>
                             - added support for conditional blocks at the member level.  Ex. around a function or variable.  Grammar changes for packageElement and mxmlEmbedded, to support both AS classes and AS code fragments embedded within mxml.
October 2009                 - added support for using namespace to access members  Ex. mx_internal::functionCall(true);
December 2009				 - fixed classBodyElement and interfaceElement to handle conditional blocks around their elements
                             - reordered labelledStatement, emptyStatement, and expression statement to be at end of statement rule so
                             	    that all the items with keyword lookahead get processed first.  There were some issues with labelled
                             	    statements that just started cropping up when I made minor changes.
                             - fixed findVirtualTokens to kick out early if the current token is one of the handled tokens (;, EOF, }) rather
                                    than performing the search for a virtual semicolon regardless.
                             - changed to require a VAR keyword before decl in for initializer.  Grammar was ambiguous before.
                             - removed enumeration of particular string escape sequences because the compiler does "the right thing" under the covers.
                             - changed UNDERSCORE and DOLLAR to fragments because they are legal by themselves as identifiers, but the lexer was treating them as a top level token instead of part of the IDENTIFIER rule
January 2010                 - added -/+ to numeric literal for bindable arguments.  The parse didn't fail, but the item wasn't treated as a metadata tag.
July 2010                    - fixed metatags to allow keywords to be used as attributes (ex. [Inspectable(category="Style", default="1")] )
August 2010                  - fixed Vector to allow array initializer. ex. var v:Vector.<int>=new < int > [1, 2, 3];
September 2010				 - added support for Vector.<*>
                             - added support for (sharedDataViz.dataKind)::entitySortField
November 2010                - added support for metatag with scoped identifiers (ex. [MessageHandler(selector=MessageChannel.PNL)])
							 - added handling for non-breaking space char (00a0), which is apparently legal in actionscript files
							 - added ability to handle regular expressions containing '>'.  Ex. />abc/g
March 2011                   - nwo allow metatags that start with @ (ex. @Embed).  Not sure if this is really legal or not.

Currently building with Antlr 3.1.1

*/
grammar ASCollector;
options
{
    backtrack=true;
    memoize=true;
    output=AST;
    //TokenLabelType=ASCommonToken;
    //ASTLabelType=ASCommonTree;
}

tokens{
    AS          =   'as';
    BREAK       =   'break';
    CASE        =   'case';
    CATCH       =   'catch';
    CLASS       =   'class';
    CONST       =   'const';
    CONTINUE    =   'continue';
    DEFAULT     =   'default';
    DELETE      =   'delete';
    DO          =   'do';
    ELSE        =   'else';
    EXTENDS     =   'extends';
    FALSE       =   'false';
    FINALLY     =   'finally';
    FOR         =   'for';
    FUNCTION    =   'function';
    IF          =   'if';
    IMPLEMENTS  =   'implements';
    IMPORT      =   'import';
    IN          =   'in';
    INSTANCEOF  =   'instanceof';
    INTERFACE   =   'interface';
    INTERNAL    =   'internal';
    IS          =   'is';
    NATIVE      =   'native';
    NEW         =   'new';
    NULL        =   'null';
    PACKAGE     =   'package';
    PRIVATE     =   'private';
    PROTECTED   =   'protected';
    PUBLIC      =   'public';
    RETURN      =   'return';
    SUPER       =   'super';
    SWITCH      =   'switch';
    THIS        =   'this';
    THROW       =   'throw';
    TO          =   'to';
    TRUE        =   'true';
    TRY         =   'try';
    TYPEOF      =   'typeof';
    USE         =   'use';
    VAR         =   'var';
    VOID        =   'void';
    WHILE       =   'while';
    WITH        =   'with';

    // KEYWORDs but can be identifier
    EACH        =   'each';
    GET         =   'get';
    SET         =   'set';
    NAMESPACE   =   'namespace';
    INCLUDE     =   'include';
    DYNAMIC     =   'dynamic';
    FINAL       =   'final';
    OVERRIDE    =   'override';
    STATIC      =   'static';

    // Future KEYWORDS
    //ABSTRACT    =   'abstract';
    //BOOLEAN     =   'boolean';
    //BYTE        =   'byte';
    //CAST        =   'cast';
    //CHAR        =   'char';
    //DEBUGGER    =   'debugger';
    //DOUBLE      =   'double';
    //ENUM        =   'enum';
    //EXPORT      =   'export';
    //FLOAT       =   'float';
    //GOTO        =   'goto';
    //INTRINSIC   =   'intrinsic';
    //LONG        =   'long';
    //PROTOTYPE   =   'prototype';
    //SHORT       =   'short';
    //SYNCHRONIZED=   'synchronized';
    //THROWS      =   'throws';
    //TO          =   'to';
    //TRANSIENT   =   'transient';
    //TYPE        =   'type';
    //VIRTUAL     =   'virtual';
    //VOLATILE    =   'volatile';

    SEMI        = ';' ;
    LCURLY      = '{' ;
    RCURLY      = '}' ;
    LPAREN      = '(' ;
    RPAREN      = ')' ;
    LBRACK      = '[' ;
    RBRACK      = ']' ;
    DOT         = '.' ;
    COMMA       = ',' ;
    LT          = '<' ;
    GT          = '>' ;
    LTE         = '<=' ;
    GTE; //         = '>=' ;
    EQ          = '==' ;
    NEQ         = '!=' ;
    SAME        = '===' ;
    NSAME       = '!==' ;
    PLUS        = '+' ;
    SUB         = '-' ;
    STAR        = '*' ;
    DIV         = '/' ;
    MOD         = '%' ;
    INC         = '++' ;
    DEC         = '--' ;
    SHL         = '<<' ;
    SHR;//         = '>>' ;
    SHU;//         = '>>>' ;
    AND         = '&' ;
    OR          = '|' ;
    XOR         = '^' ;
    NOT         = '!' ;
    INV         = '~' ;
    LAND        = '&&' ;
    LOR         = '||' ;
    QUE         = '?' ;
    COLON       = ':' ;
    ASSIGN      = '=' ;
//    MUL_ASSIGN  = '*=' ;
    DIV_ASSIGN  = '/=' ;
    MOD_ASSIGN  = '%=' ;
    ADD_ASSIGN  = '+=' ;
    SUB_ASSIGN  = '-=' ;
    SHL_ASSIGN  = '<<=';
    SHR_ASSIGN;//  = '>>=';
    SHU_ASSIGN;//  = '>>>=';
    LAND_ASSIGN = '&&=';
    LOR_ASSIGN  = '||=';
    AND_ASSIGN  = '&=' ;
    XOR_ASSIGN  = '^=' ;
    OR_ASSIGN   = '|=' ;
    ELLIPSIS    = '...';
    XML_ELLIPSIS='..';
    XML_TEND    = '/>';
    XML_E_TEND  = '</';
    XML_NS_OP   = '::';
    XML_AT      = '@';
    XML_LS_STD  = '<>';
    XML_LS_END  = '</>';
}
@header{
package actionscriptinfocollector;
}
@lexer::header{
package actionscriptinfocollector;
import heyesh.app.language.as3.parser.UnicodeUtil;
}
@lexer::members
{
    /**  */
    private Token lastDefaultCnlToken = null;

    // override
    public Token nextToken()
    {
        Token result = super.nextToken();
        if (result!=null && result.getChannel() != ASCollectorParser.CHANNEL_WHITESPACE )
        {
            lastDefaultCnlToken = result;
        }
        return result;
    }

public void reset()
{
	super.reset(); // reset all recognizer state variables
	if (input instanceof ANTLRStringStream)
	{
		((ANTLRStringStream)input).reset();
	}
}


	//TODO: fix this so that regular expression embedded within xml text will work
    private final boolean isRegularExpression(){
        if(lastDefaultCnlToken!=null){
            switch(lastDefaultCnlToken.getType()){
                case NULL :
                case TRUE :
                case FALSE:
                case THIS :
                case SUPER:
                case IDENTIFIER:
                case HEX_NUMBER_LITERAL:
                case DEC_NUMBER_LITERAL:
                case SINGLE_QUOTE_LITERAL:
                case DOUBLE_QUOTE_LITERAL:
                case RCURLY:
                case RBRACK:
                case RPAREN:
                	//this is an attempt to not think something is a regular expression if it happens
                	//to be part of a mathematical expression.
                    return false;
                default:
                    break;
            }
        }

        System.out.println("start to predict if is a RegularExpression");
        // start to predict if the next is a regular expression
        int next = -1;
        int index=1;
        boolean success = false;
        if((next=input.LA(index)) != '/'){
            success = false;
            return success;
        }
        index++;
        // check the first regular character
        next=input.LA(index);
        if(next == '\r' || next == '\n' ||
        	next == '*' || //starts a comment
        	next == '/'  //if no regex content?
        	//|| next == '>' //I think the idea of failing on /> is to prevent conflicts with other tokens, but I think that is irrelevant since I've made this context sensitive.
         	){
            success = false;
            return success;
        }else if(next == '\\'){
            next=input.LA(index+1);
            if(next == '\r' || next == '\n'){
                success=false;
                return success;
            }
            // we omit the escape sequence \ u XXXX or \ x XX
            index++;
        }
        index++;
        // check the body of regular character
        while((next=input.LA(index))!=-1){
            //System.out.println("char["+index+"] = ("+(char)next+")");
            switch(next){
                case '\r':
                case '\n':
                    success = false;
                    return success;
                case '\\':
                    next=input.LA(index+1);
                    if(next == '\r' || next == '\n'){
                        success=false;
                        return success;
                    }
                    // we omit the escape sequence \ u XXXX or \ x XX
                    index++;
                    break;
                case '/':
                    success = true;
                    return success;
            }
            index++;
        }
        return success;
    }

   /**
    * <pre> judge if is a XMLName </pre>
    * @param ch character
    * @return if is a XMLName return true
    */
    static final boolean isXMLText(int ch){
        System.out.println("isXMLText start");
        return (ch!='{'&&ch!='<'&&!(isUnicodeIdentifierPart(ch)));
    }

    /*---------------------------UNICODE_INDENTIFER START------------------------------------------*/
    private static final boolean isUnicodeIdentifierPart(int ch){
        return ch=='$'||ch=='_'||UnicodeUtil.isUnicodeLetter(ch)||UnicodeUtil.isUnicodeDigit(ch)||UnicodeUtil.isUnicodeCombiningMark(ch)||UnicodeUtil.isUnicodeConnectorPunctuation(ch);
    }

    private final void consumeIdentifierUnicodeStart() throws RecognitionException, NoViableAltException{
        int ch = input.LA(1);
        if (UnicodeUtil.isUnicodeLetter(ch) || ch=='$' || ch=='_')
        {
            matchAny();
            do
            {
                ch = input.LA(1);
                if (isUnicodeIdentifierPart(ch))
                {
                    mIDENT_PART();
                }
                else
                {
                    return;
                }
            }
            while (true);
        }
        else
        {
            throw new NoViableAltException();
        }
    }

    /*---------------------------UNICODE_INDENTIFER END------------------------------------------*/
    private final void debugMethod(String methodName,String text){
        System.out.println("recognized as <<"+methodName+">> text=("+text+")");
    }
}
@parser::members{

   		//options
private List<Exception> mParseErrors;
private List<ASCollector> mCreators;
private List<ClassRecord> mClassRecordStack=new ArrayList<ClassRecord>();
private FunctionRecord mCurrentFunction;
private TopLevelItemRecord rec=null;
private CommonTokenStream mRawTokens=null;
private List<MetadataItem> mCachedMetaItems=null;
private boolean mStopStoringBindingDecls=false;
private boolean mSeenConditionalMemberBlock=false;
private int mStatementDepth=0;

public ASCollectorParser(List<ASCollector> collectors, CommonTokenStream tokenStream)
{
	this(tokenStream, new RecognizerSharedState());
	mCreators=collectors;
	mCreators.clear();
	mRawTokens=tokenStream;
	mStatementDepth=0;
}

private void addCollector()
{
	createCollector();
}

private void createCollector()
{
	ASCollector newCollector=new ASCollector();
	mCreators.add(newCollector);
}

private ASCollector getCollector()
{
	if (mCreators.size()==0)
	{
		createCollector();
	}
	return mCreators.get(mCreators.size()-1);
}

public boolean containsConditionalMembers()
{
	return mSeenConditionalMemberBlock;
}

private CommonTokenStream getRawTokens()
{
	return mRawTokens;
}

private void flushMetatags(TopLevelItemRecord element)
{
	if (mCachedMetaItems!=null)
	{
		element.addMetadataItems(mCachedMetaItems);
		mCachedMetaItems=null;
	}
}

private void addMetadataItem(MetadataItem item)
{
	if (mCachedMetaItems==null)
	{
		mCachedMetaItems=new ArrayList<MetadataItem>();
	}

	if (getFunctionRecord()!=null)
		return;

	mCachedMetaItems.add(item);
}

public boolean foundNextLT()
{
   int i=1;
   while (true)
   {
       Token token=input.LT(i);
       if (token.getText()!=null && token.getText().startsWith("<"))
          return (i>1);
       if (token.getType()==EOF)
          return false;
       i++;
   }
}

public void changeTokensUpToNextLT()
{
   int i=1;
   while (true)
   {
       Token t=input.LT(i);
       if (t.getText()!=null && t.getText().startsWith("<"))
          return;
       if (t.getType()==EOF)
          return;
       t.setType(XML_TEXT);

       i++;
   }
}


    public boolean findVirtualHiddenToken(ParserRuleReturnScope retval)
    {
    		//the point of this method is to look for something that can serve as a semicolon.  So a carriage return
    		//or a comment containing a carriage return will fit the bill.
            int index = retval.start.getTokenIndex();
            if(index<0){
                index = input.size();
            }
            else
            {
            	Token lt=input.get(index);
            	if (lt.getType()==EOF || lt.getType()==SEMI || lt.getType()==RCURLY)
            		return false;
            }

/*            //we are on the next regular channel token after the rule.  So we walk backward to determine if between
            //the rule and this token is a single line comment, multiline comment, or new line that can serve as the
            //end token.  If so, then we 'promote' that token by returning it as the 'end' token of the rule (in place
            //of the semi colon).
	        for (int ix = index - 1; ix >= 0; ix--){
	            Token lt = input.get(ix);
	            int type = lt.getType();
	            if(lt.getChannel() == Token.DEFAULT_CHANNEL)
	                break;
	            if (type == EOL || type==COMMENT_SINGLELINE || (type == COMMENT_MULTILINE && lt.getText().matches("/.*\r\n|\r|\n")))
	            {
	            	retval.start=lt;
	                return true;
	            }
	        }*/


            //the token index is pointing to the next default channel token, which is not what we want.
            //We want to walk backward to the previous default channel token (first loop), and then walk forward
            //again looking for EOL/comments (2nd loop)
            int ix=index-1;
            for (; ix >= 0; ix--){
                Token lt = input.get(ix);
                if(lt.getChannel() == Token.DEFAULT_CHANNEL)
                    break;
            }

            //walk forward again
            ix++; //to move to next token that's not default channel
            for (;ix<input.size();ix++) //now search for the next "statement ender"
            {
                Token lt = input.get(ix);
                int type = lt.getType();
                if (lt.getChannel() == Token.DEFAULT_CHANNEL)
                    break;
                if (type == EOL || type==COMMENT_SINGLELINE || (type == COMMENT_MULTILINE && lt.getText().matches("/.*\r\n|\r|\n")))
                {
                	retval.start=lt;
                    return true;
                }
            }

            return false;

    }

public void reportError(RecognitionException e)
{
    if (mParseErrors==null)
    	mParseErrors=new ArrayList<Exception>();
    mParseErrors.add(e);
    super.reportError(e);
}

public List<Exception> getParseErrors()
{
    return mParseErrors;
}

    public static final int CHANNEL_SLCOMMENT=43;
    public static final int CHANNEL_MLCOMMENT=42;
    public static final int CHANNEL_WHITESPACE=41;
    public static final int CHANNEL_EOL=40;
    private final boolean promoteWhitespace()
    {
    	//find the current lookahead token
        Token lt = input.LT(1);
        int index = lt.getTokenIndex();
        if(index<0){
            index = input.size();
        }

		//walk backward through tokens to see if the previous token is whitespace.
        for (int ix = index - 1; ix >= 0; ix--){
            lt = input.get(ix);
            int channel=lt.getChannel();
            if (channel == CHANNEL_EOL || channel ==  CHANNEL_WHITESPACE){
                return true;
            } else if(channel == Token.DEFAULT_CHANNEL){
                break;
            }
        }
        return false;
    }

    private FunctionRecord getFunctionRecord()
    {
    	return mCurrentFunction;
    }

    private TopLevelItemRecord mCurrentItem;
    private void setCurrentItem(TopLevelItemRecord rec)
    {
    	mCurrentItem=rec;
    }

    private ParserTextHandler mTextHandler;

    private void setTextHandler(ParserTextHandler handler)
    {
    	mTextHandler=handler;
    }

    private ParserTextHandler getTextHandler()
    {
    	return mTextHandler;
    }

    private void clearTextHandler()
    {
    	mTextHandler=null;
    }

    private void setCurrentFunction(FunctionRecord func)
    {
    	mCurrentFunction=func;
    }

    private void createClassRecord()
    {
    	ClassRecord record=new ClassRecord();
    	mClassRecordStack.add(record);
    }

    private void capturePostHiddenTokens(SourceItem item, Token t)
    {
    	item.addPostTokens(AntlrUtilities.getPostHiddenTokens(t, getRawTokens()));
    }

    private void capturePostHiddenTokens(SourceItem item, ParserRuleReturnScope t)
    {
    	item.addPostTokens(AntlrUtilities.getPostHiddenTokens(t, getRawTokens()));
    }

    private void captureHiddenTokens(SourceItem item, Token t)
    {
    	item.addPreTokens(AntlrUtilities.getHiddenTokens(t, getRawTokens(), item instanceof ISourceElement, false));
    }

    private void captureHiddenTokens(SourceItem item, ParserRuleReturnScope t)
    {
    	item.addPreTokens(AntlrUtilities.getHiddenTokens(t, getRawTokens(), item instanceof ISourceElement));
    }

    private void closeClassRecord()
    {
    	if (mClassRecordStack.size()>0)
    	{
    		ClassRecord rec=mClassRecordStack.remove(mClassRecordStack.size()-1);
    		getCollector().addClass(rec);
    	}
    }

    private ClassRecord getClassRecord()
    {
    	if (mClassRecordStack.size()==0)
    		return null;
    	return mClassRecordStack.get(mClassRecordStack.size()-1);
    }


}

// Lexer Helper Rule
fragment UNDERSCORE  : '_';
fragment DOLLAR      : '$';

fragment ALPHABET            :    'a'..'z'|'A'..'Z';

fragment NUMBER              :    '0' .. '9';

fragment HEX_DIGIT           :    ('0' .. '9'|'a'..'f'|'A'..'F') ;

fragment CR                  :    '\r';

fragment LF                  :    '\n';

fragment UNICODE_ESCAPE      :    '\\' 'u' HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT;

//changed to accept any backslash escape because the compiler seems to be very lenient.
fragment ESCAPE_SEQUENCE     :
							//	'\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
                            //     |   UNICODE_ESCAPE
                            	 '\\' '\\'
                            	| '\\' ~('\\')
                                 ;
// Lexer Ignored Rule
EOL
@after{
    debugMethod("EOL",$text);
}
    :    (CR LF
    	| CR
    	| LF)
    { $channel = ASCollectorParser.CHANNEL_EOL; };

WHITESPACE
@after{
    debugMethod("WHITESPACE",$text);
}
    :   (('\u0020'|'\u0009'|'\u000B'|'\u00A0'|'\u000C')|('\u001C'..'\u001F'))+              { $channel = ASCollectorParser.CHANNEL_WHITESPACE; }
    ;

COMMENT_MULTILINE
@after{
    debugMethod("COMMENT_MULTILINE",$text);
}
    :   '/*' ( options {greedy=false;} : . )* '*/'         { $channel = ASCollectorParser.CHANNEL_MLCOMMENT; };

COMMENT_SINGLELINE
@after{
    debugMethod("COMMENT_SINGLELINE",$text);
}
    :   '//' ~( CR | LF )* (CR LF | CR | LF)                          { $channel = ASCollectorParser.CHANNEL_SLCOMMENT; };

// $<StringLiteral

SINGLE_QUOTE_LITERAL
@after{
    debugMethod("SINGLE_QUOTE_LITERAL",$text);
}
    :   '\'' ( ESCAPE_SEQUENCE | ~('\\'|'\'') )* '\'';
DOUBLE_QUOTE_LITERAL
@after{
    debugMethod("DOUBLE_QUOTE_LITERAL",$text);
}
    :   '"'  ( ESCAPE_SEQUENCE | ~('\\'|'"') )* '"';

// $>

// $<RegularExpressionLiteral

REGULAR_EXPR_LITERAL
@after{
    debugMethod("REGULAR_EXPR_LITERAL",$text);
}
    :   {isRegularExpression()}? => DIV REGULAR_EXPR_BODY DIV REGULAR_EXPR_FLAG*
    ;

fragment REGULAR_EXPR_BODY
    :   REGULAR_EXPR_FIRST_CHAR REGULAR_EXPR_CHAR*
    ;

// add > to the cannot be first char list
fragment REGULAR_EXPR_FIRST_CHAR
    :   ~(CR | LF |'*'|'\\'|'/') //|'>')
    |   BACKSLASH_SEQUENCE
    ;

fragment REGULAR_EXPR_CHAR
    :   ~(CR | LF |'\\'|'/')
    |   BACKSLASH_SEQUENCE
    ;

fragment BACKSLASH_SEQUENCE:    '\\' ~(CR | LF);

fragment REGULAR_EXPR_FLAG :    IDENT_PART ;

// $>

// $<NumberLiteral

HEX_NUMBER_LITERAL
@after{
    debugMethod("HEX_NUMBER_LITERAL",$text);
}
    : '0' ('X'|'x') HEX_DIGIT+ ;

fragment DEC_NUMBER          :  NUMBER+ '.' NUMBER* | '.' NUMBER+ | NUMBER+ ;

DEC_NUMBER_LITERAL
@after{
    debugMethod("DEC_NUMBER_LITERAL",$text);
}
    :  DEC_NUMBER EXPONENT? ;

fragment EXPONENT            : ('e'|'E') ('+'|'-')? NUMBER+ ;

// $>

IDENTIFIER
@after{
    debugMethod("Identifier",$text);
}
    :   IDENT_NAME_ASCII_START
    |   UNICODE_ESCAPE+
    |   {consumeIdentifierUnicodeStart();}
    ;

fragment IDENT_NAME_ASCII_START   : IDENT_ASCII_START IDENT_PART*;

fragment IDENT_ASCII_START        : ALPHABET | DOLLAR | UNDERSCORE;

fragment IDENT_PART
@after{
    debugMethod("IDENT_PART",$text);
}
    :   (IDENT_ASCII_START) => IDENT_ASCII_START
    |   NUMBER
    |   {isUnicodeIdentifierPart(input.LA(1))}? {matchAny();}
    ;

XML_COMMENT
@after{
    debugMethod("XML_COMMENT",$text);
}
    :   '<!--' ( options {greedy=false;} : . )* '-->';

XML_CDATA options {k=8;}
@after{
    debugMethod("XML_CDATA",$text);
}
    :   '<![CDATA' ( options {greedy=false;} : . )* ']]>' ;

XML_PI
@after{
    debugMethod("XML_PI",$text);
}
    :   '<?' ( options {greedy=false;} : . )* '?>';

// SourceCharacters but no embedded left-curly { or less-than <
XML_TEXT
@after{
    debugMethod("XMLText",$text);
}
    : '\u0020'..'\u003b'
    | '\u003d'..'\u007a'
    | '\u007c'..'\u007e'
    | {isXMLText(input.LA(1))}?{matchAny();}
    ;


// $<Literal

booleanLiteral                     :   T=TRUE | F=FALSE;

numericLiteral                     :   D=DEC_NUMBER_LITERAL | H=HEX_NUMBER_LITERAL;

stringLiteral                      :   S=SINGLE_QUOTE_LITERAL | D=DOUBLE_QUOTE_LITERAL ;

regularExpresionLiteral            :   R=REGULAR_EXPR_LITERAL ;

identifierLiteral                  :   /*{isNotReservedWord(input.LT(1).getText())}?*/ I=IDENTIFIER | notQuiteReservedWord ;

xmlNameLiteral                     :   (IDENTIFIER | allKeywords) ( {!promoteWhitespace()}?=> (SUB | DOT | COLON) {!promoteWhitespace()}?=> (IDENTIFIER | allKeywords))*
									;

literal                            :   N=NULL  | booleanLiteral | numericLiteral | stringLiteral | regularExpresionLiteral;
// $>

xmlMarkup                          :   xmlComment | xmlCDATA | xmlPI;
xmlComment                         :   x=XML_COMMENT  ;
xmlCDATA                           :   x=XML_CDATA ;
xmlPI                              :   x=XML_PI  ;
xmlExprEval                        :   L=LCURLY  expression R=RCURLY ;


xmlTextElement
    :
		allKeywords {/*TODO: see if I can change token type*/}
    | lexToken=(   DEC_NUMBER_LITERAL
    | 	HEX_NUMBER_LITERAL
    |   SINGLE_QUOTE_LITERAL
    | 	DOUBLE_QUOTE_LITERAL
    |   IDENTIFIER
    |   XML_TEXT  //used to have a '+' on this item
    |   DIV
    | 	SEMI
//    | 	LCURLY //not allowed in xml text
    | 	RCURLY
    | 	LPAREN
    | 	RPAREN
    |	LBRACK
    |	RBRACK
    |	DOT
    |	COMMA
//    |	LT          //not allowed in xml text
    |	GT
    |	LTE
//    |	GTE
    |	EQ
    |	NEQ
    |	SAME
    |	NSAME
    |	PLUS
    |	SUB
    |	STAR
    |	MOD
    |	INC
    |	DEC
    |	SHL
//    |	SHR
//    |	SHU
    |	AND
    |	OR
    |	XOR
    |	NOT
    |	INV
    |	LAND
    |	LOR
    |	QUE
    |	COLON
    |	ASSIGN
//    |	UNDERSCORE
//    |	DOLLAR
//    |	MUL_ASSIGN
    |	DIV_ASSIGN
    |	MOD_ASSIGN
    |	ADD_ASSIGN
    |	SUB_ASSIGN
    |	SHL_ASSIGN
//    |	SHR_ASSIGN
//    |	SHU_ASSIGN
    |	AND_ASSIGN
    |	XOR_ASSIGN
    |	OR_ASSIGN
    |   LOR_ASSIGN
    |   LAND_ASSIGN
    |	ELLIPSIS
    |	XML_ELLIPSIS
    |	XML_NS_OP
    |	XML_AT
//    |	XML_LS_STD
 //   |	XML_LS_END
    )
    {
        lexToken.setType(XML_TEXT);
    }
    ;


xmlText
@after{
    System.out.println("xmlText.text=("+$text+")");
    System.out.println("xmlText after start currentIndex = "+input.index()+"size = "+input.size());
}
    :
//    {foundNextLT()}? => {changeTokensUpToNextLT();}
    (x=XML_TEXT  | xmlTextElement)+ //xmlTextElement+
    ;

// it's a helper rule,should not be a tree.
xmlPrimaryExpression
    :   xmlPropertyIdentifier
    |   xmlInitialiser
    |   xmlListInitialiser
    ;

/*
    XMLPropertyIdentifier can be a primary expression, but also can be a propertySuffixReference
    see example
        :   var xml:XML = <soap:Envelope soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"/>;
            var soapNS:Namespace = message.namespace("soap");
            trace(xml.@soapNS::encodingStyle); //-> it's a propertySuffixReference Call
            with(xml){
                trace(@soapNS::encodingStyle); //-> it's a primaryExpression Call
            }
*/
xmlPropertyIdentifier
      :   xmlAttributeIdentifier
      |   xmlQualifiedIdentifier
      |   s=STAR
      ;

xmlAttributeIdentifier
    :   at=XML_AT
        (
           xmlQualifiedIdentifier
           | xmlPropertySelector
           | indexSuffix
        )
    ;

xmlPropertySelector
    :   xmlNameLiteral
    |   s=STAR
    ;

xmlQualifiedIdentifier
    :   xmlPropertySelector  x=XML_NS_OP
    (
        xmlPropertySelector
        | indexSuffix
    )
    ;

xmlInitialiser
    :   xmlMarkup
    |   xmlElement
    ;

xmlElement
    :


    L=LT  xmlTagName xmlAttributes?
    (
        x=XML_TEND


        |
        G=GT xmlElementContent?
        x=XML_E_TEND
        xmlTagName G=GT
    )

    ;

xmlAttributes
    :   xmlAttribute+
    ;

xmlTagName
    :   xmlExprEval
    |   xmlNameLiteral
    ;

xmlAttribute
    :  {promoteWhitespace()}?  xmlTagName  A=ASSIGN
    (
        xmlExprEval
        | stringLiteral
    )
    ;

xmlElementContent
    :  xmlElementContentHelper+
    ;

xmlElementContentHelper
    : xmlExprEval
    | xmlMarkup
    | xmlElement
    | xmlText
	;


xmlListInitialiser
    :    x=XML_LS_STD

  		xmlElementContent?
  		 x=XML_LS_END
    ;

// semic rule
semic
@init
{
    // Mark current position so we can unconsume a RBRACE.
    int marker = input.mark();
    // Promote EOL if appropriate
    boolean onBrace=false;
    if (retval.start.getText()!=null && retval.start.getText().equals("}"))
    {
    	onBrace=true;
		if (state.backtracking>0)
		{
			retval.stop=retval.start;
		    return retval; //we don't want to consume the '}' during the prediction phase
		}
    }

    if (findVirtualHiddenToken(retval))
    {
       retval.stop=retval.start;
       return retval;
    }
}
    :   S=SEMI
    |   E=EOF
    |   R=RCURLY { input.rewind(marker);
                    if (onBrace)
                    {
                         retval.start=input.LT(-1);
                         retval.stop=retval.start;
                         retval.tree=null;
                         return retval;
                    }
                 }
//    |   C=COMMENT_MULTILINE {emit($C);} // (with EOL in it)
//    |   {isNextTokenHiddenVirtualSemi(retval)}?  E=EOL {emit($E);}
    ;


fileContents
	: (packageDeclaration? packageElement*) | EOF
	;

// $<Package Declaration

packageDeclaration
	:   p=PACKAGE (type)?
	    l=LCURLY {addCollector();getCollector().setPackageOpen($l);}

	    packageElement*
	     r=RCURLY {getCollector().setPackageClose($r);addCollector();}
	;


//this is for actionscript embedded within mxml.  I believe that the semantics are that the code in
//the mx:Script blocks are embedded inside a virtual class declaration, so anything that is normally
//allowed inside a class should be okay.  However, imports are okay too.
mxmlEmbedded
	:
		(conditionalCompilerOption LCURLY mxmlEmbedded RCURLY {mSeenConditionalMemberBlock=true;}
	    	| propertyDeclaration | functionDeclaration[true] | statement | directive | interfaceFunctionDeclaration[true])*
	    EOF?
	;

packageElement
    :
			conditionalCompilerOption LCURLY packageElement* RCURLY {mSeenConditionalMemberBlock=true;}
    		| classOrInterfaceDecl | propertyDeclaration | functionDeclaration[true] | interfaceFunctionDeclaration[true] | directive | statement
    ;

importDeclaration
	:    i=IMPORT  t=type (D=DOT  S=STAR )? s=semic
		{
			ImportRecord iRec=new ImportRecord();
			iRec.captureStartPos(i);
			if (s!=null)
			{
				iRec.captureEndPos(s);
				capturePostHiddenTokens(iRec, s);
			}
			else if (S!=null)
			{
				iRec.captureEndPos(S);
				capturePostHiddenTokens(iRec, S);
			}
			else
			{
				iRec.captureEndPos(t);
				capturePostHiddenTokens(iRec, t);
			}
			iRec.setType(t, S!=null);
			captureHiddenTokens(iRec, i);
			if (getClassRecord()==null)
				getCollector().addImport(iRec);
			else
				getClassRecord().addImport(iRec);
		}
	;

classOrInterfaceDecl
	:
		{createClassRecord();}
		(cond=conditionalDirAndBindingDecls
			{getClassRecord().captureStartPos(cond);}
		)?
		(m=memberModifiers[getClassRecord()]
		 {getClassRecord().captureStartPos(m);}
		 {captureHiddenTokens(getClassRecord(), m);}
		)?
		{flushMetatags(getClassRecord());}
		(i=interfaceDeclaration {getClassRecord().captureEndPos(i);getClassRecord().setIsClass(false);{if (m==null) captureHiddenTokens(getClassRecord(), i);} capturePostHiddenTokens(getClassRecord(), i);}
		 | c=classDeclaration 	{getClassRecord().captureEndPos(c); {if (m==null) captureHiddenTokens(getClassRecord(), c);} capturePostHiddenTokens(getClassRecord(), c); }
		)
	    {closeClassRecord();}

	;

directive
	: (bindingDecl | includeDirective | useNamespaceDirective | i=importDeclaration | defaultXMLNamespaceDirective)
	;

conditionalDirAndBindingDecls
	:

	  conditionalCompilerOption
      {mStopStoringBindingDecls=true;}
	  ( bindingDecl)*
	  {mStopStoringBindingDecls=false;}
	;

xmlKeyword
	: {input.LT(1).getText().equalsIgnoreCase("xml")}? I=IDENTIFIER
	;

conditionalCompilerOption
	:
	identifierLiteral x=XML_NS_OP  identifierLiteral
	;

defaultXMLNamespaceDirective
@init{
	DefaultNamespaceItem item=null;
}
	:
	{item=new DefaultNamespaceItem();}
	D=DEFAULT {item.captureStartPos($D);captureHiddenTokens(item, $D);}
	xmlKeyword
	//namespace
	N=NAMESPACE
	A=ASSIGN  ex=assignmentExpression  {item.setNamespace(ex);} s=semic
	{
		if (s!=null)
		{
			item.captureEndPos(s);
			capturePostHiddenTokens(item, s);
		}
		else
		{
			item.captureEndPos(ex);
			capturePostHiddenTokens(item, ex);
		}

		if (getFunctionRecord()!=null)
		{} //throw away
		else if (getClassRecord()!=null)
		{
			getClassRecord().addDefaultNamespace(item);
		}
		else
		{
			getCollector().addDefaultNamespace(item);
		}
	}
	;

bindingDecl
@init
{
	MetadataItem item=null;
}
	: L=LBRACK
	  {item=new MetadataItem();item.captureStartPos($L);captureHiddenTokens(item, $L);}
		  (XML_AT)? I=IDENTIFIER
		  {item.setBindingType($I);}
		  (L=LPAREN
		     (b1=bindingDeclArg {item.addArg(b1);}
		     	(C=COMMA b2=bindingDeclArg {item.addArg(b2);})*
		     )?

		   R=RPAREN
	       )?
	   R=RBRACK (s=SEMI )?
	   {
	   		if (!mStopStoringBindingDecls)
	   		{
	   			if (s!=null)
	   			{
   					item.captureEndPos(s);
   					capturePostHiddenTokens(item, s);
   				}
   				else
   				{
   					item.captureEndPos($R);
   					capturePostHiddenTokens(item, $R);
   				}

	   			addMetadataItem(item);
	   		}
	   }
	;

includeDirective
	: I=INCLUDE s=stringLiteral sem=semic
	 {
	    if (getFunctionRecord()==null) //make sure this is not inside a function
	    {
	 		IncludeItem item=new IncludeItem();
	 		item.captureStartPos($I);
	 		captureHiddenTokens(item, $I);
	 		item.setIncludeFile(s);
	 		if (getClassRecord()!=null)
	 		{
	 			getClassRecord().addInclude(item);
	 		}
	 		else
	 		{
	 		    getCollector().addInclude(item);
	 		}
	 		if (sem!=null)
	 		{
	 			item.captureEndPos(sem);
	 			capturePostHiddenTokens(item, sem);
	 		}
	 		else
	 		{
	 			item.captureEndPos(s);
	 			capturePostHiddenTokens(item, s);
	 		}
	 	}
	 }
	;

bindingDeclArg
	:
	//TODO: figure out what's actually legal here
//	(I=IDENTIFIER  E=ASSIGN )? expression
//	| I=IDENTIFIER{emit($I);}
//	| T=TRUE {emit($T);}
//	| F=FALSE{emit($F);}
	(eitherIdentifier  E=ASSIGN )?
	(
		stringLiteral | (PLUS | SUB)? numericLiteral | (eitherIdentifier (DOT eitherIdentifier)* )
	)
	;

// $>

// $<Class / Interface Body

interfaceDeclaration
	:   i=INTERFACE
	    		{
  			//TODO: look for existing asdoc comment in the hidden tokens before the 'class' keyword
			ClassRecord rec=getClassRecord();
			rec.captureStartPos(i);
		}

		name=type
		{
			getClassRecord().setName(name);
		}

		(e=EXTENDS  typeList)?
        interfaceBody
	;

interfaceBody
	:   l=LCURLY
	    {
	    	getClassRecord().setBodyStart($l);
	    }
	    interfaceElement*

	    r=RCURLY
	    {getClassRecord().setBodyEnd($r);}
	;

classDeclaration
	:
		c=CLASS
  		{
  			//TODO: look for existing asdoc comment in the hidden tokens before the 'class' keyword
			ClassRecord rec=getClassRecord();
			rec.captureStartPos(c);
		}
		name=type
		{
			getClassRecord().setName(name);
		}
		( E=EXTENDS  superclass=type
			{
				getClassRecord().setExtends(superclass);
			}
		)?
		(
			I=IMPLEMENTS {setTextHandler(getClassRecord().getImplementsHandler());} implemented=typeList {clearTextHandler();}
		)?
        classBody
    ;



classBody
	:   L=LCURLY
	    {
	    	getClassRecord().setBodyStart($L);
	    }

		classBodyElement*

		R=RCURLY {getClassRecord().setBodyEnd($R);}
	;

// $>

// $<Class/Interface Element

classBodyElement
    :   (conditionalCompilerOption LCURLY)=>conditionalCompilerOption LCURLY classBodyElement* RCURLY {mSeenConditionalMemberBlock=true;}
    	| propertyDeclaration | functionDeclaration[true] | directive | statement
	;

interfaceElement
    :   (conditionalCompilerOption LCURLY)=>conditionalCompilerOption LCURLY interfaceElement* RCURLY {mSeenConditionalMemberBlock=true;}
    	| propertyDeclaration | interfaceFunctionDeclaration[true] | directive | statement
    ;

// $>



// $<InterfaceFunction Declaration

interfaceFunctionDeclaration[boolean store]
@init
{
	FunctionRecord func=null;
	int startPos=(-1);
	int endPos=(-1);
}
    :
    	{func=new FunctionRecord();
    	 if (store)
    	 {
    	 	setCurrentFunction(func);
    	 	flushMetatags(func);
    	 }
    	}
        (c=conditionalDirAndBindingDecls
           {func.captureStartPos(c);}
        )?
    	(m=memberModifiers[func]
    		{func.captureStartPos(m);}
    	)?
    	F=FUNCTION
        {
         	func.captureStartPos($F);
         	if (c!=null)
         		captureHiddenTokens(func, c);
         	else if (m!=null)
         		captureHiddenTokens(func, m);
    	    else
    		    captureHiddenTokens(func, $F);
        }
    (   S=SET {func.setType(FunctionRecord.Type_Setter);}
      | G=GET {func.setType(FunctionRecord.Type_Getter);}
    )?
    (   I=IDENTIFIER {func.setName($I);}
      | nq=notQuiteReservedWord {func.setName(nq);}
    )
    f=formalParameterList[func]
    (C=COLON  t=type {func.setReturnType(t);})?
    s=semic
    {
    	if (s!=null)
    	{
    		func.captureEndPos(s);
    		capturePostHiddenTokens(func, s);
    	}
    	else if (t!=null)
    	{
    		func.captureEndPos(t);
    		capturePostHiddenTokens(func, t);
    	}
    	else
    	{
    	    func.captureEndPos(f);
    	    capturePostHiddenTokens(func, f);
    	}
    }
    {
    	if (store)
    	{
    		if (getClassRecord()!=null)
    		{
    			getClassRecord().addFunctionRecord(func);
    		}
    		else
    		{
    			getCollector().addFunctionRecord(func);
    		}
    	}
    	setCurrentFunction(null);
    }
    ;

// $>

// $<Property Declaration

propertyDeclaration
@init
{
	PropertyLine rec=null;
}
	:
		{rec=new PropertyLine();}
		{flushMetatags(rec);}

		(c=conditionalDirAndBindingDecls
			{rec.captureStartPos(c);
			 captureHiddenTokens(rec, c);
			}
		)?

		(m=memberModifiers[rec]
			{rec.captureStartPos(m);
			 if (c==null)
			    captureHiddenTokens(rec, m);
			}
		)?

		 (v=variableStatement[rec]
		  {rec.capturePositions(v); capturePostHiddenTokens(rec, v);
		   if (c==null && m==null)
		   		captureHiddenTokens(rec, v);
		  }
		| constVar=constantVarStatement[rec]
		  {rec.capturePositions(constVar); capturePostHiddenTokens(rec, constVar);
		   if (c==null && m==null)
		   		captureHiddenTokens(rec, constVar);
		  }
		| ns=namespaceDirective[rec]
		  {rec.capturePositions(ns); rec.setIsNamespace(true); capturePostHiddenTokens(rec, ns);
  		   if (c==null && m==null)
		   		captureHiddenTokens(rec, ns);
		  }
		)
		{
			if (getClassRecord()!=null)
			{
				if (ns!=null)
					getClassRecord().addNamespace(rec);
				else
					getClassRecord().addProperty(rec);
			}
			else
			{
				if (ns!=null)
					getCollector().addDefinedNamespace(rec);
				else
					getCollector().addPropertyRecord(rec);
			}
		}

	;

// $>

// $<Function Definition (13)

functionDeclaration[boolean store]
@init
{
	FunctionRecord func=null;
	int startPos=(-1);
	int endPos=(-1);
}
    :
       {func=new FunctionRecord();
        if (store)
        {
        	setCurrentFunction(func);
        	{flushMetatags(func);}
        }
       }
        (c=conditionalDirAndBindingDecls
            {func.captureStartPos(c);}
          )?
    (m=memberModifiers[func]
      {func.captureStartPos(m);}
    )?

    key=FUNCTION
    {
    	func.captureStartPos($key);
    	if (c!=null)
    		captureHiddenTokens(func, c);
    	else if (m!=null)
    		captureHiddenTokens(func, m);
    	else
    		captureHiddenTokens(func, $key);
    }

    (
	    (SET {func.setType(FunctionRecord.Type_Setter);}
	    	|GET {func.setType(FunctionRecord.Type_Getter);}
	    )
    )?
    (   I=IDENTIFIER {func.setName($I);}
      | nq=notQuiteReservedWord {func.setName(nq);}
    )
    formalParameterList[func]
    (C=COLON  t=type {func.setReturnType(t);})?
    body=functionBody
    {
     	func.captureEndPos(body);
     	capturePostHiddenTokens(func, body);
    	if (store)
    	{
    		if (getClassRecord()!=null)
    		{
    			getClassRecord().addFunctionRecord(func);
    		}
    		else
    		{
    			getCollector().addFunctionRecord(func);
    		}
    		setCurrentFunction(null);
    	}
    }
    ;

functionExpression
		//pop the indent to remove the lazy indent that is added by the surrounding expression.  Then add an indent
		//back at the end so that when the surrounding expression pops it will leave the correct number of indents.  Yuck.
    :   F=FUNCTION  (I=IDENTIFIER)? formalParameterList[null] (C=COLON  type)?  functionBody

    ;

formalParameterList[DeclHolder holder]
    :

    	L=LPAREN
        ( (  variableDeclaration[holder]
            (
               C=COMMA

               variableDeclaration[holder]
            )*
            (  C=COMMA   formalEllipsisParameter[holder])?
           )
           |  formalEllipsisParameter[holder]
        )?
        R=RPAREN


    ;

formalEllipsisParameter[DeclHolder holder]
    :   E=ELLIPSIS   variableIdentifierDecl[holder]
    ;

functionBody
    :   L=LCURLY

    		(statement|functionDeclaration[false])*
    	R=RCURLY
    ;

// $>

// $<Member Modifiers

memberModifiers[TopLevelItemRecord rec]
    :
//    {setCurrentItem(record);}
    (memberModifier[rec])+
//    {setCurrentItem(null);}
    ;

memberModifier[TopLevelItemRecord rec]
    :   x=(
        DYNAMIC
    |   FINAL
    |   INTERNAL
    |   NATIVE
    |   OVERRIDE
    |   PRIVATE
    |   PROTECTED
    |   PUBLIC
    |   STATIC
    |   IDENTIFIER //this is to handle the case of namespaces, which apparently don't have to be before other modifiers
    )

    {
    	if (rec!=null)
    	{
    		TextItem newItem=rec.addModifier($x);
    		captureHiddenTokens(newItem, $x);
    		newItem.trimLeadingWhitespaceTokens();
    	}

    }
    ;

// $>


// statement

// $<Statement

statement
    :
    {mStatementDepth++;}
    (	blockStatement
    |   directive
    |   namespaceDirective[null]
    |    constantVarStatement[null]
    |   tryStatement
    |   switchStatement
    |   withStatement
    |     returnStatement
    |     breakStatement
    |     continueStatement
    |   forStatement
    |   forInStatement
    |   forEachInStatement
    |   doWhileStatement
    |   whileStatement
    |   ifStatement
    |     variableStatement[null]
    |     throwStatement
    |   labelledStatement
    |    expression semic
    |   emptyStatement
    )
    {mStatementDepth--;}
    ;

// $>


// $<Block Statement

blockStatement
@init{
	StaticInitializerRecord item=null;
	boolean freestandingBlock=false;
}
    :   {item=new StaticInitializerRecord();}
		//{flushMetatags(item);}
    	(c=conditionalCompilerOption)? L=LCURLY
    	 {freestandingBlock=getFunctionRecord()==null && getClassRecord()!=null && mStatementDepth==1;}
    	statement*
    	R=RCURLY

    	{
    		if (freestandingBlock)
    		{
    			if (c!=null)
    			{
					item.captureStartPos(c);
			 		captureHiddenTokens(item, c);
				}

    			item.captureStartPos($L);
    			item.captureEndPos($R);
   				//this is a static initializer, so add it to the list of static initializers
   				getClassRecord().addStaticInitializer(item);
    		}

    	}
    ;

// $>

throwStatement
	:  T=THROW  e=expression
		{
			FunctionRecord rec=getFunctionRecord();
			if (rec!=null)
				rec.addThrowsExpression(e);
		}
	semic
	;

// $<Constant Var Statement

constantVarStatement[PropertyLine rec]
    :   C=CONST
//    	{
//    		if (rec!=null)
//    			rec.captureStartPos($C);
//    	}
    {
    	if (rec!=null)
    	{
    		rec.setConst(true);
    	}
    }

      vdl=variableDeclarationList[rec] (S=SEMI)?


//      {
//      	if (rec!=null)
//      	{
//      		if (S!=null)
//      			rec.captureEndPos($S);
//      		else
//      			rec.captureEndPos(vdl);
//      	}
//      }
    ;
// $>


useNamespaceDirective
@init{
	UseNamespaceItem item=null;
}
	:
	{item=new UseNamespaceItem();}
	U=USE
	{item.captureStartPos($U);captureHiddenTokens(item, $U);}
	N=NAMESPACE
	q1=qualifiedIdentifier {item.addNamespace(q1);}
	(C=COMMA  q2=qualifiedIdentifier {item.addNamespace(q2);} )* s=semic
	{
		if (s!=null)
		{
			item.captureEndPos(s);
			capturePostHiddenTokens(item, s);
		}
		else if (q2!=null)
		{
			item.captureEndPos(q2);
			capturePostHiddenTokens(item, q2);
		}
		else
		{
			item.captureEndPos(q1);
			capturePostHiddenTokens(item, q1);
		}

		if (getFunctionRecord()!=null)
		{
			//don't keep if inside function
		}
		else if (getClassRecord()!=null)
		{
			getClassRecord().addUseNamespace(item);
		}
		else
		{
			getCollector().addUseNamespace(item);
		}
	}
	;
// $<UseNamespace Statement

// $<Namespace Directive


namespaceDirective[PropertyLine rec]
    :
    N=NAMESPACE
    q=qualifiedIdentifier
    ( A=ASSIGN   s=stringLiteral )? semic
    {
    	if (rec!=null)
    	{
			DeclRecord decl=new DeclRecord(q, s);
			rec.addDecl(decl);
		}
    }
    ;

// $>


// $<Try Statement(12.14)

tryStatement
    :  T=TRY   blockStatement
        ( catchClause+ finallyClause
        | catchClause+
        | finallyClause
        )
    ;

catchClause
    :  C=CATCH  L=LPAREN  variableIdentifierDecl[null] R=RPAREN  blockStatement
    ;

finallyClause
    :  F=FINALLY  blockStatement
    ;

// $>

// $<Labelled Statement(12.12)

labelledStatement
    :  I=IDENTIFIER
    	C=COLON

    	statement

    ;

// $>

// $<switch Statement(12.11)

switchStatement
    :   S=SWITCH  parExpression
    	L=LCURLY

    	switchBlockStatementGroup*
    	R=RCURLY
    ;

// The change here (switchLabel -> switchLabel+) technically makes this grammar
//   ambiguous; but with appropriately greedy parsing it yields the most
 //  appropriate AST, one in which each group, except possibly the last one, has
 //  labels and statements.
switchBlockStatementGroup
    :    switchLabel  statement*  breakStatement?
    ;

switchLabel
    :   C=CASE  expression C=COLON

    |   D=DEFAULT  C=COLON

    ;

// $>

// $<With statement(12.10)

withStatement
    :   W=WITH   L=LPAREN   expression  R=RPAREN    statement
    ;

// $>

// $<Return statment (12.9)

returnStatement
    :   R=RETURN  (  expression)? semic
    ;

// $>


// $<Break statement (12.8)

breakStatement
    :   B=BREAK     (I=IDENTIFIER)? semic
    ;

// $>


// $<Continue statement (12.7)

continueStatement
    :   C=CONTINUE  (I=IDENTIFIER)? semic
    ;

// $>


// $<For statement 12.6

forStatement
    :   F=FOR   L=LPAREN  forControl R=RPAREN  statement
    ;

forInStatement
    :   F=FOR   L=LPAREN  forInControl R=RPAREN    statement
    ;

forEachInStatement
    :   F=FOR
     //   each
    E=EACH
    L=LPAREN  forInControl R=RPAREN  statement
	;
forControl
options {k=3;} // be efficient for common case: for (ID ID : ID) ...
    :   forInit?  semic   expression? semic  forUpdate?
    ;

forInControl
options {k=3;} // be efficient for common case: for (ID ID : ID) ...
    :   forInDecl I=IN  expression
    ;

forInDecl
    :   leftHandSideExpression
    |   V=VAR  variableDeclarationNoIn
    ;

forInit
    :   V=VAR variableDeclarationNoInList
    |   expressionNoIn
    ;

forUpdate
    :   expression
    ;

// $>


// $<While statement (12.5)

doWhileStatement
    :   D=DO   statement   W=WHILE  parExpression semic (S=SEMI)?
    ;

// $>

// $<While statement (12.5)

whileStatement
    :   W=WHILE  parExpression   statement
    ;

// $>



// $<If statement (12.5)

ifStatement
    :

         I=IF

         parExpression


         statement


         (options {k=1;}:E=ELSE


	           statement )?


    ;

// $>


// $<Empty statement (12.3)

emptyStatement
    :     S=SEMI
    ;

// $>


// $<Variable statement 12.2)

variableStatement [PropertyLine prop]
    :
        (I=IDENTIFIER )? V=VAR
//        	{
//        		if (prop!=null)
//        		{
//        			if (I!=null)
//        				prop.captureStartPos($I);
//        			prop.captureStartPos($V);
//        		}
//        	}
          lastTree=variableDeclaration[prop] ( C=COMMA  lastTree=variableDeclaration[prop] )* s=semic
//        {
//        	if (prop!=null)
//        	{
//        		if (s!=null)
//        			prop.captureEndPos(s);
//        		else
//        			prop.captureEndPos(lastTree);
//        	}
//        }


    ;

variableDeclarationList[DeclHolder holder]
    :     variableDeclaration[holder] (  C=COMMA  variableDeclaration[holder])*
    ;

variableDeclarationNoInList
    :    variableDeclarationNoIn (  C=COMMA  variableDeclarationNoIn)*
    ;

variableDeclaration[DeclHolder prop]
    :   d=variableIdentifierDecl[prop]
    	( A=ASSIGN val=assignmentExpression )?
    	{
    		if (prop!=null)
    		{
//    			if (val!=null)
  //  				prop.captureEndPos(val);
    //			else
    	//			prop.captureEndPos(d);
    		}
    	}

    ;

variableDeclarationNoIn
    :    variableIdentifierDecl[null] ( A=ASSIGN  assignmentExpressionNoIn )?
    ;


variableIdentifierDecl[DeclHolder holder]
    :    id=identifierLiteral ( C=COLON  t=type )?
    	{
			if (holder!=null)
			{
				DeclRecord rec=new DeclRecord(id, t);
				holder.addDecl(rec);
			}

    	}
    ;
// $>

// $<Type / Type List

type:   qualifiedName | S=STAR  | V=VOID  ;

typeList
    :   t1=type
     	{
     		if (getTextHandler()!=null)
     			getTextHandler().addItem(t1);
     	}
       (C=COMMA t2=type
     	{
     		if (getTextHandler()!=null)
     			getTextHandler().addItem(t2);
     	}

       )*
    ;
// $>

standardQualifiedName
	:
	typeSpecifier (D=DOT  typeSpecifier )*
//	(I=IDENTIFIER  ) (D=DOT  (I=IDENTIFIER ) )*
	;

qualifiedName
    :
    	standardQualifiedName (typePostfixSyntax)?
    ;

typePostfixSyntax:
	D=DOT  L=LT  (standardQualifiedName | STAR) (typePostfixSyntax)?  G=GT
	;


qualifiedIdentifier
    :
    	I=IDENTIFIER
    ;


// Expression

parExpression
    : L=LPAREN    expression  R=RPAREN
    ;

expression
    :

    	a=assignmentExpression (  C=COMMA   a1=assignmentExpression)*

    ;

expressionNoIn
    :   assignmentExpressionNoIn (  C=COMMA   assignmentExpressionNoIn)*
    ;

//11.13 Assignment Operators
assignmentExpression
    :
      (leftHandSideExpression  assignmentOperator)=> leftHandSideExpression  assignmentOperator  assignmentExpression
    | conditionalExpression
    ;


assignmentExpressionNoIn
    :
      (leftHandSideExpression  assignmentOperator)=> leftHandSideExpression  assignmentOperator  assignmentExpressionNoIn
    |   conditionalExpressionNoIn
    ;

assignmentOperator
	: op=assignmentOperator_int

	;

assignmentOperator_int
    : ASSIGN
//    | MUL_ASSIGN
	| s=STAR a=ASSIGN!
    | DIV_ASSIGN
    | MOD_ASSIGN
    | ADD_ASSIGN
    | SUB_ASSIGN
    | SHL_ASSIGN
//    | SHR_ASSIGN
//    | SHU_ASSIGN
/*    | (('<' '<' '=')=> t1='<' t2='<' t3='='
        { $t1.getLine() == $t2.getLine() &&
          $t1.getCharPositionInLine() + 1 == $t2.getCharPositionInLine() &&
          $t2.getLine() == $t3.getLine() &&
          $t2.getCharPositionInLine() + 1 == $t3.getCharPositionInLine() }?
      -> SHL_ASSIGN){ t1.setText("<<=");} */
    |
    //(
    ('>' '>' '=')=> t1='>' t2='>' t3='='
        { $t1.getLine() == $t2.getLine() &&
          $t1.getCharPositionInLine() + 1 == $t2.getCharPositionInLine() &&
          $t2.getLine() == $t3.getLine() &&
          $t2.getCharPositionInLine() + 1 == $t3.getCharPositionInLine() }?
      //-> SHR_ASSIGN)
      {t1.setText(">>=");}

    |
    //(
    ('>' '>' '>' '=')=> t1='>' t2='>' t3='>' t4='='
        { $t1.getLine() == $t2.getLine() &&
          $t1.getCharPositionInLine() + 1 == $t2.getCharPositionInLine() &&
          $t2.getLine() == $t3.getLine() &&
          $t2.getCharPositionInLine() + 1 == $t3.getCharPositionInLine() &&
          $t3.getLine() == $t4.getLine() &&
          $t3.getCharPositionInLine() + 1 == $t4.getCharPositionInLine() }?
      //-> SHU_ASSIGN)
      {t1.setText(">>>=");}
    | AND_ASSIGN
    | XOR_ASSIGN
    | OR_ASSIGN
    | LOR_ASSIGN
    | LAND_ASSIGN
    ;

//11.12 Conditional Operator ( ?: )
conditionalExpression
    :   logicalORExpression ( Q=QUE   assignmentExpression   C=COLON   assignmentExpression )?
    ;

conditionalExpressionNoIn
    :   logicalORExpressionNoIn ( Q=QUE  assignmentExpression   C=COLON   assignmentExpression )?
    ;

//11.11 Binary Logical Operators
logicalORExpression
    :   logicalANDExpression ( L=LOR  logicalANDExpression )*
    ;

logicalORExpressionNoIn
    :   logicalANDExpressionNoIn ( L=LOR  logicalANDExpressionNoIn )*
    ;

logicalANDExpression
    :   bitwiseORExpression ( L=LAND  bitwiseORExpression )*
    ;

logicalANDExpressionNoIn
    :   bitwiseORExpressionNoIn ( L=LAND  bitwiseORExpressionNoIn )*
    ;

//11.10 Binary Bitwise Operators
bitwiseORExpression
    :   bitwiseXORExpression ( O=OR  bitwiseXORExpression )*
    ;

bitwiseORExpressionNoIn
    :   bitwiseXORExpressionNoIn ( O=OR  bitwiseXORExpressionNoIn )*
    ;

bitwiseXORExpression
    :   bitwiseANDExpression ( x=XOR  bitwiseANDExpression )*
    ;

bitwiseXORExpressionNoIn
    :   bitwiseANDExpressionNoIn ( x=XOR  bitwiseANDExpressionNoIn )*
    ;

bitwiseANDExpression
    :   equalityExpression ( A=AND  equalityExpression )*
    ;

bitwiseANDExpressionNoIn
    :   equalityExpressionNoIn ( A=AND  equalityExpressionNoIn )*
    ;

//11.9 Equality Operators
equalityExpression
    :   relationalExpression ( eq=(EQ|NEQ|SAME|NSAME)  relationalExpression )*
    ;

equalityExpressionNoIn
    :   relationalExpressionNoIn ( eq=(EQ|NEQ|SAME|NSAME)   relationalExpressionNoIn )*
    ;

//11.8 Relational Operators
relationalExpression
    :   shiftExpression
    	(
	    	( g=GT (assign=ASSIGN)?
		        {if (assign!=null)
		         {
		         	g.setText(">=");
		         	g.setType(GTE);
		         }
		        }
	          | eq=(IN|LT|LTE|INSTANCEOF|IS|AS)
	        )
	        shiftExpression
        )*
    ;

relationalExpressionNoIn
    :   shiftExpression
    	(
	    	( g=GT (assign=ASSIGN)?
		        {if (assign!=null)
		         {
		         	g.setText(">=");
		         	g.setType(GTE);
		         }
		        }
	          | eq=(LT|LTE|INSTANCEOF|IS|AS)
	        )
	        shiftExpression
        )*
    ;

//11.7 Bitwise Shift Operators
shiftExpression
    :   a=additiveExpression (
    		(
    			t1=SHL
    			/*(('<' '<' )=> t1='<' t2='<'
        		{$t1.getLine() == $t2.getLine() &&
          		$t1.getCharPositionInLine() + 1 == $t2.getCharPositionInLine() }?
      			-> SHL) {t1.setText("<<");}*/
      		|
      		//(
      		('>' '>')=> t1='>' t2='>'!
        		{ $t1.getLine() == $t2.getLine() &&
          			$t1.getCharPositionInLine() + 1 == $t2.getCharPositionInLine() }?
//      			-> SHR)
      			{t1.setText(">>");}
		    |
		    //(
		    ('>' '>' '>')=> t1='>' t2='>'! t3='>'!
        		{ $t1.getLine() == $t2.getLine() &&
          			$t1.getCharPositionInLine() + 1 == $t2.getCharPositionInLine() &&
          			$t2.getLine() == $t3.getLine() &&
          			$t2.getCharPositionInLine() + 1 == $t3.getCharPositionInLine() }?
      			//-> SHU)
      			{t1.setText(">>>");}
    		)
    		a1=additiveExpression
    	)*
    ;

//11.6 Additive Operators
additiveExpression
    :   multiplicativeExpression ( op=(PLUS|SUB)  multiplicativeExpression )*
    ;

//11.5 Multiplicative Operators
multiplicativeExpression
    :   unaryExpression ( op=(STAR|DIV|MOD) unaryExpression )*
    ;

//11.4 Unary Operators
unaryExpression
    :   postfixExpression
    |  op=(NOT | INV)  unaryExpression
    |   unaryOp postfixExpression


    ;

unaryOp
    :   op=(DELETE | VOID | TYPEOF | INC | DEC | PLUS | SUB | INV | NOT)
    ;


//11.3 Postfix Expressions
postfixExpression
    :   leftHandSideExpression postfixOp?
    ;

postfixOp
    :   op=(INC | DEC)
    ;

//These rules came from a grammar by Patrick Hulsmeijer, posted to the ANTLR examples
memberExpression
	: p=primaryExpression
	| f=functionExpression
	| n=newExpression
	;

newExpression
	: N=NEW   p=primaryExpression
	;

//11.2
leftHandSideExpression
    :   m=memberExpression
    (
      arguments
      | L=LBRACK  expression R=RBRACK
//      | D=DOT  (I=IDENTIFIER  op=XML_NS_OP  )? I=IDENTIFIER
//      | D=DOT  (eitherIdentifier op=XML_NS_OP  )? eitherIdentifier
      | XML_ELLIPSIS eitherIdentifier
      | DOT (eitherIdentifier | parExpression)
      | typePostfixSyntax
      | XML_NS_OP expression
    )*  // | x=XML_AT
    ;

eitherIdentifier
	: I=IDENTIFIER
	 | xmlPropertyIdentifier
	 | allKeywords
	;

typeSpecifier:
	I=IDENTIFIER  | notQuiteReservedWord | I=INTERNAL  | D=DEFAULT
	;


notQuiteReservedWord
	:
	word=(TO | NATIVE | EACH | GET | SET | NAMESPACE | DYNAMIC | FINAL | OVERRIDE | STATIC )
	;

allKeywords
	: (reservedWord | notQuiteReservedWord)
	;
reservedWord
	:
    word=(AS
    | BREAK
    | CASE
    | CATCH
    | CLASS
    | CONST
    | CONTINUE
    | DEFAULT
    | DELETE
    | DO
    | ELSE
    | EXTENDS
    | FALSE
    | FINALLY
    | FOR
    | FUNCTION
    | IF
	| IMPLEMENTS
    | IMPORT
    | IN
    | INSTANCEOF
    | INTERFACE
    | INTERNAL
    | IS
//    | NATIVE
    | NEW
    | NULL
    | PACKAGE
    | PRIVATE
    | PROTECTED
    | PUBLIC
    | RETURN
    | SUPER
    | SWITCH
    | THIS
    | THROW
	| TRUE
    | TRY
    | TYPEOF
    | USE
    | VAR
    | VOID
    | WHILE
    | WITH
//    | EACH
// 	| GET
//    | SET
//    | NAMESPACE
    | INCLUDE
//    | DYNAMIC
//    | FINAL
//    | OVERRIDE
//    | STATIC)
       )

	;

arguments
	:

	  L=LPAREN
	  (  assignmentExpression
	        (
		        C=COMMA

		        assignmentExpression
	        )*
	  )?
	  R=RPAREN



	;

//suffix helper rule
suffix
    :    indexSuffix | propertyReferenceSuffix
    ;
//code like [i] or [1]
indexSuffix
    :    L=LBRACK   expression  R=RBRACK
    ;

propertyReferenceSuffix
    :    D=DOT   I=IDENTIFIER
    |    D=DOT   xmlPropertyIdentifier
    |    D=DOT        //it's a xml only reference match
    ;

//11.1 Primary Expression
primaryExpression
    :    primaryExpressionHelper
    ;

// derived from ECMA-262 basicly. but add super alternative
primaryExpressionHelper
    :   T=THIS
    |   S=SUPER
    |   literal
    |   arrayLiteral // ARRAY_LITERAL
    |   objectLiteral  // OBJECT_LITERAL
    |   (identifierLiteral XML_NS_OP)? identifierLiteral
    |   xmlPrimaryExpression
    |   parExpression // PAR_EXPRESSION
    |   LT type GT (arrayLiteral)? //Vector initializer with optional array data
    ;

//11.1.5 Object Initialiser
objectLiteral
    :   L=LCURLY  propertyNameAndValueList? R=RCURLY
    ;

propertyNameAndValueList
    :   propertyNameAndValue (C=COMMA  propertyNameAndValue)*
    ;

propertyNameAndValue
    :   propertyName C=COLON

    		assignmentExpression
    ;

propertyName
    :   identifierLiteral
    |   stringLiteral
    |   numericLiteral
    ;

//11.1.4 Array Initialiser
arrayLiteral
    :   L=LBRACK  elementList? R=RBRACK
    ;

elementList
    :


        assignmentExpression
    	(
    		C=COMMA

    		assignmentExpression
    	)* (C=COMMA )? //allow extra comma on end, because it's apparently tolerated


    ;