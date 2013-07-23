/*
 * COPYRIGHT:
 * 
 * This software is Copyright (c) 2013 by ovido
 *                              <sales@ovido.at>
 *
 * This file is part of Business Process View (BPView).
 * 
 * (Except where explicitly superseded by other copyright notices)
 * BPView is free software: you can redistribute it and/or modify it 
 * under the terms of the GNU General Public License as published by 
 * the Free Software Foundation, either version 3 of the License, or 
 * any later version.
 * 
 * BPView is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with BPView. 
 * If not, see <http://www.gnu.org/licenses/>.
 */


$(document).ready(function() {
	
 $('#dashboards').change(function() {
    // get JSON data
	getDbOverview();
  })
  .trigger('change');

  // get JSON data
  setInterval("getDbOverview()", refreshInterval);
  
  // close popup windows
  $('.closePopup').click(function(){
	$('.overlayBG').hide();
  });
});


// clickable products
$(document).on('click', 'div.tile', function(){
  // open window only if business process is defined
  // TODO: Better JavaScript check!!!
  if ($(this).attr("class") != "tile state99"){
	getDetails( $(this).attr("id") );
//    window.open('?details=' + $(this).attr("id"), '_blank', "width=700,height=500,location=no,status=no" )
  }
});
  
  
function getDbOverview(){
	var dashboard = $("#dashboards option:selected").val();
	$.getJSON( "?dashboard=" + dashboard, function(data){
  	  var jsonData = "";
	  $.each(data, function(environment, envval){
		
	    // main environments
  	    jsonData += "<div class=\"environment\">" + environment + "</div>\n";
  	    
		$.each(envval, function(groups, groupval){
			
		  // product groups
//		  jsonData += "  <div class=\"groups\">" + groups + "</div>\n";
		  jsonData += "    <div class=\"groupTiles\"><div class=\"groups\">" + groups + "</div>\n";
			  
		  $.each(groupval, function(products, productval){
			  
			// set class for status code
			var statusClass = "state" + productval.state;
			var bpName      = productval.bpname;
			  
			//products
		    jsonData += "      <div id=\"" + bpName +"\" class=\"tile " + statusClass + "\">" + products + "</div>\n";
		    
		  });
			  
		jsonData += "    </div>\n";
		
		});
			
	  });
	  
	  // display error message on empty returns
	  if (jsonData == ""){
		$('.overlayBG').show();
	  }
	  
	  // show last refresh date
	  var date = new Date();
//	  jsonData += "<div>&nbsp;</div>";
//	  jsonData += "<div>Last refresh: " + date + "</div>";
		
      // create new start page
	  $('#bps').empty();
	  $('#bps').append(jsonData);
	  
	})
	.fail(function(){ 
	  // Open DIV popup and inform user about error
	  console.log("fail");
	  $('.overlayBG').show();
	})
	.done(function(){ 
	  console.log("done"); 
	})	
	
}


function getDetails(businessProcess) {
	$.getJSON( "?details=" + businessProcess, function(data){
  	  var jsonData = "";
	  $.each(data, function(host, hostval){
		
	    // host names
  	    jsonData += "<div><div class=\"host\">" + host + "</div>\n";
  	    
		$.each(hostval, function(service, serviceval){
			
		  // service names
		  jsonData += "    <div><div class=\"service\">" + service + "</div>\n";
		  jsonData += "    <div class=\"status\">" + serviceval.hardstate + "</div>\n";
		  jsonData += "    <div class=\"output\">" + serviceval.output + "</div></div>\n";
			  
		});
		
		jsonData += "    </div>\n";
			
	  });
	  
	  // display error message on empty returns
	  if (jsonData == ""){
		$('.overlayBG').show();
	  }
	  
      // create new details div
	  $('#details').empty();
	  $('#details').append(jsonData);
	  
	})
	.fail(function(){ 
	  // Open DIV popup and inform user about error
	  console.log("fail");
	  $('.overlayBG').show();
	})
	.done(function(){ 
	  console.log("done"); 
	})
}
