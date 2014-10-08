package weave.data.DataSources
{
	import flash.net.URLRequest;
	
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	import weave.*;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.newLinkableChild;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.core.SessionManager;
	import weave.data.CSVParser;
	import weave.data.KeySets.KeySet;
	import weave.primitives.DateRangeFilter;
	import weave.services.InfoMapAdminInterface;
	import weave.utils.DateUtils;
	import weave.utils.VectorUtils;

	public class InfoMapsDataSource extends CSVDataSource
	{
		public function InfoMapsDataSource()
		{
			solrURL.value = "http://209.204.119.180:8080/solr/demo/";
			setCSVDataString("url,title,imgURL,date_published,date_added");
			keyColName.value = "url";
			keyType.value = "infoMapsDoc";
			
			(WeaveAPI.SessionManager as SessionManager).excludeLinkableChildFromSessionState(this,csvData);
			(WeaveAPI.SessionManager as SessionManager).excludeLinkableChildFromSessionState(this,keyColName);
			(WeaveAPI.SessionManager as SessionManager).excludeLinkableChildFromSessionState(this,keyType);
		}
		
		public const solrURL:LinkableString = newLinkableChild(this,LinkableString);
		
		public static const DOC_KEYTYPE:String = "infoMapsDoc";
		
		public static const SOURCE_NAME:String = "InfoMaps Data Source";
		
		public static const defaultNumberOfDocumentsPerRequest:int = 2000;
		
		public function containsDoc(key:IQualifiedKey):Boolean
		{
			var title:String = getTitleForKey(key);
			
			if(title)
				return true;
			else 
				return false;
		}
		
		private function getKeyValueForColumn(csvColumnName:String,key:IQualifiedKey):*
		{
			var col:IAttributeColumn = getColumnById(csvColumnName);
			
			return col.getValueFromKey(key);
		}
		
		public function getTitleForKey(key:IQualifiedKey):String
		{
			return getKeyValueForColumn("title",key) as String;
		}
		
		public function getDescriptionForKey(key:IQualifiedKey):String
		{
			return getKeyValueForColumn("description",key) as String;
		}
		
		public function getImageURLForKey(key:IQualifiedKey):String
		{
			return getKeyValueForColumn("imgURL",key) as String;
		}
		
		public function getDatePublishedForKey(key:IQualifiedKey):String
		{
			return getKeyValueForColumn("date_published",key) as String;
		}
		
		public function getDateAddedForKey(key:IQualifiedKey):String
		{
			return getKeyValueForColumn("date_added",key) as String;
		}
		
		
		private function getColumnValueForURL(csvColumnName:String,url:String):*
		{
			var col:IAttributeColumn = getColumnById(csvColumnName);
			
			var key:IQualifiedKey = WeaveAPI.QKeyManager.getQKey(DOC_KEYTYPE,url);
			
			return col.getValueFromKey(key);
		}
		
		public function getTitleForURL(url:String):String
		{
			return getColumnValueForURL("title",url) as String;
		}
		
		public function getDescriptionForURL(url:String,keywords:Array):AsyncToken
		{
			var q:AsyncToken = InfoMapAdminInterface.instance.getDescriptionForURL(url,keywords);
			
			return q;
		}
		
		public function getSourceForURL(url:String):AsyncToken
		{
			var q:AsyncToken = InfoMapAdminInterface.instance.getSourceForURL(url);
			
			return q;
		}
		
		
		public function getImageURLForURL(url:String):String
		{
			return getColumnValueForURL("imgURL",url) as String;
		}
		
		public function getDatePublishedForURL(url:String):String
		{
			return getColumnValueForURL("date_published",url) as String;
		}
		
		public function getDateAddedForURL(url:String):String
		{
			return getColumnValueForURL("date_added",url) as String;
		}
		
//		public function queryDataSources(queryTerms:Array):void
//		{
//			InfoMapAdminInterface.instance.queryDataSources(queryTerms);
//		}
		
		public function getWordCount(query:String,sources:String,
									 dateFilter:DateRangeFilter,sortBy:String):AsyncToken
		{
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.getWordCount(query,dateFilterString,sources,sortBy);
			
			return q;
		}
		
		public function getNumOfDocumentsForQuery(query:String,
												  dateFilter:DateRangeFilter,sources:String):AsyncToken
		{
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.getNumOfDocumentsForQuery(query,dateFilterString,sources);
			
			return q;
		}
		
		public function getDocumentsForQueryWithRelatedKeywords(query:String,sources:String,
																dateFilter:DateRangeFilter,numberOfRequestedDocuments:int,sortyBy:String):AsyncToken
		{
			
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.getResultsForQueryWithRelatedKeywords(query,dateFilterString,
																			numberOfRequestedDocuments,sources,sortyBy);
			return q;
			
		}
		public function getClustersForQueryString(query:String,sources:String,
															   sortBy:String,dateFilter:DateRangeFilter=null,numberOfRequestedDocuments:int=2000):AsyncToken
		{
			
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.getClustersForQueryString(query,
				dateFilterString,numberOfRequestedDocuments,sources,sortBy);
			return q;
			
		}
		
		public function getClustersForQueryWithRelatedKeywords(requiredKeywords:Array,relatedKeywords:Array,operator:String,sources:String,
															   sortBy:String,dateFilter:DateRangeFilter=null,numberOfRequestedDocuments:int=2000):AsyncToken
		{
			
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.getClustersForQueryWithRelatedKeywords(requiredKeywords,relatedKeywords,
				dateFilterString,numberOfRequestedDocuments,operator,sources,sortBy);
			return q;
			
		}
		
		public function classifyDocumentsForQuery(query:String,sources:String,sortBy:String,
												 dateFilter:DateRangeFilter=null,numberOfRequestedDocuments:int=2000,numOfTopics:int=5,
												 numOfKeywords:int=5):AsyncToken
		{
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.classifyDocumentsForQuery(query,
				dateFilterString,numberOfRequestedDocuments,sources,sortBy,numOfTopics,numOfKeywords);
			
			return q;
		}
		
		public function getLinksForFilteredQuery(query:String,dateFilter:DateRangeFilter,
												 filterTerms:Array,rows:int,sources:String,sortBy:String):AsyncToken
		{
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.getLinksForFilteredQuery(query,dateFilterString,
				filterTerms,rows,sources,sortBy);
			
			return q;
		}
		
		public function getEntityDistributionForQuery(query:String, entities:Array,sources:String,
													  dateFilter:DateRangeFilter,numberOfRequestedDocuments:int,sortBy:String):AsyncToken
		{
			var dateFilterString:String = DateUtils.getDateFilterStringForSolr(dateFilter);
			
			var q:AsyncToken = InfoMapAdminInterface.instance.getEntityDistributionForQuery(query,
				dateFilterString,entities,numberOfRequestedDocuments,sources,sortBy);
			
			return q;
			
		}
		
		/**
		 * This function takes a query and adds a filter to restrict by field values 
		 * @param query The query string
		 * @param fieldsNames The field names to filter on
		 * @param fieldValues This is a 2D array because each fieldName can have multiple values. Each array in a row corresponds to the field name in the fieldNames array. 
		 * @param operator
		 * @param dateFilter
		 * @param numberOfDocuments
		 * 
		 */		
//		public function getDocumentsForQueryWithFieldValues(docKeySet:KeySet,query:String,fieldsNames:Array,fieldValues:Array,sources:Array,operator:String='AND',dateFilter:DateRangeFilter=null,numberOfDocuments:int=2000,partialMatch:Boolean=false):void
//		{
//			if(fieldsNames.length == 0)
//				return;
//			
//			var filteredQuery:String = "";
//			
//			for (var i:int=0; i< fieldsNames.length; i++)
//			{
//				filteredQuery += fieldsNames[i] + ":(";
//				for(var j:int=0; j <fieldValues[i].length; j++)
//				{
//					//replacing $amp; with &
////					var val:String = (fieldValues[i][j] as String).replace( /\&amp\;/g,'&');
//					
////					var val:String = (fieldValues[i][j] as String).replace( /\&amp\;/g,'%26');
////					val = val.replace( /\:/g,'\:');
//					
//					//encoding the fieldValues in case it is a link
//					//TODO: need to test how this might affect non-link text
//					//val = escape(val);
//					
//					
//					
//					filteredQuery += '"' + fieldValues[i][j] + '" ' + "OR" + ' ';
//				}
//				filteredQuery = filteredQuery.substr(0,filteredQuery.length-(4));
//				filteredQuery += ") AND ";
//			}
//			
//			//removing the last AND
//			filteredQuery = filteredQuery.substr(0,filteredQuery.length-(5));
//			
//			var queryTerms:Array = query.split(" ");
//			
//			createAndSendQuery(docKeySet,null,queryTerms,filteredQuery,operator,sources,dateFilter,numberOfDocuments);
//		}
		
		private static function parseFilterQuery(filterQuery:String,dateFilter:DateRangeFilter=null,sources:Array=null):String
		{
			if(!filterQuery)
				filterQuery = "";
			
			var fq:String = "";
			if(sources)
			{
				fq = "source:(";
				
				for each(var sourceName:String in sources)
				{
					fq += '"'+sourceName+'" OR ';
				}
				
				fq = fq.substr(0,fq.length-4);
				fq = fq + ')';	
			}
			
			if(filterQuery && fq)
				filterQuery += ' AND ' + fq;
			else if(fq)
				filterQuery = fq;
			
			
			var dateFilterString:String = "";
			
			//applying date filters if set
			if(dateFilter)
			{
				if(dateFilter.startDate.value != '' && dateFilter.endDate.value != '')
				{
					
					var sDate:Date = DateUtils.getDateFromString(dateFilter.startDate.value);
					var eDate:Date = DateUtils.getDateFromString(dateFilter.endDate.value);
					
					
					//Solr requires the date format to be ISO 8601 Standard Compliant
					//It should be in the form: 1995-12-31T23:59:59Z 
					var sStr:String = DateUtils.getDateInStringFormat(sDate,'YYYY-MM-DD');
					
					//For start date we append 00:00:00 to set time to start of the day
					sStr = sStr + 'T00:00:00Z';
					
					var eStr:String = DateUtils.getDateInStringFormat(eDate,'YYYY-MM-DD');
					
					//For end date we append 23:59:59 to set time to end of day
					eStr = eStr + 'T23:59:59Z';
					
					dateFilterString = "date_added:["+sStr+" TO "+eStr + "]";
				}
			}
			
			if(dateFilterString && filterQuery)
				filterQuery = filterQuery + ' AND ' + dateFilterString;
			else if(dateFilterString)
				filterQuery = dateFilterString;
			
			return filterQuery;
		}
		
		private function handleQueryResults(event:ResultEvent,token:Object=null):void
		{
			var docsArray:Array = event.result.queryResult as Array;
			var docsToAdd:Array = [];
			var keys:Array = [];
			
			var urlCol:IAttributeColumn = getColumnById('url'); 
			
			for (var i:int = 0; i < docsArray.length; i++)
			{
				var link:String = docsArray[i][0];
				
				var key:IQualifiedKey = WeaveAPI.QKeyManager.getQKey("infoMapsDoc",link);
				
				//if the key is already present in the column, then we only add it to the keys keyset
				//we will not add the currentDoc to the docsArray, this way the rows are not repeated in the csvDataString
				if(urlCol.containsKey(key))
				{
					keys.push(link);
					continue;
				}
				
				docsToAdd.push(docsArray[i]);
				
				keys.push(link);
			}
			
			csvData.setSessionState((csvData.getSessionState() as Array).concat(docsToAdd));			
			
			if(!event.result.wordCount || !token)
				return;
			
			VectorUtils.copy(event.result.wordCount,token.wordCount);
			
			
			//			(token.keySet as KeySet).clearKeys();
			(token.docKeySet as KeySet).replaceKeys(WeaveAPI.QKeyManager.getQKeys("infoMapsDoc",keys));
			// we force to trigger callbacks so that if a empty keyset is replaced with empty keys the callbacks are still called
			(token.docKeySet as KeySet).triggerCallbacks(); 
			if(token.numberOfMatchedDocuments)
				(token.numberOfMatchedDocuments as LinkableNumber).value = event.result.totalNumberOfDocuments;  
		}
		
		
		private function handleQueryFault(event:FaultEvent,token:Object=null):void
		{
			return;
		}
		public function startIndexing():void
		{
			WeaveAPI.URLRequestUtils.getURL(this,new URLRequest(solrURL.value + "select?&clean=false&commit=true&qt=%2Fdataimport&command=full-import"));
		}
		
		private function handleSolrResponseError(event:FaultEvent,token:Object):void
		{
			WeaveAPI.ErrorManager.reportError(event.type + token.url);
		}
		
		private var parser:CSVParser = new CSVParser();
		
		private static function removeEmptyStringElementsFromArray(arg:Array):Array
		{
			var result:Array = [];
			for each(var item:String in arg)
			{
				if(item != "")
					result.push(item);
			}
			
			return result;
		}
	}
	
}