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

var FilterJsonState = getCookie("BPView_FilterJsonState");
var FilterJsonHost2 = getCookie("BPView_FilterJsonHost");
var activeDashboard2 = getCookie("BPView_activeDashboard");
var reloadWait;
var popup;
var overviewErrorCount = 0;
var detailsErrorCount = 0;

if (FilterJsonState == null) FilterJsonState = "";
if (FilterJsonHost2 == null) FilterJsonHost = "";
if (activeDashboard2 != null) activeDashboard = activeDashboard2;
if (FilterJsonHost2 != null) FilterJsonHost = FilterJsonHost2;

$(document).ready(function() {

  getDbOverview();
  updateDashSub();

  // get JSON data
  setInterval("getDbOverview()", refreshInterval);

  // close popup windows
  $('.closePopup').click(function(){
        $('.overlayBG').hide();
  });

  jQuery(document).ready(function() {
	jQuery('ul.sf-menu').superfish({
		useClick:     false,
		animation:    {opacity:'show'},
		animationOut: {opacity:'hide'},
		disableHI:    false,
		autoArrows:   true,
                delay:        0000,
                speed:        'fast'
        });
   });

	if (FilterJsonHost != "") {
		$('#hostSearch').replaceWith("<input id=\"hostSearch\" name=\"string\" type=\"text\" size=\"15\" maxlength=\"100\" value=\"" + FilterJsonHost + "\">");
	}

	inputHostEnter();

});



// clickable products
$(document).on('click', 'div.tile', function(){
  // open window only if business process is defined
  // TODO: Better JavaScript check!!!
  if ($(this).attr("class") != "tile state99"){
          gHelperJSON = "";
        var det = getDetails( $(this).attr("id") );

        $.magnificPopup.open({
                items: {
                        src: '<div class="white-popup"><div id="details_subject" class="topBar">' + $(this).attr("title") +'</div><div id="details_data">Data loading ...</div></div>',
                        type: 'inline'
                }
        });
  }
});


