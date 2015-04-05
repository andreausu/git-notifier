var onWaitTimeout = function() {
  this.capture('failure_timeout.png');
  casper.test.fail('Wait timeout occurred!');
};

casper.on("page.error", function(msg, trace) {
  /*this.echo("Error:    " + msg, "ERROR");
  this.echo("file:     " + trace[0].file, "WARNING");
  this.echo("line:     " + trace[0].line, "WARNING");
  this.echo("function: " + trace[0]["function"], "WARNING");
  errors.push(msg);*/
  console.log(msg);
  console.log(trace);
});

casper.options.onWaitTimeout = onWaitTimeout;
casper.options.viewportSize = {width: 1280, height: 800};

casper.test.on('fail', function () {
  casper.capture('failure.png');
});

casper.test.begin("Signup process", 24, function suite(test) {
  casper.start("http://gitnotifier.local/", function() {
    test.assertTitle("GitNotifier - Notifications for stars, forks, follow and unfollow", "Page title is correct");
    test.assertExists('a.btn-github', "Signup button found");
    this.click('a.btn-github');
  });

  casper.then(function() {
    test.assertUrlMatch(/github\.com/, "We are on GitHub");
    casper.waitForSelector('form input[name="password"]', function() {
      this.fillSelectors('div#login form', {
          'input[name="login"]' : this.cli.get("username"),
          'input[name="password"]': this.cli.get("password")
      }, true);
    });
  });

  casper.then(function() {
    if (this.exists('button[name="authorize"]')) {
      this.click('button[name="authorize"]');
    }
  });

  casper.then(function() {
    test.assertUrlMatch(/gitnotifier/, "We are back on Git Notifier");
    this.waitForSelector('button#signup_button', function() {
      test.assertVisible('input[name="email"]', 'Main email is visible');
      test.assertVisible('input[name="other_email"]', 'Other email is visible');
      test.assertVisible('button#signup_button', 'Signup button is visible');
      this.click('input#other_email_radio');
      this.fillSelectors('form#signup', {
          'input[name="other_email"]' : 'gitnotifier@gnail.com',
      }, false);
      this.waitUntilVisible('div#other_email_suggestion a.domain', function() {
        test.assertVisible('div#other_email_suggestion a.domain', 'Wrong domain suggestion is visible');
        this.click('div#other_email_suggestion a.domain');
        test.assertField({type: 'css', path: 'input#other_email'}, 'gitnotifier@gmail.com', 'Domain replaced!');
        this.wait('500', function() {
          test.assertNotVisible('div#other_email_suggestion a.domain', 'Suggestion is not visible anymore');
          this.click('button#signup_button');
        });
      });
    });
  });

  casper.then(function() {
    this.waitUntilVisible('button#button_save_preferences', function() {
      test.assertTextExists('We have sent an email to gitnotifier@gmail.com, please open it and click on the link inside to activate your account', 'Flash alert "confirm e-mail address" is present');
      test.assertVisible('div.alert.alert-success', 'Flash alert "confirm e-mail address" is visible');
      test.assertTextExists('Choose the type of notifications you wish to receive', 'Text type of notifications is present');
      test.assertTextExists('Choose at which frequency we should send you the notifications', 'Text frequency of notifications is present');
      test.assertTextExists('Star', 'Text Star is present');
      test.assertTextExists('Fork', 'Text Fork is present');
      test.assertTextExists('Follow', 'Text Follow is present');
      test.assertTextExists('Unfollow', 'Text Unfollow is present');
      test.assertTextExists('Deleted', 'Text Deleted is present');
      test.assertTextExists('Site-news', 'Text Site-news is present');

      test.assertTextExists('Asap', 'Text Asap is present');
      test.assertTextExists('Daily', 'Text Daily is present');
      test.assertTextExists('Weekly', 'Text Weekly is present');

      //this.click('input#asap');
      //this.click('input#deleted');
      //this.clickLabel('Save', 'button');
      this.clickLabel('Profile', 'a');
    });
  });

  casper.then(function() {
    this.waitForSelector('table#events > tbody > tr > td > span', function() {
      test.assertTextExists('andreausu starred your project', 'Text for the notification is present');
      this.clickLabel('Preferences', 'a');
    });
  });

  casper.then(function() {
    this.capture('test2.jpg', undefined, {
      format: 'jpg',
      quality: 75
    });
  });

  casper.run(function() {
    test.done();
  });
});


// A8o_IF!BgHoltE0ZbOFX3LGUlziL
