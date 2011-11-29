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

package weave.core
{
	import flash.utils.getQualifiedClassName;
	
	import weave.api.core.ILinkableObject;
	
	/**
	 * This is a dummy class that serves as no more than a qualified class name.
	 * 
	 * @author adufilie
	 */
	[ExcludeClass]
	public final class GlobalObjectReference implements ILinkableObject
	{
		public static const qualifiedClassName:String = getQualifiedClassName(GlobalObjectReference);
		
		public function GlobalObjectReference(Please:_do_not_call_this_constructor) { }
	}
}
internal class _do_not_call_this_constructor { }
