/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weave.data.KeySets
{
	import flash.utils.Dictionary;
	import flash.utils.getTimer;
	
	import weave.api.core.ICallbackCollection;
	import weave.api.core.IDisposableObject;
	import weave.api.data.IKeySet;
	import weave.api.data.IQualifiedKey;
	import weave.api.getCallbackCollection;
	import weave.api.newDisposableChild;
	import weave.api.objectWasDisposed;
	import weave.core.CallbackCollection;
	
	/**
	 * This key set is the union of several other key sets.  It has no session state.
	 * 
	 * @author adufilie
	 */
	public class KeySetUnion implements IKeySet, IDisposableObject
	{
		public static var debug:Boolean = false;
		
		/**
		 * @param keyInclusionLogic A function that accepts an IQualifiedKey and returns true or false.
		 */		
		public function KeySetUnion(keyInclusionLogic:Function = null)
		{
			_keyInclusionLogic = keyInclusionLogic;
			
			if (debug)
				getCallbackCollection(this).addImmediateCallback(this, _firstCallback);
		}
		
		private function _firstCallback():void { debugTrace(this,'trigger',keys.length,'keys'); }
		
		/**
		 * This will be used to determine whether or not to include a key.
		 */		
		private var _keyInclusionLogic:Function = null;
		
		/**
		 * This will add an IKeySet as a dependency and include its keys in the union.
		 * @param keySet
		 */
		public function addKeySetDependency(keySet:IKeySet):void
		{
			if (_keySets.indexOf(keySet) < 0)
			{
				_keySets.push(keySet);
				getCallbackCollection(keySet).addDisposeCallback(this, asyncStart);
				getCallbackCollection(keySet).addImmediateCallback(this, asyncStart, true);
			}
		}
		
		/**
		 * This is a list of the IQualifiedKey objects that define the key set.
		 */
		public function get keys():Array
		{
			return _allKeys;
		}

		/**
		 * @param key A IQualifiedKey object to check.
		 * @return true if the given key is included in the set.
		 */
		public function containsKey(key:IQualifiedKey):Boolean
		{
			return _keyLookup[key] === true;
		}
		
		private var _keySets:Array = []; // Array of IKeySet
		private var _allKeys:Array = []; // Array of IQualifiedKey
		private var _keyLookup:Dictionary = new Dictionary(true); // IQualifiedKey -> Boolean
		
		/**
		 * Use this to check asynchronous task busy status.  This is kept separate because if we report busy status we need to
		 * trigger callbacks when an asynchronous task completes, but we don't want to trigger KeySetUnion callbacks when nothing
		 * changes as a result of completing the asynchronous task.
		 */
		public const busyStatus:ICallbackCollection = newDisposableChild(this, CallbackCollection); // separate owner for the async task to avoid affecting our busy status
		
		private var _asyncKeyArrays:Array; // keys from all key sets
		private var _asyncKeySetIndex:int; // index of current key set
		private var _asyncKeyIndex:int; // index of current key
		private var _prevCompareCounter:int; // keeps track of how many new keys are found in the old keys list
		private var _newKeyLookup:Dictionary; // for comparing to new keys lookup
		private var _newKeys:Array; // new allKeys array in progress
		
		private function asyncStart():void
		{
			// restart async task
			_prevCompareCounter = 0;
			_newKeys = [];
			_newKeyLookup = new Dictionary(true);
			_asyncKeySetIndex = 0;
			_asyncKeyIndex = 0;
			// request all keys now in case this triggers callbacks
			_asyncKeyArrays = [];
			var i:int = _keySets.length;
			while (i--)
			{
				// remove disposed key sets
				if (objectWasDisposed(_keySets[i]))
					_keySets.splice(i, 1);
				else
					_asyncKeyArrays.unshift((_keySets[i] as IKeySet).keys); 
			}
			
			// high priority because all visualizations depend on key sets
			WeaveAPI.StageUtils.startTask(busyStatus, asyncIterate, WeaveAPI.TASK_PRIORITY_HIGH, asyncComplete, lang("Computing the union of {0} key sets", _keySets.length));
		}
		
		private function asyncIterate(stopTime:int):Number
		{
			for (; _asyncKeySetIndex < _asyncKeyArrays.length; _asyncKeySetIndex++)
			{
				var _asyncKeys:Array = _asyncKeyArrays[_asyncKeySetIndex];
				for (; _asyncKeyIndex < _asyncKeys.length; _asyncKeyIndex++)
				{
					if (getTimer() > stopTime)
						return (_asyncKeySetIndex + _asyncKeyIndex / _asyncKeys.length) / _asyncKeyArrays.length;
					
					var key:IQualifiedKey = _asyncKeys[_asyncKeyIndex] as IQualifiedKey;
					if (_newKeyLookup[key] === undefined) // if we haven't seen this key yet
					{
						var includeKey:Boolean = (_keyInclusionLogic == null) ? true : _keyInclusionLogic(key);
						_newKeyLookup[key] = includeKey;
						
						if (includeKey)
						{
							_newKeys.push(key);
							
							// keep track of how many keys we saw both previously and currently
							if (_keyLookup[key] === true)
								_prevCompareCounter++;
						}
					}
				}
				_asyncKeyIndex = 0;
			}
			return 1; // avoids division by zero
		}
		
		private function asyncComplete():void
		{
			// detect change
			if (_allKeys.length != _newKeys.length || _allKeys.length != _prevCompareCounter)
			{
				_allKeys = _newKeys;
				_keyLookup = _newKeyLookup;
				getCallbackCollection(this).triggerCallbacks();
			}
			
			busyStatus.triggerCallbacks();
		}
		
		public function dispose():void
		{
			_keySets = null;
			_allKeys = null;
			_keyLookup = null;
			_newKeyLookup = null;
		}
	}
}
