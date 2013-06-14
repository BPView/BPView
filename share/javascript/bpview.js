


$(document).ready(function() {

  $('#dashboards').change(function() {
    // get JSON data
	var dashboard = $("#dashboards option:selected").val();
	var jsonData = $.getJSON( "?data=" + dashboard, function(data){
	  console.log("success");
	  $.each(data, function(i,data){
		alert (data.sepp);
	  })
	})
	.done(function(){ console.log("done"); })
	.fail(function(){ console.log("fail"); })
	.always(function(){ console.log("always"); });
	
//	$('#bps').empty();
//	$('#bps').append(jsonData);
  })
  .trigger('change');

});