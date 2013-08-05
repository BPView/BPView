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
          $.each(data, function(environment, envval){

            // main environments
            jsonData += "<div class=\"environment\">" + environment + "\n";

                $.each(envval, function(groups, groupval){

                  // product groups
//                jsonData += "  <div class=\"groups\">" + groups + "</div>\n";
                  jsonData += "    <div class=\"groupTiles\"><div id=\"" + groups + "\" class=\"groups\">" + groups + "</div>\n";

                  $.each(groupval, function(products, productval){

                        // set class for status code
                        var statusClass = "state" + productval.state;
                        var bpName      = productval.bpname;



                        var products_short = (products.length > 20) ? products.substr(0,20) + " ..." : products;




                        //products
                    jsonData += "      <div id=\"" + bpName +"\" class=\"tile " + statusClass + "\" title=\"" + products + "\">" + products_short + "</div>\n";
                    //?details=" + $(this).attr("id") + "\


                        //products
//                  jsonData += "      <div id=\"" + bpName +"\" class=\"tile " + statusClass + "\">" + products + "</div>\n";

                  });

                jsonData += "    </div>\n";

                });
                jsonData += "  </div>\n";
          });

          // display error message on empty returns
          if (jsonData == ""){
                $('.overlayBG').show();
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
//          jsonData += "<div class=\"detail_system\"><div class=\"detail_host\">" + host + "</div>\n";
            jsonData += "<table class=\"details\" width=\"100%\"><tr><td width=\"32%\" class=\"detail_host\">" + host + "</td><td>&nbsp;</td><td width=\"80px\">&nbsp;</td></tr>\n";

                $.each(hostval, function(service, serviceval){

                  // service names

                  var state_div = "";

//                  if (serviceval.hardstate != "OK") {
                          state_div = " detail_status_" + serviceval.hardstate;
//                  }
//                jsonData += "    <div class=\"detail_system_services\"><div class=\"detail_service" + state_div + "\" \"title=\"" + service + "\">" + service + "</div>\n";
//                jsonData += "    <div class=\"detail_output" + state_div + "\" title=\"" + serviceval.output + "\">" + serviceval.output + "</div>\n";
//                jsonData += "    <div class=\"detail_status detail_status_" + serviceval.hardstate + "\" title=\"" + serviceval.hardstate + "\">" + serviceval.hardstate + "</div></div>\n";

                  jsonData += "    <tr><td class=\"detail_service" + state_div + " \"title=\"" + service + "\">" + service + "</td>\n";
                  jsonData += "    <td class=\"detail_output" + state_div + "\" title=\"" + serviceval.output + "\">" + serviceval.output + "</td>\n";
                  jsonData += "    <td class=\"detail_status detail_status_" + serviceval.hardstate + "\" title=\"" + serviceval.hardstate + "\">" + serviceval.hardstate + "</td></tr>\n";
                });

//              jsonData += "    </div>\n";
                jsonData += "</table>\n";
          });
          // display error message on empty returns
          if (jsonData == ""){
                $('.overlayBG').show();
          }

      // create new details div
          $('#details').empty();
          $('.details').append(jsonData);
          $('#details_data').empty();
          $('#details_data').append(jsonData);
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
