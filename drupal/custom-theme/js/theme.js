(function ($, Drupal) {
    'use strict';

    Drupal.behaviors.kubernetesTheme = {
        attach: function (context, settings) {
            // Smooth scrolling pentru anchor links
            $('a[href^="#"]', context).once('smooth-scroll').click(function (e) {
                var target = $(this.getAttribute('href'));
                if (target.length) {
                    e.preventDefault();
                    $('html, body').animate({
                        scrollTop: target.offset().top - 100
                    }, 500);
                }
            });

            // Animație pentru carduri
            $('.feature-card', context).once('card-animation').hover(
                function () {
                    $(this).find('h3').css('color', '#667eea');
                },
                function () {
                    $(this).find('h3').css('color', '');
                }
            );

            // Status pentru iframe-uri
            $('iframe', context).once('iframe-status').on('load', function () {
                console.log('Iframe loaded successfully:', this.src);
            });

            // Mesaj de bun venit
            if ($('.welcome-message', context).length === 0) {
                console.log('Kubernetes Theme: Welcome to the demo site!');
            }
        }
    };

})(jQuery, Drupal);