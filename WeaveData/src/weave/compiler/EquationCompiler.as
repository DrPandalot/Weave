/*
    Weave (Web-based Analysis and Visualization Environment)
    Copyright (C) 2008-2011 University of Massachusetts Lowell

    This file is a part of Weave.

    Weave is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License, Version 3,
    as published by the Free Software Foundation.

    Weave is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.compiler
{
	import flash.utils.Dictionary;
	import flash.utils.describeType;
	
	import mx.utils.ObjectUtil;
	import mx.utils.StringUtil;
	
	import weave.api.compiler.ICompiledObject;
	import weave.core.StageUtils;
	import weave.data.AttributeColumns.EquationColumnLib;
	
	/**
	 * This class provides a static function compileEquation() that compiles an
	 * equation into a function that evaluates that equation.
	 * 
	 * @author adufilie
	 */
	public class EquationCompiler
	{
		{ /** begin static code block **/
			initStaticObjects();
			includeLibraries(Math, MathLib, StringUtil, StringLib, BooleanLib, ArrayLib);
		} /** end static code block **/
		
		/**
		 * This function compiles an equation String into a Function that takes no parameters and returns
		 * a value, which is the equation evaluated using the variable values returned by variableGetter.
		 * Variables may be surrounded by quotation marks (") to allow variable names that contain special characters.
		 * The escape sequence for a quoted variable name to indicate a quotation mark is two quotation marks together.
		 * @param equation A mathematical equation to parse.
		 * @param variableGetter A function to map to the get("var") calls in the equation.  Note that the equation 'x + 1' is equivalent to 'get("x") + 1'.
		 * @return A Function generated from the equation String, or null if the String does not represent a valid equation.
		 */
		public static function compileEquation(equation:String, variableGetter:Function):Function
		{
			var tokens:Array = getTokens(equation);
			//trace("source:",equation,"tokens:"+ObjectUtil.toString(tokens));
			var compiledObject:ICompiledObject = compileTokens(tokens, variableGetter, true);
			return createWrapperFunctionForCompiledObject(compiledObject);
		}
		
		/**
		 * This function will compile an equation into a compiled object representing a function that takes no parameters and returns a value.
		 * This function is useful for inspecting the structure of the compiled function and decompiling individual parts.
		 * @param equation A mathematical equation to parse.
		 * @param variableGetter A function to map to the get("var") calls in the equation.  Note that the equation 'x + 1' is equivalent to 'get("x") + 1'.
		 * @return A CompiledConstant or CompiledFunctionCall generated from the tokens, or null if the tokens do not represent a valid equation.
		 */
		public static function compileEquationToObject(equation:String, variableGetter:Function = null, evaluateToConstantIfPossible:Boolean = false):ICompiledObject
		{
			return compileTokens(getTokens(equation), variableGetter, evaluateToConstantIfPossible);
		}
		
		/**
		 * This function surrounds a string with quotes (") and replaces all occurrences
		 * of '"' in the original string with '""' as an escape sequence.
		 * @param A String that may contain special characters.
		 * @return The given variable name, encoded in the format accepted by compileEquation().
		 */
		public static function encodeString(string:String):String
		{
			return '"' + string.split('"').join('""') + '"';
		}

		/**
		 * This function is for internal use only.
		 * @param encodedString A String that was encoded in the same way that encodeString encodes Strings.
		 * @return The decoding of the String.
		 */
		private static function decodeString(encodedString:String):String
		{
			return encodedString.substr(1, encodedString.length - 2).split('""').join('"');
		}
		
		/**
		 * This function will include additional libraries to be supported by the compiler when compiling functions.
		 * @param classesOrObjects An Array of Class definitions or objects containing functions to be supported by the compiler.
		 */		
		public static function includeLibraries(...classesOrObjects):void
		{
			for (var i:int = 0; i < classesOrObjects.length; i++)
			{
				var library:Object = classesOrObjects[i];
				// only add this library to the list if it is not already added.
				if (library != null && libraries.indexOf(library) < 0)
				{
					libraries.push(library);
					
					var classInfo:XML = describeType(library);
					for each (var constantName:String in classInfo.child("constant").attribute("name"))
						constants[constantName] = library[constantName];
					for each (var methodName:String in classInfo.child("method").attribute("name"))
						functions[methodName] = library[methodName];
				}
			}
		}
		
		/**
		 * This function will add a variable to the constants available in equations.
		 * @param constantName The name of the constant.
		 * @param constantValue The value of the constant.
		 */		
		public static function includeConstant(constantName:String, constantValue:*):void
		{
			constants[constantName] = constantValue;
		}

		/**
		 * This function gets a list of all the libraries currently being used by the compiler.
		 * @return A new Array containing a list of all the objects and/or classes used as libraries in the compiler.
		 */		
		public static function getAllLibraries():Array
		{
			return libraries.concat(); // make a copy
		}
		
		/**
		 * This is a list of objects and/or classes containing functions and constants supported by the compiler.
		 */
		private static const libraries:Array = [];
		
		/**
		 * This is the name of the function to use in equations for getting variables by name.
		 * For example, the following two equations do the same thing:  (x + 3)   and   (get("x") + 3)
		 */
		public static const GET_FUNCTION_NAME:String = "get";
		
		/**
		 * This is the prefix used for the function notation of infix operators.
		 * For example, the function notation for ( x + y ) is ( operator+(x,y) ).
		 */
		public static const OPERATOR_FUNCTION_NAME_PREFIX:String = "operator";
		
		/**
		 * This is a String containing all the characters that are treated as whitespace.
		 */
		private static const WHITESPACE:String = ' \r\n\t';
		/**
		 * This object maps the name of a predefined constant to its value.
		 */
		private static var constants:Object = null;
		/**
		 * This object maps a function name to its Function definition.
		 */
		private static var functions:Object = null;
		/**
		 * This object maps an operator like "*" to a Function with the following signature:
		 *     function(x:Number, y:Number):Number
		 * If there is no function associated with the operator, it maps the operator to a value of null.
		 */
		private static var operators:Object = null;
		/**
		 * This object maps a unary operator like "-" to a Function that takes one parameter.
		 */
		private static var unaryOperators:Object = null;
		/**
		 * This is a two-dimensional Array of operator symbols arranged in the order they should be evaluated.
		 * Each nested Array is a group of operators that should be evaluated in the same pass.
		 */
		private static var orderedOperators:Array = null;
		/**
		 * This is an Array of all the unary operator symbols.
		 */
		private static var unaryOperatorSymbols:Array = null;
		/**
		 * The keys in this Dictionary are pointers to impure functions, meaning if they are called
		 * more than once with the same arguments, they may return different results.  The compiler
		 * checks this Dictionary to determine which function calls it cannot simplify to a constant.
		 * An example of an impure function is Math.random().
		 */
		private static var impureFunctions:Dictionary = null;
		/**
		 * This function will initialize the operators, constants, and functions.
		 */
		private static function initStaticObjects():void
		{
			functions = new Object();
			constants = new Object();
			operators = new Object();
			unaryOperators = new Object();
			impureFunctions = new Dictionary();
			
			// add cast functions
			functions["Number"] = MathLib.toNumber;
			functions["String"] = StringLib.toString;
			functions["Boolean"] = BooleanLib.toBoolean;
			functions["Array"] = function(...values):Array { return values; };
			functions["isNaN"] = isNaN;
			
			// add constants so parser will not treat them as variable names
			constants["undefined"] = undefined;
			constants["null"] = null;
			constants["NaN"] = NaN;
			constants["true"] = true;
			constants["false"] = false;

			/** operators **/
			// access
			//operators["."] = true;
			// grouping
			operators["("] = true;
			operators[")"] = true;
			operators[","] = true;
			// math
			operators["**"] = Math.pow;
			operators["*"] = function(x:*, y:*):Number { return x * y; };
			operators["/"] = function(x:*, y:*):Number { return x / y; };
			operators["%"] = function(x:*, y:*):Number { return x % y; };
			operators["+"] = function(x:*, y:*):Number { return x + y; };
			operators["-"] = function(x:*, y:*):Number { return x - y; };
			// bitwise
			operators["~"] = function(x:*):int { return ~x; };
			operators["&"] = function(x:*, y:*):int { return x & y; };
			operators["|"] = function(x:*, y:*):int { return x | y; };
			operators["^"] = function(x:*, y:*):int { return x ^ y; };
			operators["<<"] = function(x:*, y:*):int { return x << y; };
			operators[">>"] = function(x:*, y:*):int { return x >> y; };
			operators[">>>"] = function(x:*, y:*):int { return x >>> y; };
			// comparison
			operators["<"] = function(x:*, y:*):Boolean { return x < y; };
			operators["<="] = function(x:*, y:*):Boolean { return x <= y; };
			operators[">"] = function(x:*, y:*):Boolean { return x > y; };
			operators[">="] = function(x:*, y:*):Boolean { return x >= y; };
			operators["=="] = function(x:*, y:*):Boolean { return x == y; };
			operators["==="] = function(x:*, y:*):Boolean { return x === y; };
			operators["!="] = function(x:*, y:*):Boolean { return x != y; };
			operators["!=="] = function(x:*, y:*):Boolean { return x !== y; };
			// boolean
			operators["!"] = function(x:*):Boolean { return !x; };
			operators["&&"] = function(x:*, y:*):Boolean { return x && y; };
			operators["||"] = function(x:*, y:*):Boolean { return x || y; };
			// branching
			operators["?"] = true;
			operators[":"] = true;
			// assignment
			operators["="] = true; // for now, this is only here to make sure '==' will be captured as an operator

			// unary operators
			unaryOperators['-'] = function(x:*):Number { return -x; };
			unaryOperators['!'] = operators['!'];
			unaryOperators['~'] = operators['~'];
			
			// evaluate operators in the same order as ActionScript
			orderedOperators = [
				['*','/','%'],
				['+','-'],
				['<<','>>','>>>'],
				['<','<=','>','>='],
				['==','!=','===','!=='],
				['&'],
				['^'],
				['|'],
				['&&'],
				['||']
			];
			unaryOperatorSymbols = ['-','~','!'];

			// create a corresponding function name for each operator
			for (var op:String in operators)
				if (operators[op] is Function)
					functions[OPERATOR_FUNCTION_NAME_PREFIX + op] = operators[op];
			
			// Save pointers to impure functions so the compiler will not reduce
			// them to constants when all their parameters are constants.
			impureFunctions[Math['random']] = true;
		}

		/**
		 * @param equation An equation string to parse.
		 * @return An Array containing all the tokens found in the equation.
		 */
		private static function getTokens(equation:String):Array
		{
			var tokens:Array = [];
			var n:int = equation.length;
			// get a flat list of tokens
			var i:int = 0;
			while (i < n)
			{
				var token:String = getToken(equation, i);
				if (WHITESPACE.indexOf(token.charAt(0)) == -1)
					tokens.push(token);
				i += token.length;
			}
			return tokens;
		}
		/**
		 * This function is for internal use only.
		 * @param equation An equation to parse.
		 * @param index The starting index of the token.
		 * @return The token beginning at the specified index.
		 */
		private static function getToken(equation:String, index:int):String
		{
			var endIndex:int;
			var n:int = equation.length;
			var c:String = equation.charAt(index);
			
			// this function assumes operators has already been initialized

			// handle operators (find the longest matching operator)
			endIndex = index;
			while (endIndex < n && operators[ equation.substring(index, endIndex + 1) ] != undefined)
				endIndex++;
			if (index < endIndex)
				return equation.substring(index, endIndex);
			
			// handle whitespace (find the longest matching sequence)
			endIndex = index;
			while (endIndex < n && WHITESPACE.indexOf(equation.charAt(endIndex)) >= 0)
				endIndex++;
			if (index < endIndex)
				return equation.substring(index, endIndex);
			
			// handle quoted string
			if (c == '"')
			{
				// index points to the beginning '"'
				// make endIndex point to the ending '"'
				for (endIndex = index + 1; endIndex < n; endIndex++)
				{
					var twoChar:String = equation.substr(endIndex, 2);
					if (twoChar == '""') // handle escaped '"'
						endIndex++; // skip second '"' and continue
					else if (equation.charAt(endIndex) == '"')
						break; // found ending '"'
				}
				// if ending '"' was not found, append it now
				if (endIndex == n)
					equation += '"';
				// return the quoted string, including the quotes
				return equation.substring(index, endIndex + 1);
			}
			// handle everything else (go until a special character is found)
			for (endIndex = index + 1; endIndex < n; endIndex++)
			{
				c = equation.charAt(endIndex);
				// whitespace or quotes terminates a token
				if (WHITESPACE.indexOf(c) >= 0 || c == '"')
					break;
				// operator terminates a token
				if (operators[c] != undefined)
				{
					// special case: "operator" followed by an operator symbol is treated as a single token
					if (equation.substring(index, endIndex) == OPERATOR_FUNCTION_NAME_PREFIX)
					{
						// this while loop works because any substring of a multi-character operator is also an operator itself
						while (functions[ equation.substring(index, endIndex + 1) ] is Function)
							endIndex++; // include operator symbol
					}
					break;
				}
			}
			return equation.substring(index, endIndex);
		}

		/**
		 * This function will recursively compile a set of tokens into a compiled object representing a function that takes no parameters and returns a value.
		 * Example set of input tokens:  add ( - ( - 2 + 1 ) ** - 4 , 3 ) - ( 4 + - 1 )
		 * @param tokens An Array of tokens for an equation.
		 * @param variableGetter This function should return a value for a given variable name.  The function signature should be:  function(variableName:String):*
		 * @return A CompiledConstant or CompiledFunctionCall generated from the tokens, or null if the tokens do not represent a valid equation.
		 */
		private static function compileTokens(tokens:Array, variableGetter:Function, evaluateToConstantIfPossible:Boolean):ICompiledObject
		{
			var i:int;
			var subArray:Array;
			var compiledParams:Array;

			// step 1: group tokens by parentheses and compile function calls
			while (true)
			{
				// find last index of '(', then find index of matching ')'
				var open:int = tokens.lastIndexOf('(');
				if (open < 0)
					break; // no '(' found
				var close:int = tokens.indexOf(')', open + 1);
				if (open < close)
				{
					// cut out tokens between '(' and ')'
					subArray = tokens.splice(open + 1, close - open - 1);
					// if this is a function call, group tokens between commas and compile the function
					// special check for get() function -- replace with call to variableGetter()
					var funcToken:* = tokens[open - 1];
					if (open > 0 && (functions[funcToken] != undefined || funcToken == GET_FUNCTION_NAME))
					{
						//trace("compiling function call", tokens[open-1] + "(", subArray.join(' '), ")");
						compiledParams = [];
						// special case: zero-length parameters; if subArray is empty, compiledParams is already set up
						if (subArray.length > 0)
						{
							while (true)
							{
								var comma:int = subArray.indexOf(',');
								if (comma >= 0)
								{
									// group tokens before first comma
									var group:Array = subArray.splice(0, comma);
									// compile this group of tokens as a parameter
									compiledParams.push(compileTokens(group, variableGetter, evaluateToConstantIfPossible));
									subArray.shift(); // remove comma
								}
								else
								{
									// compile remaining group of tokens as a parameter
									compiledParams.push(compileTokens(subArray, variableGetter, evaluateToConstantIfPossible));
									break;
								}
							}
						}
						// replace the function token, '(', and ')' tokens with a compiled function call
						// if the function is the variableGetter, compileFunction() should not attempt to simplify to a constant.
						var func:Function;
						if (funcToken == GET_FUNCTION_NAME)
							func = variableGetter;
						else
							func = functions[funcToken] as Function;
						tokens.splice(open - 1, 3, compileFunction(funcToken, func, compiledParams, funcToken != GET_FUNCTION_NAME && evaluateToConstantIfPossible));
					}
					else // These parentheses do not correspond to a function call.
					{
						//trace("compiling tokens (", subArray.join(' '), ")");
						if (open > 0 && !(tokens[open - 1] is Function) && operators[tokens[open - 1]] == undefined)
							throw new Error("Missing operator or function name before parentheses");
						// Replace the '(' and ')' tokens with the result of compiling subArray
						tokens.splice(open, 2, compileTokens(subArray, variableGetter, evaluateToConstantIfPossible));
					}
				}
				else
					throw new Error("Missing ')'");
			}
			// return null if there are extra ',' or ')' tokens
			if (tokens.indexOf(',') >= 0)
				throw new Error("Misplaced ',' in "+tokens.join(' '));
			if (tokens.indexOf(')') >= 0)
				throw new Error("Misplaced ')'");

			// -------------------

			// there are no more parentheses, so the remaining tokens are operators, constants, and variable names.
			//trace("compiling tokens", ObjectUtil.toString(tokens.join(' ')));
			
			// step 2: handle infix '.'
			
			// step 3: compile constants and variable names
			var token:*;
			for (i = 0; i < tokens.length; i++)
			{
				token = tokens[i];
				// skip tokens that have already been compiled and skip operator tokens
				if (token is ICompiledObject || operators[token] != undefined)
					continue;
				// evaluate constants
				if (constants[token] != undefined)
				{
					tokens[i] = new CompiledConstant(token, constants[token]);
					continue;
				}
				// if the token starts with '"', treat it as a String
				if (token.charAt(0) == '"')
				{
					// parse quoted String, handling '""' escape sequence.
					tokens[i] = new CompiledConstant(token, decodeString(token));
					continue;
				}
				// attempt to evaluate the token as a Number
				try {
					var number:Number = Number(token);
					if (!isNaN(number))
					{
						tokens[i] = new CompiledConstant(token, number);
						continue;
					}
				} catch (e:Error) { }
				// treat everything else as a variable name.
				// make a copy of the variable name that is safe for the wrapper function to use
				// compile the token as a call to variableGetter.
				tokens[i] = compileVariable(variableGetter, token);
			}
			
			// step 4: compile '**' infix operators, left to right
			compileInfixOperators(tokens, ['**'], evaluateToConstantIfPossible);
			
			// step 5: compile unary operators
			compileUnaryOperators(tokens, unaryOperatorSymbols, evaluateToConstantIfPossible);
			
			// step 6: compile remaining infix operators in order
			for (i = 0; i < orderedOperators.length; i++)
				compileInfixOperators(tokens, orderedOperators[i], evaluateToConstantIfPossible);
			
			// step 7: compile conditional branches
			while (true)
			{
				// true branch includes everything between the last '?' and the next ':'
				var left:int = tokens.lastIndexOf('?');
				var right:int = tokens.indexOf(':', left);
				
				// stop if any section has no tokens
				if (left < 1 || right < 0 || left + 1 == right || right + 1 == tokens.length)
					break;
				
				// false branch includes everything after the corresponding ':' up until the next ':' or the end
				var end:int = tokens.indexOf(':', right + 1);
				if (end < 0)
					end = tokens.length;
				
				var condition:ICompiledObject = compileTokens([tokens[left - 1]], variableGetter, evaluateToConstantIfPossible);
				var trueBranch:ICompiledObject = compileTokens(tokens.slice(left + 1, right), variableGetter, evaluateToConstantIfPossible);
				var falseBranch:ICompiledObject = compileTokens(tokens.slice(right + 1, end), variableGetter, evaluateToConstantIfPossible);
				
				var result:ICompiledObject;
				if (evaluateToConstantIfPossible && condition is CompiledConstant)
					result = (condition as CompiledConstant).value ? trueBranch : falseBranch;
				else
					result = new CompiledConditionalBranch(condition, trueBranch, falseBranch);
				
				tokens.splice(left - 1, end - left + 1, result);
			}
			// stop if any branch operators remain
			if (Math.max(tokens.indexOf('?'), tokens.indexOf(':')) >= 0)
				throw new Error('Invalid conditional branch');
			
			// step 8: compile the last token
			// there should be only a single token left
			if (tokens.length == 1)
				return tokens[0];

			if (tokens.length > 1)
				throw new Error("Invalid equation: missing operator between " + decompile(tokens[0]) + ' and ' + decompile(tokens[1]));

			throw new Error("Empty equation");
		}

		/**
		 * This function is for internal use only.
		 * This function ensures that mathFunction and evaluatedParams are new Flash variables for each wrapper function created.
		 * This returns a Function with the signature:  function():*
		 * @param functionName The name of the function.
		 * @param functionToCompile A function to create a wrapper for.
		 * @param compiledParams An array of compiled parameters that will be evaluated when the wrapper function is called.
		 * @param evaluateToConstantIfPossible If this is true and all the compiledParameters are constants, the function will be called once and the result will be saved as a constant.
		 * @return A CompiledObject that contains either a constant or a wrapper function that runs the functionToCompile after evaluating the compiledParams.
		 */
		private static function compileFunction(functionName:String, functionToCompile:Function, compiledParams:Array, evaluateToConstantIfPossible:Boolean):ICompiledObject
		{
			var call:CompiledFunctionCall = new CompiledFunctionCall(functionName, functionToCompile, compiledParams);
			// if the compiled function call should not be evaluated to a constant, return it now.
			// impure functions cannot be evaluated to constants because thety may return different results on the same input.
			if (!evaluateToConstantIfPossible || impureFunctions[functionToCompile] != undefined)
				return call;
			// check for CompiledFunctionCall objects in the compiled parameters
			for each (var param:ICompiledObject in compiledParams)
				if (param is CompiledFunctionCall)
					return call; // this compiled funciton call cannot be evaluated to a constant
			// if there are no CompiledFunctionCall objects in the compiled parameters, evaluate the compiled function call to a constant.
			var callWrapper:Function = createWrapperFunctionForCompiledObject(call);
			return new CompiledConstant(decompile(call), callWrapper());
		}

		/**
		 * This function is for internal use only.
		 * This function is necessary because variableName needs to be a new Flash variable each time a wrapper function is created.
		 * @param variableGetter This function should return a value for a given variable name.  The function signature should be:  function(variableName:String):*
		 * @param variableName The name of the variable to get when the resulting wrapper function is evaluated.
		 * @param A CompiledFunctionCall for calling variableGetter(variableName).
		 */
		private static function compileVariable(variableGetter:Function, variableName:String):CompiledFunctionCall
		{
			//trace('compile variableGetter('+variableName+')');
			return new CompiledFunctionCall(GET_FUNCTION_NAME, variableGetter, [new CompiledConstant(encodeString(variableName), variableName)]);
		}

		/**
		 * This function is for internal use only.
		 * This will compile unary operators of the given type from right to left.
		 * @param compiledTokens An Array of compiled tokens for an equation.  No '(' ')' or ',' tokens should appear in this Array.
		 * @param operatorSymbols An Array containing all the infix operator symbols to compile.
		 * @param evaluateToConstantIfPossible When this is true, function calls will be simplified to constants where possible.
		 */
		private static function compileUnaryOperators(compiledTokens:Array, operatorSymbols:Array, evaluateToConstantIfPossible:Boolean):void
		{
			var index:int;
			for (index = compiledTokens.length - 1; index >= 0; index--)
			{
				// skip tokens that are not unary operators
				if (operatorSymbols.indexOf(compiledTokens[index]) < 0)
					continue;
				
				// fail when next token is not a compiled object
				if (index + 1 == compiledTokens.length || compiledTokens[index + 1] is String)
					throw new Error("Misplaced unary operator '" + compiledTokens[index] + "'");
				
				// skip infix operator
				if (index > 0 && compiledTokens[index - 1] is ICompiledObject)
					continue;
				
				// compile unary operator
				//trace("compile unary operator", ObjectUtil.toString(compiledTokens.slice(index, index + 2)));
				compiledTokens.splice(index, 2, compileFunction(compiledTokens[index], unaryOperators[compiledTokens[index]], [compiledTokens[index + 1]], evaluateToConstantIfPossible));
			}
		}
		
		/**
		 * This function is for internal use only.
		 * This will compile infix operators of the given type from left to right.
		 * @param compiledTokens An Array of compiled tokens for an equation.  No '(' ')' or ',' tokens should appear in this Array.
		 * @param operatorSymbols An Array containing all the infix operator symbols to compile.
		 * @param evaluateToConstantIfPossible When this is true, function calls will be simplified to constants where possible.
		 */
		private static function compileInfixOperators(compiledTokens:Array, operatorSymbols:Array, evaluateToConstantIfPossible:Boolean):void
		{
			var index:int = 0;
			while (index < compiledTokens.length)
			{
				// skip tokens that are not infix operators
				if (operatorSymbols.indexOf(compiledTokens[index]) < 0)
				{
					index++;
					continue;
				}
				
				// special case code for infix operators ('**') that are evaluated prior to unary operators
				var right:int = index + 1;
				// find the next ICompiledObjecgt
				while (right < compiledTokens.length && compiledTokens[right] is String)
					right++;
				// if there were String tokens, we need to compile unary operators on the right-hand-side
				if (right > index + 1)
				{
					// extract the right-hand-side, compile unary operators, and then insert the result to the right of the infix operator
					var rhs:Array = compiledTokens.splice(index + 1, right - index);
					compileUnaryOperators(rhs, unaryOperatorSymbols, evaluateToConstantIfPossible);
					if (rhs.length != 1)
						throw new Error("Unable to parse second parameter of infix operator '" + compiledTokens[index] + "'");
					compiledTokens.splice(index + 1, 0, rhs[0]);
				}
				
				// stop if infix operator does not have compiled objects on either side
				if (index == 0 || index + 1 == compiledTokens.length || compiledTokens[index - 1] is String || compiledTokens[index + 1] is String)
					throw new Error("Misplaced infix operator '" + compiledTokens[index] + "'");
				
				// compile a wrapper for the operator call
				var operatorFunction:Function = operators[compiledTokens[index]] as Function;
				var compiledParams:Array = [compiledTokens[index - 1], compiledTokens[index + 1]];
				// replace the tokens for this infix operator call with the compiled operator call
				//trace("compile infix operator", ObjectUtil.toString(compiledTokens.slice(index - 1, index + 2)));
				var functionName:String = OPERATOR_FUNCTION_NAME_PREFIX + compiledTokens[index];
				compiledTokens.splice(index - 1, 3, compileFunction(functionName, operatorFunction, compiledParams, evaluateToConstantIfPossible));
			}
		}

		/**
		 * @param compiledObject A CompiledFunctionCall or CompiledConstant to decompile into an equation String.
		 * @return The equation String generated from the compiledObject.
		 */
		public static function decompile(compiledObject:ICompiledObject):String
		{
			if (compiledObject is CompiledConstant)
				return (compiledObject as CompiledConstant).name;
			
			if (compiledObject is CompiledConditionalBranch)
			{
				var ccb:CompiledConditionalBranch = compiledObject as CompiledConditionalBranch;
				return StringUtil.substitute("({0} ? {1} : {2})", decompile(ccb.condition), decompile(ccb.trueBranch), decompile(ccb.falseBranch));
			}
			
			//trace("decompiling: " + ObjectUtil.toString(compiledObject));
			var call:CompiledFunctionCall = compiledObject as CompiledFunctionCall;
			// If this is a simple call to get("var") and the variable name parses without
			// the need for quotes, replace the function call with the variable name.
			if (call.name == GET_FUNCTION_NAME && call.compiledParams.length == 1)
			{
				var constant:CompiledConstant = call.compiledParams[0] as CompiledConstant;
				var variableName:String = constant.value as String;
				if (constant && variableName)
				{
					try
					{
						// If the variable name compiles into the same call to get(), it's safe to return just the variable name.
						var recompiled:CompiledFunctionCall = compileEquationToObject(constant.value, null, false) as CompiledFunctionCall;
						if (recompiled && recompiled.name == GET_FUNCTION_NAME && recompiled.compiledParams.length == 1)
						{
							constant = recompiled.compiledParams[0] as CompiledConstant;
							if (variableName == constant.value)
								return variableName;
						}
					}
					catch (e:Error)
					{
						// if the variable name fails to compile, we can't simplify the get() syntax. 
					}
				}
			}
			// decompile each paramter
			var params:Array = [];
			for (var i:int = 0; i < call.compiledParams.length; i++)
				params[i] = decompile(call.compiledParams[i]);
			// replace infix operator function calls with the preferred infix syntax
			if (call.name.indexOf(OPERATOR_FUNCTION_NAME_PREFIX) == 0 && params.length == 2)
				return '(' + params.join(' ' + call.name.replace(OPERATOR_FUNCTION_NAME_PREFIX, '') + ' ') + ')';
			return call.name + '(' + params.join(', ') + ')';
		}
		
		/**
		 * This function is for internal use only.
		 * @param compiledObject Either a CompiledConstant or a CompiledFunctionCall.
		 * @return A Function that takes no parameters and returns the result of evaluating the ICompiledObject.
		 */
		private static function createWrapperFunctionForCompiledObject(compiledObject:ICompiledObject):Function
		{
			if (compiledObject == null)
				return null;
			
			if (compiledObject is CompiledConstant)
			{
				// create a new variable for the value to avoid the overhead of
				// accessing a member variable of the CompiledConstant object.
				var value:* = (compiledObject as CompiledConstant).value;
				return function():* { return value; };
			}
			
			if (compiledObject is CompiledConditionalBranch)
			{
				var ccb:CompiledConditionalBranch = compiledObject as CompiledConditionalBranch;
				
				if (ccb.condition is CompiledConstant)
					return createWrapperFunctionForCompiledObject((ccb.condition as CompiledConstant).value ? ccb.trueBranch : ccb.falseBranch);
				
				var condition:Function = createWrapperFunctionForCompiledObject(ccb.condition);
				
				var trueIsConstant:Boolean = ccb.trueBranch is CompiledConstant;
				var trueBranch:* = trueIsConstant ? (ccb.trueBranch as CompiledConstant).value : createWrapperFunctionForCompiledObject(ccb.trueBranch);
				
				var falseIsConstant:Boolean = ccb.falseBranch is CompiledConstant;
				var falseBranch:* = falseIsConstant ? (ccb.falseBranch as CompiledConstant).value : createWrapperFunctionForCompiledObject(ccb.falseBranch);
				
				// optimized for speed
				return function():*
				{
					if (condition())
						return trueIsConstant ? trueBranch : trueBranch();
					return falseIsConstant ? falseBranch : falseBranch();
				};
			}
			
			// create the variables that will be used inside the wrapper function
			var call:CompiledFunctionCall;
			var subCall:CompiledFunctionCall;
			var compiledParams:Array;
			var result:*;
			var stack:Array = []; // used as a queue of function calls
			// return the wrapper function
			// this function avoids unnecessary function calls by keeping its own call stack rather than using recursion.
			return function():*
			{
				// initialize top-level function and push it onto the stack
				call = compiledObject as CompiledFunctionCall;
				call.evalIndex = 0;
				stack.length = 1;
				stack[0] = call;
				while (true)
				{
					// evaluate the CompiledFunctionCall on top of the stack
					call = stack[stack.length - 1] as CompiledFunctionCall;
					compiledParams = call.compiledParams;
					// check which parameters should be evaluated
					for (; call.evalIndex < compiledParams.length; call.evalIndex++)
					{
						//trace(StringLib.lpad('', stack.length, '\t')+"["+call.evalIndex+"] "+compiledParams[call.evalIndex].name);
						subCall = compiledParams[call.evalIndex] as CompiledFunctionCall;
						if (subCall != null)
						{
							// initialize subCall and push onto stack
							subCall.evalIndex = 0;
							stack.push(subCall);
							break;
						}
					}
					// if more parameters need to be evaluated, evaluate the new top of the stack
					if (call.evalIndex < compiledParams.length)
						continue;
					// no parameters need to be evaluated, so make the function call now
					try
					{
						result = call.method.apply(null, call.evaluatedParams);
					}
					catch (e:Error)
					{
						result = undefined;
					}
					// remove this call from the stack
					stack.pop();
					// if there is no parent function call, return the result
					if (stack.length == 0)
						return result;
					// otherwise, store the result in the evaluatedParams array of the parent call
					call = stack[stack.length - 1] as CompiledFunctionCall;
					call.evaluatedParams[call.evalIndex] = result;
					// advance the evalIndex so the next parameter will be evaluated.
					call.evalIndex++;
				}
				return null; // unreachable
			};
		}
		
		//-----------------------------------------------------------------
		private static function test():void
		{
			var eqs:Array = [
				'(- x * 3) / get("var") + -2 + pow(5,3) +operator**(6,3)',
				'operator+ ( - ( - 2 + 1 ) ** - 4 , - 3 ) - ( - 4 + - 1 * - 7 )',
				'-var---3+var2',
				'(x + var) / operator+ ( - ( 2 + 1 ) ** 4 , 3 ) - ( 4 + 1 )',
				'3',
				'-3',
				'var',
				'-var',
				'roundSignificant(random(),3)',
				'rpad("hello", 4+(var+2)*2, "._,")',
				'lpad("hello", 4+(var+2)*2, "._,")',
				'substr("hello world", var*2, 5)',
				'strlen(random())',
				'concat("(0x", upper(toBase(0xFF00FF,16)), ") ", lpad(toBase(var*20, 2, 4), 9), ", base10: ", rpad(toBase(sign(var) * (var+10),10,3), 6), ", base16: ", toBase(var+10,16))'
			];
			var values:Array = [-2, -1, -0.5, 0, 0.5, 1, 2];
			var vars:Object = {};
			vars['var'] = 123;
			vars['var2'] = 222;
			vars['x'] = 10;
			var variableGetter:Function = function(name:String):*
			{
				//trace("get variable "+name+" = "+vars[name]);
				return vars[name];
			}
			
			
			for each (var eq:String in eqs)
			{
				trace("  equation: "+eq);
				var tokens:Array = getTokens(eq);
				trace("    tokens: "+tokens.join(' '));
				var decompiled:String = decompile(compileTokens(tokens, variableGetter, true));
				trace("decompiled: "+decompiled);
				var tokens2:Array = getTokens(decompiled);
				trace("   tokens2: "+tokens2.join(' '));
				var recompiled:String = decompile(compileTokens(tokens2, variableGetter, true));
				trace("recompiled: "+recompiled);
				//trace(ObjectUtil.toString(tokens));
				var f:Function = compileEquation(eq, variableGetter);
				for each (var value:* in values)
				{
					vars['var'] = value;
					trace("f(var="+value+")\t= " + f(value));
				}
			}
		}
	}
}
