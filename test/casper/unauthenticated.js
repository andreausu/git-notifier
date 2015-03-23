casper.test.begin("Home page", 2, function suite(test) {
  casper.start("http://gitnotifier.local/", function() {
    test.assertTitle("Git Notifier - Notifications for stars, forks, follow and unfollow", "Page title is correct");
    test.assertExists('a.btn-github', "Signup button found");
  });

  casper.run(function() {
    test.done();
  });
});
