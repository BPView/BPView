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
          gHelperJSON = "";
        var det = getDetails( $(this).attr("id") );

        $.magnificPopup.open({
                items: {
                        src: '<div class="white-popup"><div id="details_subject" class="topBar">' + $(this).attr("title") +'</div><div id="details_data">Data loading ...</div></div>',
                        type: 'inline'
                }
        });
        //    window.open('?details=' + $(this).attr("id"), '_blank', "width=700,height=500,location=no,status=no" )
  }
});


function getDbOverview(){
	var dashboard = $("#dashboards option:selected").val();
	$.getJSON( "?dashboard=" + dashboard, function(data){
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
				console.log(helper_keys/inrow_val);				

					if (inrow_val == 1) jsonData += "    <div class=\"groupTilesRow\">\n";
//					else if  (helper_keys/inrow_val < 1) jsonData += "    <div class=\"groupTilesRow2\">\n";
					else jsonData += "    <div class=\"groupTilesRow\">\n";
					helper_val = inrow_val;
				}
				var groupTiles;
				switch (inrow_val) {
					case 2:		groupTiles = " groupTilesLeft50"; break;
					case 3:		groupTiles = " groupTilesLeft33"; break;
					case 4:		groupTiles = " groupTilesLeft25"; break;
					default:	groupTiles = ""; break;
				}
				helper_val--; 
				if (helper_val == 0 && inrow_val > 1) groupTiles = " groupTilesRight";
				jsonData += "      <div class=\"groupTiles" + groupTiles + "\">\n      <div id=\"" + topic + "\" class=\"groups\">" + topic + "</div>\n";

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
//					if (inrow_count == inrow_val) continue;
						jsonData += "      <div class=\"groupTilesEmpty" + groupTiles + "\">\n      <div class=\"groups\">&nbsp;</div>\n</div>\n";
						inrow_count++;

					}
					if 	(inrow_count == inrow_val) {
						jsonData += "      <div class=\"groupTilesEmpty groupTilesRight\">&nbsp;</div>\n";
						jsonData += "      </div>\n";
//						inrow_count = -1;
					}					
				}
				inrow_count++;
					
            });
//while (inrow_count != inrow_val && )




            jsonData += "  </div>\n";
          })

          // display error message on empty returns
          if (jsonData == ""){
        	showErrorMessage();
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
          // Open DIV popup and inform user about error
          showErrorMessage();
        })

}


function getDetails(businessProcess) {
        $.getJSON( "?details=" + businessProcess, function(data){
            var jsonData = "";
            
            // error handling
            if (data == 1){
              showErrorMessage();
            }


            
            $.each(data, function(host, hostval){

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
        	showErrorMessage();
          }

      // create new details div
          $('#details').empty();
          $('.details').append(jsonData);
          $('#details_data').empty();
          $('#details_data').append(jsonData);
        })
        .fail(function(){
          // Open DIV popup and inform user about error
          showErrorMessage();
        })
}

function showErrorMessage(){

	$.magnificPopup.close();
	$.magnificPopup.open({
		enableEscapeKey: false,
		closeOnBgClick: false,
		showCloseBtn: false,
        items: {
				src: '<div class="error-popup"><div id="details_subject" class="topBar">An error occured!</div><div id="details_data" class="details_data_error"><div class="details_data_error_content">Please check error_log of your webserver or try to reload this webapp!<br/><span style="font-size:13px;">&nbsp;<br/>(press &lt;F5\&gt; or &lt;CTRL-R&gt;)</span></div><div class="details_data_error_content_image"><img src="../share/images/global/exclamation_mark_red.png"></div></div</div>',
                type: 'inline'
        }
	});
}

function reloadconfig() {
	var reloadit=confirm("Attention:\n\nA config reload enforce a data import, a config generation, and a reload of BPView. This operation could be decrease the performance from connected systems.\nIf you are unsure cancel the operation.\nDo you want to proceed?");
	if (reloadit==true) {
		var Address = 'bpview.pl?reloadit=yes&reloadnow=yes&round=0';
		$.magnificPopup.open({
			enableEscapeKey: false,
			closeOnBgClick: false,
			showCloseBtn: false,
			markup: '<div class="mfp-iframe-scaler">'+
				'<iframe class="mfp-iframe" frameborder="0" allowfullscreen></iframe>'+
			  '</div>',
			items: {
				src: Address
			},
			type: 'iframe'
		});
	}
}
