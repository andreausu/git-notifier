$(function() {
  $(".nav-link").click(function(e) {
    var link = $(this);
    var href = link.attr("href");
    if (href.indexOf('#') !== -1 && href.indexOf('/#') === -1) {
      e.preventDefault();
      $("body").animate({scrollTop: $(href).offset().top - 80}, 500);
      link.closest(".navbar").find(".navbar-toggle:not(.collapsed)").click();
    }
  });

  $('[data-toggle="tooltip"]').tooltip();

  if (document.getElementById('show_unsubscribe') instanceof Object) {
    $('a#show_unsubscribe').click(function() {
      $('div#unsubscribe_form').removeClass('hidden');
      $('div#change_frequency_form,div#unsubscribe_question').addClass('hidden');
    });
  }

  if (document.getElementById('notifications_type') instanceof Object && document.getElementById('notifications_frequency') instanceof Object) {
    changePreferences();
  }

  if (document.getElementById('events') instanceof Object) {
    getEvents();
  }

  if (document.getElementById('signup') instanceof Object) {
    var $email = $('#other_email');
    var $hint = $("#other_email_suggestion");

    $email.on('focus', function() {
      $('#other_email_radio').prop("checked", true);
    });

    $email.on('blur', function(e) {
      checkEmail(e);
    });

    $('#signup').on('submit', function(e) {
      checkEmail(e);
    });

    $hint.on('click', function() {
      $email.val($(".suggestion").text());
      $hint.fadeOut(200, function() {
        $(this).empty();
      });
      return false;
    });
  }

  function checkEmail(e) {
    $hint.css('display', 'none'); // Hide the hint
    $email.mailcheck({
      suggested: function(element, suggestion) {
        if(!$hint.html()) {
          e.preventDefault();
          var suggestion = "Did you mean <span class='suggestion'>" +
          "<span class='address'>" + suggestion.address + "</span>"
          + "@<a href='#' class='domain'>" + suggestion.domain +
          "</a></span>?";

          $hint.html(suggestion).fadeIn(150);
        } else {
          $(".address").html(suggestion.address);
          $(".domain").html(suggestion.domain);
        }
      }
    });
  }

  function getEvents() {
    $('div#spinner').spin('large');
    getNextEvents(1);
  }

  function getNextEvents(page) {
    $.ajax({
      url: '/api/events?page=' + page,
      method: 'GET',
      async: true,
      success: function(data) {
        data = JSON.parse(data);
        if (data.objects.length > 0) {
          $.each(data.objects, function(index, event) {
            switch(event.type) {
              case 'star':
                icon = 'star';
                break;
              case 'fork':
                icon = 'repo-forked';
                break;
              case 'follow':
                icon = 'person';
                break;
              case 'unfollow':
                icon = 'person';
                break;
              case 'deleted':
                icon = 'trashcan';
                break;
              default:
                icon = '';
            }

            var date = 'n/a';
            if (event.timestamp) {
              var d = new Date(event.timestamp * 1000);
              date = d.toDateString();
            }

            $("table#events").append($('<tr><td><span class="octicon octicon-' + icon + '" aria-hidden="true" data-toggle="tooltip" data-placement="left" title="' + date + '"></span>  ' + event.body + "</td></tr>").hide().fadeIn(1000));
            $('[data-toggle="tooltip"]').tooltip();
          });
        } else {
          if ($('table#events tbody').children().length === 0 && data.meta.eof) {
            $('div#noevents').removeClass('hidden');
          }
        }

        if (!data.meta.eof) {
          getNextEvents(page + 1);
        } else {
          $('div#spinner').addClass('hidden').spin(false);
        }
      }
    });
  }

  function changePreferences() {

    $('button#button_save_preferences').click(function() {

      var disabledNotifications = $("#notifications_type input:checkbox:not(:checked)").map(function() {
        return this.value;
      }).get();

      var notificationFrequency = $("#notifications_frequency input[type='radio']:checked").val();

      $.ajax({
        beforeSend: function(xhr) {
          var token = $('div#preferences').data('csrf');
          xhr.setRequestHeader('x-csrf-token', token);
        },
        url : '/api/user/preferences',
        data : JSON.stringify(
        {
          "notifications_frequency":notificationFrequency,
          "disabled_notifications_type":disabledNotifications
        }),
        type : 'PATCH',
        contentType : 'application/json',
        processData: false,
        dataType: 'json',
        success: function() {
          if (window.location.pathname.indexOf('signup') > -1) {
            // Sign up
            window.location = '/';
          } else {
            window.location.reload();
          }
        },
        error: function() {
          alert('An error occurred!');
        }
      });

    });

  }

  // Google Analytics
  $('button#signup_button').click(function() {
    if (typeof(ga) == "function") {
      ga('send', 'event', 'button', 'click', 'signup', {useBeacon: true});
    }
  });

});
