// sound.js — loaded as a classic script before gameboard.js
// Exposes SoundManager as a global and registers the play_sound Turbo Stream action.
var SoundManager = (() => {
  const MUTE_KEY   = "kbc_muted";
  const VOLUME_KEY = "kbc_volume";

  let sounds = {};
  let muted  = false;
  let volume = 1.0;
  let ready  = false;

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

    const paths = JSON.parse(config.dataset.soundPaths || "{}");
    Object.entries(paths).forEach(([k, p]) => {
      const audio = new Audio(p);
      audio.preload = "auto";
      sounds[k] = audio;
    });

    volume = parseFloat(localStorage.getItem(VOLUME_KEY) ?? "1");
    muted  = localStorage.getItem(MUTE_KEY) === "true";
    applyVolumeAll();

    // Unlock audio on first user gesture (autoplay policy).
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
    audio.play().catch(() => {});
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

  return {
    init, play, setVolume, toggleMute,
    isMuted: () => muted,
    getVolume: () => volume
  };
})();

Turbo.StreamActions.play_sound = function () {
  SoundManager.play(this.getAttribute("key"));
};
