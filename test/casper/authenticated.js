casper.test.setUp(function () {
  phantom.addCookie({
      domain: 'gitnotifier.local',
      name: 'rack.session',
      value: casper.cli.get("cookie")
  });
});

casper.test.begin("Home page", 3, function suite(test) {
  casper.start("http://gitnotifier.local/", function() {
    test.assertTitle("Git Notifier - Profile", "Page title is correct");
    test.assertExists('table#events', "Events table found found");
    test.assertEval(function() {
            return __utils__.findAll("table#events tr").length >= 5;
        }, "there are some events");
  });

  casper.run(function() {
    test.done();
  });
});
