/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 10, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Enum;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Enum : Declaration
{
	this (Cursor cursor, Cursor parent, Translator translator)
	{
		super(cursor, parent, translator);
	}
	
	override string translate ()
	{
		return writeEnum(spelling, (context) {
			foreach (cursor, parent ; cursor.declarations)
			{
				with (CXCursorKind)
					switch (cursor.kind)
					{
						case CXCursor_EnumConstantDecl:
							output.newContext();
							output ~= translateIdentifier(cursor.spelling);
							output ~= " = ";
							output ~= cursor.enum_.value;
							context.instanceVariables ~= output.currentContext.data;
						break;
						
						default: break;
					}
			}
		});
	}

	@property override string spelling ()
	{
		auto name = cursor.spelling;
		return name.isPresent ? name : generateAnonymousName(cursor);
	}

private:

	string writeEnum (string name, void delegate (EnumData context) dg)
	{
		auto context = new EnumData;
		context.name = translateIdentifier(name);
		
		dg(context);
		
		return context.data;
	}
}