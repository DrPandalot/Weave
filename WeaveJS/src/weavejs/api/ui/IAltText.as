package weavejs.api.ui
{
	import weavejs.core.LinkableString;

	public interface IAltText
	{
		function get altText():LinkableString;
		altTextMode:LinkableString;
		function updateAltText():void;
	}
}
