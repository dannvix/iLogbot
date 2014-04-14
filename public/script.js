var strftime = function(date) {
  var hour = date.getHours(),
      min  = date.getMinutes(),
      sec  = date.getSeconds();
  if (hour < 10) { hour = "0" + hour; }
  if ( min < 10) {  min = "0" +  min; }
  if ( sec < 10) {  sec = "0" +  sec; }
  return hour + ":" + min + ":" + sec;
};

var lastTimestamp = undefined;
var seenTimestamp = {};
var pollNewMesg = function () {
  var time = lastTimestamp || (new Date()).getTime() / 1000.0;
  $.ajax({
    url: "/comet/poll/channel/" + channel + "/" + time,
    type: "get",
    async: true,
    cache: false,
    timeout: 60000,

    success: function (data) {
      var mesgs = JSON.parse(data);
      for (var i = 0; i < mesgs.length; i++) {
        var mesg = mesgs[i];
      	if (seenTimestamp[mesg.time]) { continue; }
      	seenTimestamp[mesg.time] = true;

        var date = new Date(parseFloat(mesg["time"]) * 1000);
        var linkedMesg = mesg["mesg"].replace(/(http[s]*:\/\/[^\s]+)/, '<a href="$1">$1</a>');
        var mesgElement = $('<li class="mesgline">').addClass("incoming")
          .append($('<div class="meta">')
            .append("&nbsp;")
            .append($('<span class="time">').text(strftime(date)))
            .append($('<span class="nick">').text(mesg.nick)))
          .append($('<div class="mesg">').html(linkedMesg))
        $(".mesgview").append(mesgElement);
      }

      if (mesgs.length > 0) {
        // there's new message
        $(document).scrollTop($(document).height());
      }
      lastTimestamp = (new Date()).getTime() / 1000.0;
      try {
        lastTimestamp = msgs[msgs.length - 1]["time"];
      } catch (e) {};

      setTimeout(function(){pollNewMesg();}, 3000);
    },

    error: function() {
      pollNewMesg();
    }
  });
}

var pollNewPrivMesg = function () {
  var time = lastTimestamp || (new Date()).getTime() / 1000.0;
  $.ajax({
    url: "/comet/poll/privchat/" + channel + "/" + time,
    type: "get",
    async: true,
    cache: false,
    timeout: 60000,

    success: function (data) {
      var mesgs = JSON.parse(data);
      for (var i = 0; i < mesgs.length; i++) {
        var mesg = mesgs[i];
        if (seenTimestamp[mesg.time]) { continue; }
        seenTimestamp[mesg.time] = true;

        var date = new Date(parseFloat(mesg["time"]) * 1000);
        var linkedMesg = mesg["mesg"].replace(/(http[s]*:\/\/[^\s]+)/, '<a href="$1">$1</a>');
        var mesgElement = $('<li class="mesgline">').addClass("incoming")
          .append($('<div class="meta">')
            .append("&nbsp;")
            .append($('<span class="time">').text(strftime(date)))
            .append($('<span class="nick">').text(mesg.nick)))
          .append($('<div class="mesg">').html(linkedMesg))
        $(".mesgview").append(mesgElement);
      }

      if (mesgs.length > 0) {
        // there's new message
        $(document).scrollTop($(document).height());
      }
      lastTimestamp = (new Date()).getTime() / 1000.0;
      try {
        lastTimestamp = msgs[msgs.length - 1]["time"];
      } catch (e) {};

      setTimeout(function(){pollNewPrivMesg();}, 3000);
    },

    error: function() {
      pollNewPrivMesg();
    }
  });
}

var pageScrollTop = function(position) {
  $("html, body").animate({
    scrollTop: position
  }, 1000);
};