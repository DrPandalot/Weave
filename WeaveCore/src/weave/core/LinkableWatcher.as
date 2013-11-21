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
	import weave.api.WeaveAPI;
	import weave.api.core.IDisposableObject;
	import weave.api.core.ILinkableObject;
	
	/**
	 * This is used to dynamically attach a set of callbacks to different targets.
	 * The callbacks of the LinkableWatcher will be triggered automatically when the
	 * target triggers callbacks, changes, becomes null or is disposed.
	 * @author adufilie
	 */
	public class LinkableWatcher implements ILinkableObject, IDisposableObject
	{
		/**
		 * Instead of calling this constructor directly, consider using one of the global functions
		 * newLinkableChild() or newDisposableChild() to make sure the watcher will get disposed automatically.
		 * @param typeRestriction Optionally restricts which type of targets this watcher accepts.
		 * @see weave.api.core.newLinkableChild()
		 * @see weave.api.core.newDisposableChild()
		 */
		public function LinkableWatcher(typeRestriction:Class = null)
		{
			_typeRestriction = typeRestriction;
		}
		
		private var _typeRestriction:Class;
		private var _target:ILinkableObject; // the current target
		
		/**
		 * This is the linkable object currently being watched.
		 */		
		public function get target():ILinkableObject
		{
			return _target;
		}
		
		/**
		 * This sets the new target to which should be watched.
		 * Callbacks will be triggered immediately if the new target is different from the old one.
		 */
		public function set target(newTarget:ILinkableObject):void
		{
			if (_typeRestriction)
				newTarget = newTarget as _typeRestriction as ILinkableObject;
			
			// do nothing if the targets are the same.
			if (_target == newTarget)
				return;
			
			// unlink from old target
			if (_target)
			{
				WeaveAPI.SessionManager.getCallbackCollection(_target).removeCallback(_handleTargetDispose);
				
				// if we own the previous target, dispose it
				if (WeaveAPI.SessionManager.getLinkableOwner(_target) == this)
					WeaveAPI.SessionManager.disposeObjects(_target);
				else
					(WeaveAPI.SessionManager as SessionManager).unregisterLinkableChild(this, _target);
			}
			
			_target = newTarget;
			
			// link to new target
			if (_target)
			{
				WeaveAPI.SessionManager.registerLinkableChild(this, _target);
				WeaveAPI.SessionManager.getCallbackCollection(_target).addDisposeCallback(this, _handleTargetDispose);
			}
			
			WeaveAPI.SessionManager.getCallbackCollection(this).triggerCallbacks();
		}
		
		private function _handleTargetDispose():void
		{
			_target = null;
			WeaveAPI.SessionManager.getCallbackCollection(this).triggerCallbacks();
		}
		
		/**
		 * @inheritDoc
		 */
		public function dispose():void
		{
			_target = null; // everything else will be cleaned up automatically
		}
	}
}
