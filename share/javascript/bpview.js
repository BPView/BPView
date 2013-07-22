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
  setInterval("getDbOverview()", 15000);
});


// clickable products
$(document).on('click', 'div.tile', function(){
  // open window only if business process is defined
  // TODO: Better JavaScript check!!!
  if ($(this).attr("class") != "tile state99"){
    window.open('?details=' + $(this).attr("id"), '_blank', "width=700,height=500,location=no,status=no" )
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
	  
	  // show last refresh date
	  var date = new Date();
	  jsonData += "<div>&nbsp;</div>";
	  jsonData += "<div>Last refresh: " + date + "</div>";
		
      // create new start page
	  $('#bps').empty();
	  $('#bps').append(jsonData);
	  
	})
	.fail(function(){ console.log("fail"); })		// TODO: Error handling!
	.done(function(){ console.log("done"); })
	
}