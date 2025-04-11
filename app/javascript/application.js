// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

window.onload = () => {
  const fancy = document.getElementById('fancy-background');

  if (fancy) {
    const colors = ['#3e713a', '#7fac46', '#5083a9', '#f4c935', '#d386d5', '#76675b', '#222'];

    let cells = document.querySelectorAll('.fancy-container div');
    cells.forEach((cell, index) => {
      cell.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
    });

    window.setInterval(() => {
      cells[Math.floor(Math.random() * cells.length)].style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
      }
    , 100);
  }
}
