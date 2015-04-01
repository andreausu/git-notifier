Git Notifier
==============================

[![Build Status](https://travis-ci.org/andreausu/git-notifier.svg?branch=travis)](https://travis-ci.org/andreausu/git-notifier) [![Dependency Status](https://gemnasium.com/andreausu/github-notifier.svg)](https://gemnasium.com/andreausu/github-notifier)

Git Notifier is a Sinatra app that makes possible to receive email notifications for interesting GitHub events.

The supported events are:
- A user stars one of your repositories
- A user forks one of your repositories
- A user starts following you
- A user unfollows you
- A user that was following you was deleted

Git Notifier lets a GitHub user signup via OAuth and choose which type of notifications the user wishes to receive and at which frequency (asap, or in a nice daily or weekly report).

You can take a look and use this project in production here: https://gitnotifier.io

Weekly report example
------------

![Weekly report example](https://gitnotifier.io/img/screenshot1.png)

Installation
------------

Copy config.yml.example to config.yml and change the variables, then run:

``` bash
$ bundle install
$ puma -C config/puma.rb -e development # starts the webserver
$ bundle exec sidekiq -r ./workers/init.rb -q notifications_checker -q send_email -q send_email_signup -q email_builder # starts the workers
```

Testing
-------

This project includes casperjs functional tests.
Since the project relies on the GitHub API for basically everything the tests that require authenticated calls are not executed on Travis because doing so would expose the credentials of an actual GitHub user.

On your local machine, you can run the tests like this

``` bash
$ casperjs test test/casper/unauthenticated.js
$ casperjs test test/casper/authenticated.js --cookie=the-value-of-the-rack.session-cookie
$ casperjs test test/casper/signup.js --username=githubuser --password=githubpassword # make sure you start with a clean redis db
```

The ultimate goal is to mock the GitHub API calls and Redis calls in order to build a proper unit tests suite, but at least for now those tests make sure that the basic functionality isn't impaired by a broken commit.

License
-------

This project is released under the MIT license.
See the complete license:

[LICENSE](LICENSE)

Code contributions
----------------

If it's a feature that you think would need to be discussed please open an issue first, otherwise, you can follow this process:

1. Fork the project ( http://help.github.com/fork-a-repo/ )
2. Create a feature branch (git checkout -b my_branch)
3. Push your changes to your new branch (git push origin my_branch)
4. Initiate a pull request on github ( http://help.github.com/send-pull-requests/ )
5. Your pull request will be reviewed and hopefully merged :)

Thanks!
