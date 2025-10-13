// script.js

document.addEventListener('DOMContentLoaded', function() {
    //const header = document.querySelector('header');
    const heroSection = document.querySelector('#hero');
    const heroHeight = heroSection.offsetHeight;

    window.addEventListener('scroll', function() {
        if (window.scrollY > heroHeight) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    });
});

document.addEventListener('scroll', function() {
  const logoLabel = document.querySelector('.logo_label');
  if (window.scrollY > 20) { // Adjust the scroll value as needed
    logoLabel.style.opacity = '0';
  } else {
    logoLabel.style.opacity = '1';
  }
});


document.addEventListener('scroll', function() {
  const logoLabel = document.querySelector('.navbar22');
  if (window.scrollY > 20) { // Adjust the scroll value as needed
    logoLabel.style.opacity = '0';
  } else {
    logoLabel.style.opacity = '1';
  }
});




