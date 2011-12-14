/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Weave API.
 *
 * The Initial Developer of the Original Code is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

package weave.api.core
{
	/**
	 * This is an interface for a central location to report progress of asynchronous requests.
	 * Since this interface extends ILinkableObject, getCallbackCollection() can be used on an IProgressIndicator.
	 * Callbacks should be triggered after any action that would change the result of getNormalizedProgress().
	 * 
	 * @author adufilie
	 */
	public interface IProgressIndicator extends ILinkableObject
	{
		/**
		 * This is the number of active background tasks.
		 */
		function getTaskCount():int;

		/**
		 * This function will register a background task.
		 * @param taskToken A token representing a background task.
		 */
		function addTask(taskToken:Object):void;
		
		/**
		 * This function will check if a background task is registered as an active task.
		 * @param taskToken A token representing a background task.
		 * @return A value of true if the task was previously added and not yet removed.
		 */
		function hasTask(taskToken:Object):Boolean;
		
		/**
		 * This function will report the progress of a background task.
		 * @param taskToken An object representing a task.
		 * @param percent The current progress of the task.
		 */
		function updateTask(taskToken:Object, percent:Number):void;

		/**
		 * This function will remove a previously registered pending request token and decrease the pendingRequestCount if necessary.
		 * 
		 * @param taskToken The object to remove from the progress indicator.
		 */
		function removeTask(taskToken:Object):void;
		
		/**
		 * This function checks the overall progress of all pending requests.
		 *
		 * @return A Number between 0 and 1.
		 */
		function getNormalizedProgress():Number;
	}
}
