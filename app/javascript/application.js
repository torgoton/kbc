// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

window.Turbo.StreamActions.play_sound = function () {
  window.SoundManager?.play(this.getAttribute("key"))
}

let fancyDanceInterval;

function stop_fancy_dance() {
  if (fancyDanceInterval) {
    window.clearInterval(fancyDanceInterval);
    fancyDanceInterval = undefined;
  }
}

function fancy_dance() {
  stop_fancy_dance();

  const fancy = document.getElementById('fancy-background');

  console.log('onpageshow', fancy);
  if (fancy) {
    const colors = ['#a52a2a', '#ffd700', 'darkorchid', 'chartreuse', '#444', 'forestgreen', 'royalblue'];

    let cells = document.querySelectorAll('.fancy-hexfield div');
    cells.forEach((cell, index) => {
      cell.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
    });

    fancyDanceInterval = window.setInterval(() => {
      cells[Math.floor(Math.random() * cells.length)].style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
      }
    , 100);
  }
}

document.addEventListener('turbo:before-render', stop_fancy_dance);
document.addEventListener('turbo:load', fancy_dance);

import "trix"
import "@rails/actiontext"