function getDbOverview(){
    if (activeDashboard == "dummy") return;
	var dashboard = activeDashboard;
	var watermark = 0;
	var filter = "";
	if (FilterJsonState != "") {
		filter = "&filter=" + FilterJsonState;
	}
	if (FilterJsonHost != "") {
		if (filter == "") filter = "&filter=";
			if (FilterJsonState == "") filter += "name+" + FilterJsonHost;
			else filter += "+name+" + FilterJsonHost;
	}
	$.getJSON( "?json=1&dashboard=" + dashboard + filter, function(data){
		var jsonData = "";
        if (data == 1){
			showErrorMessage();
        }
        $.each(data, function(environment, envval){
			// main environments
            jsonData += "<div class=\"environment\"><div class=\"environmentTitle\">" + environment + "</div>\n";

			var inrow_val;
			var helper_val;
			var helper_keys = Object.keys(envval).length-2;
			var inrow_count = 1;
			$.each(envval, function(topic, topicval){

			if (topic == "__displayorder") return true;// {
				if (topic == "__displayinrow") {
					inrow_val = topicval;
					return true;
				}
				if 	(inrow_count == 1) {

					if (inrow_val == 1) jsonData += "    <div class=\"groupTilesRow\">\n";
					else jsonData += "    <div class=\"groupTilesRow\">\n";
					helper_val = inrow_val;
				}
				var groupTiles;
				switch (inrow_val) {
					case 2:		groupTiles = " groupTilesLeft50"; break;
					case 3:		groupTiles = " groupTilesLeft33"; break;
					case 4:		groupTiles = " groupTilesLeft25"; break;
					case 5:		groupTiles = " groupTilesLeft20"; break;
					default:	groupTiles = ""; break;
				}
				helper_val--; 
				if (helper_val == 0 && inrow_val > 1) groupTiles = " groupTilesRight";
				jsonData += "      <div class=\"groupTiles" + groupTiles + "\">\n      <div class=\"groups\">" + topic + "</div>\n";

				$.each(topicval, function(products, productval){
					// set class for status code
					var statusClass = "state" + productval.state;
					var bpName      = productval.bpname;
					var name		= productval.name;
					var name_short = (name.length > 20) ? name.substr(0,20) + " ..." : name;
					//products
					jsonData += "          <div id=\"" + bpName +"\" class=\"tile " + statusClass + "\" title=\"" + name + "\">" + name_short + "</div>\n";
				});

				jsonData += "    </div>\n";
				if (watermark == 0) watermark = 1;

				helper_keys--;
				if 	(inrow_count == inrow_val) {
					jsonData += "      </div>\n";
					if (helper_keys != 0) jsonData += "      <div class=\"groupTilesRowEmpty\"></div>\n";
					inrow_count = 1;
					 return true;
				}
				if (helper_keys == 0 && inrow_count != inrow_val && inrow_val != 1) {
						inrow_count++;
					while (inrow_count != inrow_val) {
						jsonData += "      <div class=\"groupTilesEmpty" + groupTiles + "\">\n      <div class=\"groups\">&nbsp;</div>\n</div>\n";
						inrow_count++;

					}
					if 	(inrow_count == inrow_val) {
						jsonData += "      <div class=\"groupTilesEmpty groupTilesRight\">&nbsp;</div>\n";
						jsonData += "      </div>\n";
					}					
				}
				inrow_count++;
					
            });
            jsonData += "  </div>\n";
          })
		  // change css to display watermark with BP content
		  if (watermark == 1) $('#watermark').css({"height":"35%"});
          // display error message on empty returns
          if (jsonData == ""){
        	jsonData = "<span style=\"font-size:24px; margin-left: 100px;\">No data returned.</span></br><span style=\"font-size:24px;margin-left: 100px;\">Did you use an active state or host filter?</span>";
          }

          // show last refresh date
          // TODO: Change the date format setting to dynamicly generated based on a config-value (bpview.yml)
          var date = moment().format('DD.MM.YYYY, HH:mm:ss');
          $('#refresh').replaceWith("<div id=\"refresh\">Last refresh: <b>" + date + "</b></div>");

      // create new start page
          $('#bps').empty();
          $('#bps').append(jsonData);

       })
        .fail(function(){
          // Retry fetching data before rising an error
          if (overviewErrorCount <= 2){
        	  // Sleep for 5 seconds
        	  setTimeout("getDbOverview()", 50000)
        	  overviewErrorCount = overviewErrorCount + 1;
          }else{
        	  // Open DIV popup and inform user about error
        	  overviewErrorCount = 0;
        	  showErrorMessage();
          }
        })

}


function getDetails(businessProcess) {
	var filter = "";
        if (FilterJsonState != "") {
                filter = "&filter=" + FilterJsonState;
        }
        if (FilterJsonHost != "") {
                if (filter == "") filter = "&filter=";
                        if (FilterJsonState == "") filter += "name+" + FilterJsonHost;
                        else filter += "+name+" + FilterJsonHost;
        }
	$.getJSON( "?details=" + businessProcess + filter, function(data){
		var jsonData = "";
		
		// error handling
		if (data == 1){
		  showErrorMessage();
		}

		$.each(data, function(host, hostval){

		// did we receive an error message?
		if (host == "error"){
		  showDetailedErrorMessage(hostval);
		  exit;
		}

		// host names
		jsonData += "<table class=\"details\" width=\"100%\">\n";
		jsonData += "  <colgroup>\n    <col class=\"detail_service\">\n    <col class=\"detail_output\">\n    <col class=\"detail_status\">\n  </colgroup>\n";
		jsonData += "<thead><tr><th width=\"100%\" class=\"detail_host\" colspan=\"3\">" + host + "</th></tr></thead>\n";

			$.each(hostval, function(service, serviceval){

			  // service names
			  jsonData += "    <tbody><tr><td class=\"detail_service detail_status_" + serviceval.hardstate + " \"title=\"" + service + "\">" + service + "</td>\n";
			  jsonData += "    <td class=\"detail_output detail_status_" + serviceval.hardstate + "\" title=\"" + serviceval.output + "\">" + serviceval.output + "</td>\n";
			  jsonData += "    <td class=\"detail_status detail_status_" + serviceval.hardstate + "\" title=\"" + serviceval.hardstate + "\">" + serviceval.hardstate + "</td></tr></tbody>\n";
			});

			jsonData += "</table>\n";
	  });
	  // display error message on empty returns
	  if (jsonData == ""){
		jsonData = "<span style=\"font-size:24px; margin-left: 100px;\">No data returned.</span></br><span style=\"font-size:24px;margin-left: 100px;\">Did you use an active state or host filter?</span>";
	  }

  // create new details div
	  $('#details').empty();
	  $('.details').append(jsonData);
	  $('#details_data').empty();
	  $('#details_data').append(jsonData);
	})
	.fail(function(){
        // Retry fetching data before rising an error
        if (detailsErrorCount <= 2){
      	  // Sleep for 5 seconds
      	  setTimeout("getDetails()", 50000)
      	  detailsErrorCount = detailsErrorCount + 1;
        }else{
      	  // Open DIV popup and inform user about error
      	  detailsErrorCount = 0;
      	  showErrorMessage();
        }
	})
}

