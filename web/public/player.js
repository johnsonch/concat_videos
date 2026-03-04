(function() {
  var video = document.getElementById('player');
  var display = document.getElementById('current-time');
  var setFront = document.getElementById('set-front');
  var setEnd = document.getElementById('set-end');
  var frontInput = document.getElementById('front_trim');
  var endInput = document.getElementById('end_trim');

  function formatTime(seconds) {
    var h = Math.floor(seconds / 3600);
    var m = Math.floor((seconds % 3600) / 60);
    var s = Math.floor(seconds % 60);
    return String(h).padStart(2, '0') + ':' +
           String(m).padStart(2, '0') + ':' +
           String(s).padStart(2, '0');
  }

  video.addEventListener('timeupdate', function() {
    display.textContent = formatTime(video.currentTime);
  });

  setFront.addEventListener('click', function() {
    frontInput.value = formatTime(video.currentTime);
  });

  setEnd.addEventListener('click', function() {
    if (isNaN(video.duration)) return;
    var remaining = video.duration - video.currentTime;
    endInput.value = formatTime(Math.max(0, remaining));
  });
})();
