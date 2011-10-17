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

package weave.visualization.plotters
{
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.getClassByAlias;
	import flash.utils.Dictionary;
	
	import weave.Weave;
	import weave.api.WeaveAPI;
	import weave.api.core.ILinkableObject;
	import weave.api.data.IQualifiedKey;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.compiler.StandardLib;
	import weave.core.ErrorManager;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableNumber;
	import weave.data.AttributeColumns.BinnedColumn;
	import weave.data.AttributeColumns.ColorColumn;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.primitives.Bounds2D;
	import weave.primitives.ColorRamp;
	import weave.utils.BitmapText;
	import weave.utils.LegendUtils;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	/**
	 * This plotter displays a legend for a ColorColumn.  If the ColorColumn contains a BinnedColumn, a list of bins
	 * with their corresponding colors will be displayed.  If not a continuous color scale will be displayed.  By
	 * default this plotter links to the static color column, but it can be linked to another by changing or removing
	 * the dynamicColorColumn.staticName value.
	 * 
	 * @author adufilie
	 */
	public class ColorBinLegendPlotter extends AbstractPlotter
	{
		public function ColorBinLegendPlotter()
		{
			init();
		}
		private function init():void
		{
			dynamicColorColumn.globalName = Weave.DEFAULT_COLOR_COLUMN;
			
			setKeySource(dynamicColorColumn);
			
			for each (var child:ILinkableObject in [
				Weave.properties.axisFontSize,
				Weave.properties.axisFontColor,
				Weave.properties.axisFontFamily,
				Weave.properties.axisFontItalic,
				Weave.properties.axisFontUnderline,
				Weave.properties.axisFontBold])
			{
				registerLinkableChild(this, child);
			}
		}
		
		/**
		 * This plotter is specifically implemented for visualizing a ColorColumn.
		 * This DynamicColumn only allows internal columns of type ColorColumn.
		 */
		public const dynamicColorColumn:DynamicColumn = registerSpatialProperty(new DynamicColumn(ColorColumn), createHashMaps);
		
		/**
		 * This accessor function provides convenient access to the internal ColorColumn.
		 * The public session state is defined by dynamicColorColumn.
		 */
		public function get internalColorColumn():ColorColumn
		{
			return dynamicColorColumn.internalColumn as ColorColumn;
		}
		
		/**
		 * This is the radius of the circle, in screen coordinates.
		 */
		public const shapeSize:LinkableNumber = registerLinkableChild(this, new LinkableNumber(20));
		/**
		 * This is the line style used to draw the outline of the shape.
		 */
		public const lineStyle:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		
		public const maxColumns:LinkableNumber = registerSpatialProperty(new LinkableNumber(1), createHashMaps);
		public const reverseOrder:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false), createHashMaps);

		private const _binsOrdering:Array = [];
		private var _binToBounds:Dictionary = new Dictionary();
		private var _binToString:Dictionary = new Dictionary();
		public var numBins:int = 0;
		private function createHashMaps():void
		{
			_binsOrdering.length = 0;
			_binToString = new Dictionary();
			_binToBounds = new Dictionary();
			
			var keys:Array = keySet.keys;
			var binnedColumn:BinnedColumn = internalColorColumn.internalColumn as BinnedColumn;
			if (binnedColumn == null)
			{
				numBins = 0;
				return;
			}
			
			var bins:Array = binnedColumn.derivedBins.getObjects();
			numBins = bins.length;
			var maxCols:int = maxColumns.value;
			if (maxCols <= 0)
				maxCols = 1;
			if (maxCols > numBins)
				maxCols = numBins;
			var blankBins:int = numBins % maxCols;
			var fakeNumBins:int = (blankBins > 0) ? maxCols - blankBins : 0; // invisible bins which should be put in the lower right 
			var maxNumBins:int = numBins + fakeNumBins;
			for (var iBin:int = 0; iBin < numBins; ++iBin)
			{
				// get the adjusted position and transpose inside the row
				var adjustedIBin:int = (reverseOrder.value) ? (maxNumBins - 1 - iBin) : (fakeNumBins + iBin);
				var row:int = adjustedIBin / maxCols;
				var col:int = adjustedIBin % maxCols;
				var b:IBounds2D = new Bounds2D();
				_binsOrdering.push(bins[iBin]);
				
				LegendUtils.getBoundsFromItemID(getBackgroundDataBounds(), adjustedIBin, b, maxNumBins, maxCols, true);
				
				_binToBounds[iBin] = b;
				_binToString[iBin] = binnedColumn.deriveStringFromNumber(iBin);
			}
		}
		
		private var _drawBackground:Boolean = false; // this is used to check if we should draw the bins with no records.
		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			// draw the bins that have no records in them in the background
			_drawBackground = true;
			drawBinnedPlot(keySet.keys, dataBounds, screenBounds, destination);
			_drawBackground = false;
		}

		override public function drawPlot(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			if (internalColorColumn == null)
				return; // draw nothing
			if (internalColorColumn.internalColumn is BinnedColumn)
				drawBinnedPlot(recordKeys, dataBounds, screenBounds, destination);
			else
				drawContinuousPlot(recordKeys, dataBounds, screenBounds, destination);
		}
			
		protected function drawContinuousPlot(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			//todo
		}
		
		protected function drawBinnedPlot(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			if (internalColorColumn == null)
				return;
			
			var binnedColumn:BinnedColumn = internalColorColumn.internalColumn as BinnedColumn;
			if (binnedColumn == null)
				return;
			
			screenBounds.getRectangle(_clipRectangle);
			var g:Graphics = tempShape.graphics;
			g.clear();
			lineStyle.beginLineStyle(null, g);
			
			// convert record keys to bin keys
			// save a mapping of each bin key found to a value of true
			var binIndexMap:Dictionary = new Dictionary();
			for (var i:int = 0; i < recordKeys.length; i++)
				binIndexMap[ binnedColumn.getValueFromKey(recordKeys[i], Number) ] = 1;
			
			var margin:int = 4;
			var height:Number = screenBounds.getYCoverage() / dataBounds.getYCoverage();			
			var actualShapeSize:int = Math.max(7, Math.min(shapeSize.value, height - margin));
			var iconGap:Number = actualShapeSize + margin * 2;
			var circleCenterOffset:Number = margin + actualShapeSize / 2; 
			var internalMin:Number = WeaveAPI.StatisticsCache.getMin(internalColorColumn.internalDynamicColumn);
			var internalMax:Number = WeaveAPI.StatisticsCache.getMax(internalColorColumn.internalDynamicColumn);
			var internalColorRamp:ColorRamp = internalColorColumn.ramp;
			var binCount:int = binnedColumn.derivedBins.getObjects().length;
			for (var iBin:int = 0; iBin < binCount; ++iBin)
			{
				// if _drawBackground is set, we should draw the bins that have no records in them.
				if ((_drawBackground?0:1) ^ int(binIndexMap[iBin])) // xor
					continue;
				
				var binBounds:IBounds2D = _binToBounds[iBin];
				tempBounds.copyFrom(binBounds);
				dataBounds.projectCoordsTo(tempBounds, screenBounds);
//				tempBounds.makeSizePositive();
				
				// draw almost invisible rectangle for probe filter
				tempBounds.getRectangle(tempRectangle);
				destination.fillRect(tempRectangle, 0x02808080);
				
				// draw the text
				LegendUtils.renderLegendItemText(
					destination, _binToString[iBin], tempBounds, iconGap, _clipRectangle
				);

				// draw circle
				var iColorIndex:int = reverseOrder.value ? iBin : (binCount - 1 - iBin);
				var color:Number = internalColorRamp.getColorFromNorm(StandardLib.normalize(iBin, internalMin, internalMax));
				var xMin:Number = tempBounds.getXNumericMin(); 
				var yMin:Number = tempBounds.getYNumericMin();
				var xMax:Number = tempBounds.getXNumericMax(); 
				var yMax:Number = tempBounds.getYNumericMax();
				if (color <= Infinity) // alternative is !isNaN()
					g.beginFill(color, 1.0);
				g.drawCircle(circleCenterOffset + xMin, (yMin + yMax) / 2, actualShapeSize / 2);
			}
			destination.draw(tempShape);
		}
		private const _clipRectangle:Rectangle = new Rectangle();
		
		
		// reusable temporary objects
		private const tempPoint:Point = new Point();
		private const tempBounds:IBounds2D = new Bounds2D();
		private const tempRectangle:Rectangle = new Rectangle();
		
		private var XMIN:Number = 0, XMAX:Number = 1;
		
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey):Array
		{
			var binnedColumn:BinnedColumn = internalColorColumn.internalColumn as BinnedColumn;
			if (binnedColumn)
			{
				var index:Number = binnedColumn.getValueFromKey(recordKey, Number);
				var b:IBounds2D = _binToBounds[index];
				if (b)
					return [ b ];
			}
			
			return [ getReusableBounds() ];
		}
		
		override public function getBackgroundDataBounds():IBounds2D
		{
			return getReusableBounds(0, 0, 1, 1);
		}
	}
}