function showErrorMessage(){

	$.magnificPopup.open({
		enableEscapeKey: false,
		closeOnBgClick: false,
		showCloseBtn: false,
        items: {
		src: '<div class="error-popup"><div id="details_subject" class="topBar">An error occured!</div><div id="details_data" class="details_data_error"><div class="details_data_error_content">Please check error_log of your webserver or try to reload this webapp!<br/><span style="font-size:13px;">&nbsp;<br/>(press &lt;F5\&gt; or &lt;CTRL-R&gt;)</span></div><div class="details_data_error_content_image"><img src="../share/images/global/exclamation_mark_red.png"></div></div></div>',
                type: 'inline'
        }
	});
	deleteCookie();
}

function showDetailedErrorMessage(message){

	$.magnificPopup.open({
		enableEscapeKey: true,
		closeOnBgClick: true,
		showCloseBtn: true,
        items: {
		src: '<div class="error-popup"><div id="details_subject" class="topBar">An error occured!</div><div id="details_data" class="details_data_error"><div class="details_data_error_content">' + message + '</div><div class="details_data_error_content_image"><img src="../share/images/global/exclamation_mark_red.png"></div></div></div>',
                type: 'inline'
        }
	});
}

function showCopyright(){

        $.magnificPopup.open({
                enableEscapeKey: true,
                closeOnBgClick: true,
                showCloseBtn: false,
        items: {
		src: '<div class="error-popup"><div id="details_subject" class="topBar">Copyright</div><div id="details_data" class="details_data_error"><div class="details_data_copyright_content">BPView is Open Source under the terms of the GNU General Public License.<br/>&nbsp;<br/><span style="font-size:14px;">Copyright:<br/>&nbsp;&nbsp;&nbsp;ovido<br/>&nbsp;&nbsp;&nbsp;Peter Stöckl, p.stoeckl@ovido.at</br>&nbsp;&nbsp;&nbsp;Rene Koch, r.koch@ovido.at</span></div><div class="details_data_copyright_content_image"><img src="../share/images/global/bpview_watermark.png" height="76" width="450"></div></div><button title="Close (Esc)" type="button" class="mfp-close" style="color: white;">×</button></div>',
                type: 'inline'
        }
        });
}

function showReload(){

	popup = this;
    $.magnificPopup.open({
            enableEscapeKey: true,
            closeOnBgClick: true,
            showCloseBtn: false,
    items: {
    	src: '<div class="error-popup"><div id="details_subject" class="topBar">Generate and Reload Config</div><div id="details_data" class="details_data_error"><div class="details_data_copyright_content" style="text-aling: center;">Generating configuration and reloading application...<br/>&nbsp;<br/><img src="../share/images/global/ajax-loader.gif"><br /><br /></div><div class="details_data_copyright_content_image"><img src="../share/images/global/bpview_watermark.png" height="76" width="450"></div></div><button title="Close (Esc)" type="button" class="mfp-close" style="color: white;">×</button></div>',
            type: 'inline'
    }
    });
}

function getStatus() {
	$.getJSON("?reload=status", function(data){
		if (data.status != 1){
			// exit loop
			clearInterval(reloadWait);
			
			statusMessage = "<div>" + data.message + "<br /><br /><br /></div>";
	
			$('.details_data_copyright_content').empty();
			$('.details_data_copyright_content').append(statusMessage);
			
		}
	});
}


