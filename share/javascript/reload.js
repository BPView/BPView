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

function reloadone(){
	$(document).ready(function(){
		$('#iframeContent').append(' ....  import data from CMDB<br/>').delay(1000).queue(function (next) {
			next();
			$('#iframeContent').append(' ....  generate config files for dashboard and business processes<br/>').delay(1000).queue(function (next) {
				next();
				$('#iframeContent').append(' ....  generate config files for Monitoring<br/>').delay(1000).queue(function (next) {
					$(this).append('<br/> .... wait a moment .');
					$(function(){
						setInterval(oneSecondFunction, 1000);
					});
					next();
				});
			});
		});
	});
}

function oneSecondFunction() {
	$('#iframeContent').append(' .');
}

function goback() {
	$(document).ready(function(){
		setTimeout(function (){
             window.top.location.href = "bpview.pl";
        }, 3000);
	});
}




