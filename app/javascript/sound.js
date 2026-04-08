// sound.js — loaded as a classic script before gameboard.js
// Exposes SoundManager as a global accessible to gameboard.js.
var SoundManager = (() => {
  const MUTE_KEY   = "kbc_muted";
  const VOLUME_KEY = "kbc_volume";

  let sounds        = {};   // { key: HTMLAudioElement }
  let muted         = false;
  let volume        = 1.0;
  let ready         = false;
  let lastPlayed    = null; // track most recently started audio

  function applyVolume(audio) {
    audio.volume = muted ? 0 : volume;
  }

  function applyVolumeAll() {
    Object.values(sounds).forEach(applyVolume);
  }

  function init() {
    if (ready) return;
    ready = true;

    const config = document.getElementById("sound-config");
    if (!config) return;

    const keys  = JSON.parse(config.dataset.soundPreload || "[]");
    const paths = JSON.parse(config.dataset.soundPaths   || "{}");

    keys.forEach(k => {
      if (!paths[k]) return;   // file not yet recorded
      const audio = new Audio(paths[k]);
      audio.preload = "auto";
      sounds[k] = audio;
    });

    volume = parseFloat(localStorage.getItem(VOLUME_KEY) ?? "1");
    muted  = localStorage.getItem(MUTE_KEY) === "true";
    applyVolumeAll();

    // Unlock audio for browsers that block autoplay until user interaction.
    // On first gesture, silently play every loaded element so that
    // stream-triggered sounds (e.g. my_turn) are allowed to play later.
    const unlock = () => {
      Object.values(sounds).forEach(audio => {
        audio.volume = 0;
        audio.play().catch(() => {});
      });
      document.getElementById("audio-unlock-prompt")?.remove();
      ["click", "keydown", "pointerdown"].forEach(ev =>
        document.removeEventListener(ev, unlock, true));
    };
    ["click", "keydown", "pointerdown"].forEach(ev =>
      document.addEventListener(ev, unlock, true));
  }

  function play(name) {
    const audio = sounds[name];
    if (!audio) return;
    audio.currentTime = 0;
    applyVolume(audio);
    audio.play().catch(() => {});   // ignore autoplay policy errors
    lastPlayed = audio;
  }

  // Play name after the most recently started sound finishes.
  // Falls through to play() immediately if nothing is currently playing.
  function playAfterLast(name) {
    if (lastPlayed && !lastPlayed.ended && !lastPlayed.paused) {
      lastPlayed.addEventListener("ended", () => play(name), { once: true });
    } else {
      play(name);
    }
  }

  function setVolume(v) {
    volume = Math.min(1, Math.max(0, parseFloat(v)));
    localStorage.setItem(VOLUME_KEY, volume);
    applyVolumeAll();
  }

  function toggleMute() {
    muted = !muted;
    localStorage.setItem(MUTE_KEY, muted);
    applyVolumeAll();
    return muted;
  }

  function isMuted() { return muted; }
  function getVolume() { return volume; }

  return { init, play, playAfterLast, setVolume, toggleMute, isMuted, getVolume };
})();
