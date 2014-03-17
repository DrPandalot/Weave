/*
 *
 * Analysis Service which handle all data services for the analysis tab
 *
 */

angular.module('aws.analysisService', [])
.service('steps1_2_service',['queryService', function(queryService){
    
    
    
       
}])
.service('dasboard_widget_service', ['$filter',
function($filter) {

	var tool_list = [{

		id : 'GeographyFilter',
		title : 'Geography Filter',
		template_url : 'aws/visualization/data_filters/geography.tpl.html',
		description : 'Filter display data based on places',
		note: 'This filter will limit its options if the scipt computes on a list subset',
		category : 'datafilter'

	}, {
		id : 'BarChartTool',
		title : 'Bar Chart Tool',
		template_url : 'aws/visualization/tools/barChart/bar_chart.tpl.html',
		description : 'Display a Bar Chart in Weave',
		category : 'visualization'

	}, {
		id : 'MapTool',
		title : 'Map Tool',
		template_url : 'aws/visualization/tools/mapChart/map_chart.tpl.html',
		description : 'Display Map in Weave',
		category : 'visualization'
	}, {
		id : 'DataTableTool',
		title : 'Data Table Tool',
		template_url : 'aws/visualization/tools/dataTable/data_table.tpl.html',
		description : 'Display a Data Table in Weave',
		category : 'visualization'
	}, {
		id : 'ScatterPlotTool',
		title : 'Scatter Plot Tool',
		template_url : 'aws/visualization/tools/scatterPlot/scatter_plot.tpl.html',
		description : 'Display a Scatter Plot in Weave',
		category : 'visualization'
	}];

	/*Model to hold the widgets that are being displayed in dashboard*/
	var widget_bricks = [];

	this.get_widget_bricks = function() {

		return widget_bricks;
	};

	this.add_widget_bricks = function(element_id) {

		var widget_id = element_id;
		var widget_brick_found = $filter('filter')(widget_bricks, {
			id : widget_id
		})
		if (widget_brick_found.length == 0) {
			var tool = $filter('filter')(tool_list, {
				id : widget_id
			});
			widget_bricks.splice(0, 0, tool[0]);
		} else {
			//TODO: Hightlight the div if already added to dashboard. Use ScrollSpy
		}
	};

	this.remove_widget_bricks = function(widget_index) {

		widget_bricks.splice(widget_index, 1);

	};

	this.get_tool_list = function(category) {

			return $filter('filter')(tool_list, {
				category : category
			});

	};
}]);

