/*
Weave (Web-based Analysis and Visualization Environment)
Copyright (C) 2008-2011 University of Massachusetts Lowell

This file is a part of Weave.

Weave is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License, Version 3,
as published by the Free Software Foundation.

Weave is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Weave. If not, see <http://www.gnu.org/licenses/>.
*/




package weave.ui
{
	import flash.display.DisplayObject;
	import flash.events.ContextMenuEvent;
	import flash.events.MouseEvent;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	
	import mx.containers.Canvas;
	import mx.core.Application;
	import mx.core.UIComponent;
	import mx.managers.CursorManagerPriority;
	
	import weave.api.WeaveAPI;
	import weave.api.core.IDisposableObject;
	import weave.api.core.ILinkableContainer;
	import weave.api.core.ILinkableObject;
	import weave.api.newDisposableChild;
	import weave.api.newLinkableChild;
	import weave.api.registerLinkableChild;
	import weave.compiler.StandardLib;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.core.StageUtils;
	import weave.utils.CustomCursorManager;
	
	
	/**
	 * PenTool
	 * This is a class that controls the graphical annotations within Weave.
	 *
	 * @author jfallon
	 * @author adufilie
	 */
	public class PenTool extends UIComponent implements ILinkableObject, IDisposableObject
	{
		public function PenTool()
		{
			percentWidth = 100;
			percentHeight = 100;
			
			// add local event listeners for rollOver/rollOut for changing the cursor
			addEventListener(MouseEvent.MOUSE_OVER, handleRollOver);
			addEventListener(MouseEvent.MOUSE_OUT, handleRollOut);
			// add local event listener for mouse down.  local rather than global because we don't care if mouse was pressed elsewhere
			addEventListener(MouseEvent.MOUSE_DOWN, handleMouseDown);
			// add global event listener for mouse move and mouse up because user may move or release outside this display object
			StageUtils.addEventCallback(MouseEvent.MOUSE_MOVE, this, handleMouseMove);
			StageUtils.addEventCallback(MouseEvent.MOUSE_UP, this, handleMouseUp);
		}
		
		public function dispose():void
		{
			editMode = false; // public setter cleans up event listeners and cursor
		}
		
		private var _editMode:Boolean = false; // true when editing
		private var _drawing:Boolean = false; // true when editing and mouse is down
		private var _coordsArrays:Array = []; // parsed from coords LinkableString
		
		/**
		 * This is used for sessiong all of the coordinates.
		 */
		public const coords:LinkableString = registerLinkableChild(this, new LinkableString(''), handleCoordsChange);
		/**
		 * Allows user to change the size of the line.
		 */
		public const lineWidth:LinkableNumber = registerLinkableChild(this, new LinkableNumber(2), invalidateDisplayList);
		/**
		 * Allows the user to change the color of the line.
		 */
		public const lineColor:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0x000000), invalidateDisplayList);
		
		public function get editMode():Boolean
		{
			return _editMode;
		}
		public function set editMode(value:Boolean):void
		{
			if (_editMode == value)
				return;
			
			_editMode = value;
			
			_drawing = false;
			if (value)
				CustomCursorManager.showCursor(CustomCursorManager.PEN_CURSOR, CursorManagerPriority.HIGH, -3, -22);
			else
				CustomCursorManager.removeAllCursors();
			invalidateDisplayList();
		}
		
		private function handleCoordsChange():void
		{
			if (!_drawing)
				_coordsArrays = WeaveAPI.CSVParser.parseCSV( coords.value );
			invalidateDisplayList();
		}
		
		/**
		 * This function is called when the left mouse button is pressed inside the PenTool UIComponent.
		 * It adds the initial mouse position coordinate to the session state so it knows where
		 * to start from for the following lineTo's added to it.
		 */
		private function handleMouseDown(event:MouseEvent):void
		{
			if (!_editMode)
				return;
			
			_drawing = true;
			// new line in CSV means "moveTo"
			_coordsArrays.push([mouseX, mouseY]);
			coords.value += '\n' + mouseX + "," + mouseY + ",";
			invalidateDisplayList();
		}
		
		private function handleMouseUp():void
		{
			if (!_editMode)
				return;
			
			_drawing = false;
			invalidateDisplayList();
		}
		
		private function handleMouseMove():void
		{
			if (!_editMode)
				return;
			
			if (_drawing)
			{
				var x:Number = StandardLib.constrain(mouseX, 0, unscaledWidth);
				var y:Number = StandardLib.constrain(mouseY, 0, unscaledHeight);
				
				var line:Array = _coordsArrays[_coordsArrays.length - 1];
				// only save new coords if they are different from previous coordinates
				if (line.length < 2 || line[line.length - 2] != x || line[line.length - 1] != y)
				{
					line.push(x, y);
					coords.value += x + "," + y + ",";
					invalidateDisplayList();
				}
			}
		}
		
		private function handleRollOver( e:MouseEvent ):void
		{
			if (!_editMode)
				return;
			
			CustomCursorManager.showCursor(CustomCursorManager.PEN_CURSOR, CursorManagerPriority.HIGH, -3, -22);
		}
		
		private function handleRollOut( e:MouseEvent ):void
		{
			if (!_editMode)
				return;
			
			CustomCursorManager.removeAllCursors();
		}
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			graphics.clear();
			
			if (_editMode)
			{
				// draw invisible transparent rectangle to capture mouse events
				graphics.lineStyle(0, 0, 0);
				graphics.beginFill(0, 0);
				graphics.drawRect(0, 0, unscaledWidth, unscaledHeight);
				graphics.endFill();
			}
			
			graphics.lineStyle(lineWidth.value, lineColor.value);
			for (var line:int = 0; line < _coordsArrays.length; line++)
			{
				var lineArray:Array = _coordsArrays[line];
				for (var i:int = 0; i < lineArray.length - 1 ; i += 2 )
				{
					if ( i == 0 )
						graphics.moveTo( lineArray[i], lineArray[i+1] );
					else
						graphics.lineTo( lineArray[i], lineArray[i+1] );
				}
			}
		}
		
		/*************************************************
		 * static section *
		 *************************************************/
		
		private static var _penToolMenuItem:ContextMenuItem = null;
		private static var _removeDrawingsMenuItem:ContextMenuItem = null;
		private static const ENABLE_PEN:String = "Enable Pen Tool";
		private static const DISABLE_PEN:String = "Disable Pen Tool";
		private static const PEN_OBJECT_NAME:String = "penTool";
		
		public static function createContextMenuItems(destination:DisplayObject):Boolean
		{
			if(!destination.hasOwnProperty("contextMenu") )
				return false;
			
			// Add a listener to this destination context menu for when it is opened
			var contextMenu:ContextMenu = destination["contextMenu"] as ContextMenu;
			contextMenu.addEventListener(ContextMenuEvent.MENU_SELECT, handleContextMenuOpened);
			
			// Create a context menu item for printing of a single tool with title and logo
			_penToolMenuItem = CustomContextMenuManager.createAndAddMenuItemToDestination(ENABLE_PEN, destination, handleDrawModeMenuItem, "5 drawingMenuItems");
			_removeDrawingsMenuItem = CustomContextMenuManager.createAndAddMenuItemToDestination("Remove All Drawings", destination, handleEraseDrawingsMenuItem, "5 drawingMenuItems");
			_removeDrawingsMenuItem.enabled = false;
			
			return true;
		}
		
		/**
		 * This function is called whenever the context menu is opened.
		 * The function will change the caption displayed depending upon if there is any drawings.
		 * This is also used to get the correct mouse pointer for the context menu.
		 */
		private static function handleContextMenuOpened(e:ContextMenuEvent):void
		{
			var contextMenu:ContextMenu = (Application.application as Application).contextMenu;
			if (!contextMenu)
				return;
			CustomCursorManager.removeCurrentCursor();
			//Reset Context Menu as if no PenMouse Object is there and let following code adjust as necessary.
			_penToolMenuItem.caption = ENABLE_PEN;
			_removeDrawingsMenuItem.enabled = false;
			//If session state is imported need to detect if there already is drawings.
			//Check if LinkableContainer is null.
			if( ( getLinkableContainer(e.mouseTarget) as ILinkableContainer) )
				if( ( getLinkableContainer(e.mouseTarget) as ILinkableContainer).getLinkableChildren().getObject( PEN_OBJECT_NAME ) )
				{
					var penObject:PenTool = ( getLinkableContainer(e.mouseTarget) as ILinkableContainer).getLinkableChildren().getObject( PEN_OBJECT_NAME ) as PenTool;
					if (penObject && penObject.editMode)
					{
						_penToolMenuItem.caption = DISABLE_PEN;
					}
					else
					{
						_penToolMenuItem.caption = ENABLE_PEN;
					}
					_removeDrawingsMenuItem.enabled = true;
				}
		}
		
		/**
		 * This function gets called whenever Enable/Disable Pen Tool is clicked in the Context Menu.
		 * This creates a PenMouse object if there isn't one existing already.
		 * All of the necessary event listeners are added and captions are
		 * dealt with appropriately.
		 */
		private static function handleDrawModeMenuItem(e:ContextMenuEvent):void
		{
			var linkableContainer:ILinkableContainer = getLinkableContainer(e.mouseTarget);
			
			if ( !linkableContainer )
				return;
			
			var penTool:PenTool = linkableContainer.getLinkableChildren().requestObject(PEN_OBJECT_NAME, PenTool, false);
			if( _penToolMenuItem.caption == ENABLE_PEN )
			{
				// enable pen
				
				penTool.editMode = true;
				_penToolMenuItem.caption = DISABLE_PEN;
				_removeDrawingsMenuItem.enabled = true;
				CustomCursorManager.showCursor(CustomCursorManager.PEN_CURSOR, CursorManagerPriority.HIGH, -3, -22);
			}
			else
			{
				// disable pen
				penTool.editMode = false;
				
				_penToolMenuItem.caption = ENABLE_PEN;
			}
		}
		
		/**
		 * This function is passed a target and checks to see if the target is an ILinkableContainer.
		 * Either a ILinkableContainer or null will be returned.
		 */
		private static function getLinkableContainer(target:*):*
		{
			var targetComponent:* = target;
			
			while (targetComponent)
			{
				if (targetComponent is ILinkableContainer)
					return targetComponent as ILinkableContainer;
				
				targetComponent = targetComponent.parent;
			}
			
			return targetComponent;
		}
		
		/**
		 * This function occurs when Remove All Drawings is pressed.
		 * It removes the PenMouse object and clears all of the event listeners.
		 */
		private static function handleEraseDrawingsMenuItem(e:ContextMenuEvent):void
		{
			var linkableContainer:ILinkableContainer = getLinkableContainer(e.mouseTarget);
			
			if ( linkableContainer )
				linkableContainer.getLinkableChildren().removeObject( PEN_OBJECT_NAME );
			_penToolMenuItem.caption = ENABLE_PEN;
			_removeDrawingsMenuItem.enabled = false;
		}
	}
}