function reloadconfig() {
	
	var reloadit=confirm("Attention:\n\nA config reload enforce a data import, a config generation, and a reload of BPView. This operation could be decrease the performance from connected systems.\nIf you are unsure cancel the operation.\nDo you want to proceed?");
	
	if (reloadit==true) {
		showReload();
		$.getJSON( "?reload=true", function(data){
			if (data.status == 1){
				// Reload is still in progress - loop
				reloadWait=setInterval("getStatus()", 3000);
			}else{
				statusMessage = "<div>" + data.message + "</div>";
				$('.details_data_copyright_content').empty();
				$('.details_data_copyright_content').append(statusMessage);
			}
		}).fail(function(){
			statusMessage = "<div>An unknown error occured during reload process - please check reload.log!</div>";
			$('.details_data_copyright_content').empty();
			$('.details_data_copyright_content').append(statusMessage);
		})
	}
}

function custom_filter() {
	var s=prompt('Insert your custom search string:\n\nHelp:\n  Possible arguments are: ok, warning, critical, unknown\n  e.g: "warning+unknown" to display these states','');
        if (s == "all") FilterJsonState="";
        else if (s == "" || s == null) FilterJsonState="";
        else FilterJsonState = "state+" + s;
        document.cookie = "BPView_FilterJsonState=" + FilterJsonState;
        getDbOverview();
	updateDashSub();
}

function filterState(state) {
	if (state == "all") FilterJsonState="";
	else FilterJsonState = state;
        document.cookie = "BPView_FilterJsonState=" + FilterJsonState;
	getDbOverview();
	updateDashSub();
}

function changeDash(db) {
        activeDashboard = db;
        document.cookie = "BPView_activeDashboard=" + activeDashboard;
	getDbOverview();
	updateDashSub();
}

function getCookie(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    }
    return null;
}

function updateDashSub() {
	var dashb = activeDashboard;
	var filters = "<span style=\"color: rgb(160,160,160);\">No Filters activated</span>";
        if (FilterJsonState != "" || FilterJsonHost != "") {
		filters = "<span style=\"color: rgb(78,238,148);\">Filters: ";
		if (FilterJsonState.search(/warning/) != -1) filters += "W ";
		if (FilterJsonState.search(/unknown/) != -1) filters += "U ";
		if (FilterJsonState.search(/critical/) != -1) filters += "C ";
		if (FilterJsonState.search(/ok/) != -1) filters += "OK ";
		filters += "</span>";
	        if (FilterJsonHost != "") filters += "<span style=\"color: rgb(255,127,36);\" title=\"" + FilterJsonHost  + "\">+ HOST</<span>";
        }
	var data = "<span style=\"color: rgb(250,250,250);\">Dashboard: \"" + dashb  + "\"</span></br>" + filters;
	$(function() {	
		$('.dashboard_subject').replaceWith("<div class=\"dashboard_subject\">" + data + "</div>");
	});
}

function clearHostFilter() {
	$(function() {
                $('#hostSearch').replaceWith("<input id=\"hostSearch\" name=\"string\" type=\"text\" size=\"15\" maxlength=\"100\" value=\"\">");
		document.cookie = "BPView_FilterJsonHost=; expires=Thu, 01 Jan 1970 00:00:01 GMT;";
		FilterJsonHost = "";
		getDbOverview();
		updateDashSub();
		inputHostEnter();
	});
}

function inputHostEnter() {
	$('#hostSearch').bind("enterKey",function(e) {
		FilterJsonHost = $('#hostSearch').val();
		getDbOverview();
		updateDashSub();
		$('#hostSearch').change(FilterJsonHost);
		document.cookie = "BPView_FilterJsonHost=" + FilterJsonHost;
	});
	$('#hostSearch').keyup(function(e) {
		if(e.keyCode == 13) {
		$(this).trigger("enterKey");
		}
	});

}

function deleteCookie() {
	document.cookie = "BPView_FilterJsonHost=; expires=Thu, 01 Jan 1970 00:00:01 GMT;";
	document.cookie = "BPView_FilterJsonState=; expires=Thu, 01 Jan 1970 00:00:01 GMT;";
	document.cookie = "BPView_activeDashboard=; expires=Thu, 01 Jan 1970 00:00:01 GMT;";
}
